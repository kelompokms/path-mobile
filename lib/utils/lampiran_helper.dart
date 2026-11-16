import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/utils/http_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// Maximum number of attachments per postingan (matches `path-api`).
const int maxPostinganFiles = 5;

/// Maximum size per attachment file in bytes (10 MB, matches `path-api`).
const int maxPostinganFileSizeBytes = 10 * 1024 * 1024;

/// Allowed file extensions for postingan attachments (matches `path-api`).
const Set<String> allowedPostinganExtensions = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'pdf',
  'txt',
  'csv',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'zip',
  'rar',
  '7z',
  'gz',
  'mp4',
  'mp3',
};

class LampiranItem {
  final String name;
  final String detail;
  final bool isLink;
  final String? url;

  const LampiranItem({
    required this.name,
    required this.detail,
    this.isLink = false,
    this.url,
  });

  String? get targetUrl {
    final raw = (url ?? (isLink ? detail : null))?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

class UploadedPostinganFile {
  final String nama;
  final String path;
  final int ukuran;

  const UploadedPostinganFile({
    required this.nama,
    required this.path,
    required this.ukuran,
  });

  factory UploadedPostinganFile.fromJson(Map<String, dynamic> json) {
    return UploadedPostinganFile(
      nama: json['nama'] as String? ?? '',
      path: (json['path'] ?? json['url'])?.toString() ?? '',
      ukuran: (json['ukuran'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'path': path,
    'ukuran': ukuran,
  };
}

class UploadPostinganFilesResponse {
  final List<UploadedPostinganFile> files;

  const UploadPostinganFilesResponse({required this.files});

  factory UploadPostinganFilesResponse.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final list = rawFiles is List
        ? rawFiles
              .map(
                (e) =>
                    UploadedPostinganFile.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : <UploadedPostinganFile>[];
    return UploadPostinganFilesResponse(files: list);
  }
}

class PickedLampiranFile {
  final String name;
  final int? size;
  final Future<Uint8List> Function() readBytes;

  const PickedLampiranFile({
    required this.name,
    this.size,
    required this.readBytes,
  });
}

typedef UploadLampiranFiles =
    Future<(List<UploadedPostinganFile>?, String?)> Function(
      List<http.MultipartFile> files,
    );

typedef LampiranUrlLauncher =
    Future<bool> Function(Uri uri, {LaunchMode mode});

typedef LampiranFilePicker = Future<List<PickedLampiranFile>> Function();

abstract final class LampiranHelper {
  @visibleForTesting
  static LampiranUrlLauncher? urlLauncherOverride;

  @visibleForTesting
  static LampiranFilePicker? filePickerOverride;

  @visibleForTesting
  static void resetTestOverrides() {
    urlLauncherOverride = null;
    filePickerOverride = null;
  }
}

Future<bool> _defaultLaunchUrl(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(uri, mode: mode);
}

Future<List<PickedLampiranFile>> _defaultPickFiles() async {
  final files = await FilePicker.pickFiles(type: FileType.any);
  return files
      .map(
        (f) => PickedLampiranFile(
          name: f.name,
          size: f.lengthSync(),
          readBytes: f.readAsBytes,
        ),
      )
      .toList();
}

String extractLampiranExtension(String fileName) {
  final base = fileName.split(RegExp(r'[/\\]')).last.trim();
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

String _sanitizeFileName(String name) {
  final base = name.split(RegExp(r'[/\\]')).last.trim();
  return base.isEmpty ? 'file' : base;
}

/// Validates and normalizes an external link attachment to `http://` or `https://`.
/// Returns `null` if empty, contains whitespace, uses a non-http(s) scheme, or has no host.
String? normalizeLampiranLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
    return null;
  }

  final lower = trimmed.toLowerCase();
  final hasHttpScheme =
      lower.startsWith('http://') || lower.startsWith('https://');
  if (!hasHttpScheme) {
    final colonIdx = trimmed.indexOf(':');
    final slashIdx = trimmed.indexOf('/');
    final hasColonBeforePath =
        colonIdx > 0 && (slashIdx == -1 || colonIdx < slashIdx);
    if (hasColonBeforePath &&
        !RegExp(r'^[a-zA-Z0-9.-]+:\d+($|[/?#])').hasMatch(trimmed)) {
      return null;
    }
  }

  final candidate = hasHttpScheme ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
    return null;
  }
  return candidate;
}

bool isLampiranUploadPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('/uploads/') || trimmed.startsWith('uploads/')) {
    return true;
  }
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.path.startsWith('/uploads/');
  }
  return false;
}

/// Resolves a [LampiranItem] into a launchable HTTP(S) [Uri], or `null` if it
/// does not have a valid link or uploaded file URL.
Uri? resolveLampiranUri(LampiranItem item, {String? baseUrl}) {
  final raw = item.targetUrl;
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final effectiveBase = (baseUrl != null && baseUrl.trim().isNotEmpty)
      ? baseUrl.trim()
      : HttpClient.defaultBaseUrl;

  if (trimmed.startsWith('/')) {
    final base = Uri.tryParse(effectiveBase);
    if (base == null || !base.hasScheme) return null;
    return base.resolve(trimmed);
  }
  if (trimmed.startsWith('uploads/')) {
    final base = Uri.tryParse(effectiveBase);
    if (base == null || !base.hasScheme) return null;
    return base.resolve('/$trimmed');
  }

  if (item.isLink) {
    final normalized = normalizeLampiranLink(trimmed);
    return normalized == null ? null : Uri.tryParse(normalized);
  }

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.host.isNotEmpty) {
      return parsed;
    }
  }
  return null;
}

/// Launches the attachment's URL in an external browser/app (falling back to platformDefault).
/// Returns `null` on success or an Indonesian error message on failure.
Future<String?> openLampiranItem(LampiranItem item, {String? baseUrl}) async {
  final uri = resolveLampiranUri(item, baseUrl: baseUrl);
  if (uri == null) {
    return 'Link lampiran tidak valid';
  }

  final launcher = LampiranHelper.urlLauncherOverride ?? _defaultLaunchUrl;
  var launched = false;
  try {
    launched = await launcher(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      launched = await launcher(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      launched = await launcher(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      launched = false;
    }
  }

  if (!launched) {
    return 'Tidak dapat membuka lampiran';
  }
  return null;
}

Future<List<PickedLampiranFile>> pickLampiranFiles() {
  final picker = LampiranHelper.filePickerOverride ?? _defaultPickFiles;
  return picker();
}

/// Validates [picked] files against `path-api/internal/files` constraints and
/// immediately uploads them via [onUploadFiles], returning [LampiranItem]s whose
/// [LampiranItem.url] holds the uploaded path/URL returned by the API.
Future<(List<LampiranItem>?, String?)> uploadPickedLampiranFiles(
  List<PickedLampiranFile> picked, {
  required int currentCount,
  required UploadLampiranFiles? onUploadFiles,
  int maxFiles = maxPostinganFiles,
}) async {
  if (picked.isEmpty) return (const <LampiranItem>[], null);
  if (onUploadFiles == null) {
    return (null, 'Layanan upload file tidak tersedia');
  }

  final remaining = maxFiles - currentCount;
  if (remaining <= 0) {
    return (null, 'Maksimal $maxFiles lampiran');
  }
  if (picked.length > remaining) {
    return (null, 'Maksimal $maxFiles lampiran (tersisa $remaining slot)');
  }

  final multipartFiles = <http.MultipartFile>[];
  for (final file in picked) {
    final fileName = _sanitizeFileName(file.name);
    final ext = extractLampiranExtension(fileName);
    if (ext.isEmpty || !allowedPostinganExtensions.contains(ext)) {
      return (null, 'Tipe file "$fileName" tidak didukung');
    }

    final knownSize = file.size;
    if (knownSize != null) {
      if (knownSize <= 0) {
        return (null, 'File "$fileName" kosong');
      }
      if (knownSize > maxPostinganFileSizeBytes) {
        return (
          null,
          'Ukuran file "$fileName" terlalu besar (maks. 10 MB)',
        );
      }
    }

    final bytes = await file.readBytes();
    if (bytes.isEmpty) {
      return (null, 'File "$fileName" kosong');
    }
    if (bytes.length > maxPostinganFileSizeBytes) {
      return (
        null,
        'Ukuran file "$fileName" terlalu besar (maks. 10 MB)',
      );
    }

    multipartFiles.add(
      http.MultipartFile.fromBytes('files', bytes, filename: fileName),
    );
  }

  final (uploaded, err) = await onUploadFiles(multipartFiles);
  if (err != null) {
    return (null, err);
  }
  if (uploaded == null || uploaded.isEmpty) {
    return (null, 'Gagal mengunggah file lampiran');
  }

  final items = uploaded.map((f) {
    final displayName = f.nama.isNotEmpty
        ? f.nama
        : _sanitizeFileName(f.path);
    final ext = extractLampiranExtension(displayName);
    return LampiranItem(
      name: displayName,
      detail: ext.isEmpty ? 'FILE' : ext.toUpperCase(),
      url: f.path,
    );
  }).toList();

  return (items, null);
}
