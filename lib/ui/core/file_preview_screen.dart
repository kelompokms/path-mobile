import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

/// Lightweight in-app preview screen for uploaded attachment files:
/// - Images: zoomable [InteractiveViewer] + [Image.network]
/// - Text / CSV: scrollable [SelectableText]
/// - PDF & Office documents: in-app browser preview via Google Docs Viewer
///   (no forced download), plus fallback button to open/download directly.
class FilePreviewScreen extends StatefulWidget {
  final LampiranItem item;
  final String? baseUrl;

  const FilePreviewScreen({super.key, required this.item, this.baseUrl});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  String? _textContent;
  String? _textError;
  bool _loadingText = false;

  Uri? get _fileUri => resolveLampiranUri(widget.item, baseUrl: widget.baseUrl);

  String get _ext {
    final fromName = extractLampiranExtension(widget.item.name);
    if (fromName.isNotEmpty) return fromName;
    final uri = _fileUri;
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return extractLampiranExtension(uri.pathSegments.last);
    }
    return widget.item.detail.trim().toLowerCase();
  }

  bool get _isImage => isPreviewableImageExtension(_ext);
  bool get _isText => isPreviewableTextExtension(_ext);
  bool get _isDocument => isPreviewableDocumentExtension(_ext);

  @override
  void initState() {
    super.initState();
    if (_isText) {
      _loadTextPreview();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadTextPreview() async {
    final uri = _fileUri;
    if (uri == null) {
      setState(() => _textError = 'Link file tidak valid');
      return;
    }
    setState(() {
      _loadingText = true;
      _textError = null;
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loadingText = false;
          _textError = 'Gagal memuat isi dokumen (HTTP ${response.statusCode})';
        });
        return;
      }
      final decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
      setState(() {
        _loadingText = false;
        _textContent = decoded.length > 100000
            ? '${decoded.substring(0, 100000)}\n\n... (dokumen dipotong untuk preview)'
            : decoded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingText = false;
        _textError = 'Gagal memuat preview teks. Anda dapat membuka file langsung.';
      });
    }
  }

  Future<void> _openDocumentViewer() async {
    final err = await openLampiranDocumentPreview(
      widget.item,
      baseUrl: widget.baseUrl,
    );
    if (err != null) {
      _showSnack(err);
    }
  }

  Future<void> _openExternal() async {
    final err = await openLampiranItem(widget.item, baseUrl: widget.baseUrl);
    if (err != null) {
      _showSnack(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = _fileUri;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 900,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: Row(
                children: [
                  Expanded(child: BackTitleRow(title: widget.item.name)),
                  if (uri != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Buka / Unduh',
                        onPressed: _openExternal,
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 20,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: uri == null
                  ? const Center(
                      child: Text(
                        'File tidak dapat ditampilkan',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    )
                  : _buildPreviewBody(uri, h),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewBody(Uri uri, double h) {
    if (_isImage) {
      return Padding(
        padding: EdgeInsets.fromLTRB(h, 8, h, 24),
        child: Container(
          decoration: AppTheme.cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                uri.toString(),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, _, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gagal memuat gambar',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _openExternal,
                        style: AppTheme.softCompactButton,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Buka di Browser'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_isText) {
      if (_loadingText) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_textError != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _textError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _loadTextPreview,
                      style: AppTheme.softCompactButton,
                      child: const Text('Coba Lagi'),
                    ),
                    FilledButton(
                      onPressed: _openExternal,
                      child: const Text('Buka / Unduh File'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(h, 8, h, 24),
        child: Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              _textContent ?? '',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(h, 12, h, 24),
        child: Card(
          elevation: AppTheme.cardElevation,
          shadowColor: AppTheme.shadowColor,
          margin: EdgeInsets.zero,
          color: AppColors.card,
          surfaceTintColor: Colors.transparent,
          shape: AppTheme.cardShape(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 44,
                  color: AppColors.color1,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _ext.isEmpty ? widget.item.detail : _ext.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_isDocument)
                      FilledButton.icon(
                        key: const Key('file_preview_open_viewer_button'),
                        onPressed: _openDocumentViewer,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Preview Dokumen'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                        ),
                      ),
                    ElevatedButton.icon(
                      key: const Key('file_preview_download_button'),
                      onPressed: _openExternal,
                      style: AppTheme.softCompactButton,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Buka / Unduh File'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
