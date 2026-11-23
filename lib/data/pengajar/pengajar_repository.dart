import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/utils/api_error_helper.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

LampiranItem _uploadedToLampiran(UploadedPostinganFile file) {
  final ext = extractLampiranExtension(
    file.nama.isNotEmpty ? file.nama : file.path,
  );
  return LampiranItem(
    name: file.nama.isNotEmpty ? file.nama : 'Lampiran',
    detail: ext.isEmpty ? 'FILE' : ext.toUpperCase(),
    url: file.path,
  );
}

class GeneratedMateriAiResult {
  final String judul;
  final String deskripsi;
  final List<LampiranItem> lampiran;

  const GeneratedMateriAiResult({
    required this.judul,
    required this.deskripsi,
    required this.lampiran,
  });
}

class KoreksiAiResult {
  final Map<int, int> scoresByPenggunaId;
  final Map<int, String> labelsByPenggunaId;
  final Map<int, String> feedbackByPenggunaId;
  final LampiranItem? rekapFile;
  final List<String> analisa;

  const KoreksiAiResult({
    required this.scoresByPenggunaId,
    this.labelsByPenggunaId = const {},
    required this.feedbackByPenggunaId,
    this.rekapFile,
    this.analisa = const [],
  });
}

class AssessmentCheckAiResult {
  final LampiranItem? rekapFile;
  final List<String> analisa;
  final List<String> ringkasan;

  const AssessmentCheckAiResult({
    this.rekapFile,
    this.analisa = const [],
    this.ringkasan = const [],
  });
}

class PengajarRepository {
  final HttpClient _client;
  late final KelasRepository _kelasRepo = KelasRepository(_client);

  PengajarRepository(this._client);

  String get baseUrl => _client.baseUrl;

  int? get currentUserId => _client.userId;

  bool get isAdmin => _client.isAdmin;

  String _extractMessage(String body, String fallback) =>
      extractApiErrorMessage(body, fallback);

  Future<(List<KelasModel>?, String?)> getListKelas() {
    return _kelasRepo.getListKelas(guru: true);
  }

  Future<(List<AnggotaKelasModel>?, String?)> getListAnggota(
    String kodeKelas,
  ) {
    return _kelasRepo.getListAnggota(kodeKelas);
  }

  Future<(KelasModel?, String?)> getKelas(String kodeKelas) {
    return _kelasRepo.getKelas(kodeKelas);
  }

  Future<String?> createKelas(CreateKelasRequest request) {
    return _kelasRepo.createKelas(request);
  }

  Future<(KelasModel?, String?)> updateKelas(
    String kodeKelas,
    UpdateKelasRequest request,
  ) {
    return _kelasRepo.updateKelas(kodeKelas, request);
  }

  Future<String?> promoteToGuru(String kodeKelas, int penggunaId) {
    return _kelasRepo.promoteToGuru(kodeKelas, penggunaId);
  }

  Future<String?> demoteToMurid(String kodeKelas, int penggunaId) {
    return _kelasRepo.demoteToMurid(kodeKelas, penggunaId);
  }

  Future<(List<PostinganModel>?, String?)> getListPostingan(
    String kodeKelas, {
    int? tipe,
  }) {
    return _kelasRepo.getListPostingan(kodeKelas, tipe: tipe);
  }

  Future<(PostinganModel?, String?)> createPostingan(
    String kodeKelas,
    CreatePostinganPayload payload,
  ) {
    return _kelasRepo.createPostingan(kodeKelas, payload);
  }

  Future<(PostinganModel?, String?)> editPostingan(
    String kodeKelas,
    int postinganId,
    EditPostinganPayload payload,
  ) {
    return _kelasRepo.editPostingan(kodeKelas, postinganId, payload);
  }

  Future<String?> deletePostingan(String kodeKelas, int postinganId) {
    return _kelasRepo.deletePostingan(kodeKelas, postinganId);
  }

  Future<(List<TipePostinganModel>?, String?)> getListTipePostingan() {
    return _kelasRepo.getListTipePostingan();
  }

  Future<(List<UploadedPostinganFile>?, String?)> uploadPostinganFiles(
    List<http.MultipartFile> files,
  ) {
    return _kelasRepo.uploadPostinganFiles(files);
  }

  Future<(List<PengumpulanMuridModel>?, String?)> listPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) {
    return _kelasRepo.listPengumpulanTugas(kodeKelas, postinganId);
  }

  Future<(List<PengumpulanMuridModel>?, String?)> simpanNilaiPengumpulan(
    String kodeKelas,
    int postinganId,
    Map<int, int?> nilaiByPenggunaId,
  ) {
    return _kelasRepo.simpanNilaiPengumpulan(
      kodeKelas,
      postinganId,
      nilaiByPenggunaId,
    );
  }

  Future<String?> updateRoleGuru(String kodeKelas, bool roleGuru) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final payload = UpdateGuruPayload(roleGuru: roleGuru);
      final response = await _client
          .patch(
            _client.uri('/$encodedCode/guru'),
            headers: _client.JSON,
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(response.body, 'Gagal mengupdate role guru');
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<(List<GuruModel>?, String?)> getListGuru() async {
    try {
      final response = await _client
          .get(_client.uri('/guru'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat daftar guru'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final list = data
          .map((x) => GuruModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (list, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<AdminModel>?, String?)> getListAdmin() async {
    try {
      final response = await _client
          .get(_client.uri('/admin'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat daftar admin'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final list = data
          .map((x) => AdminModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (list, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(GeneratedMateriAiResult?, String?)> generateMateriAi({
    required String judul,
    required String deskripsiMateri,
    List<String> lampiranPaths = const [],
    String jenjang = '',
    bool tabel = false,
    bool diagram = false,
    bool ilustrasi = false,
    bool kombinasi = false,
    String formatKeluaran = 'pdf',
    bool gunakanModelGratis = false,
  }) async {
    try {
      // Image generation on ai.pathclass.app cannot use the free model tier.
      final effectiveFree = gunakanModelGratis && !ilustrasi && !kombinasi;
      final normalizedFormat =
          formatKeluaran.trim().toLowerCase() == 'pptx' ? 'pptx' : 'pdf';
      final response = await _client
          .post(
            _client.uri('/ai/materi/generate'),
            headers: _client.JSON,
            body: jsonEncode({
              'judul': judul,
              'deskripsi_materi': deskripsiMateri,
              if (lampiranPaths.isNotEmpty) 'lampiran_paths': lampiranPaths,
              'jenjang': jenjang,
              'tabel': tabel,
              'diagram': diagram,
              'ilustrasi': ilustrasi,
              'kombinasi': kombinasi,
              'format_keluaran': normalizedFormat,
              'gunakan_model_gratis': effectiveFree,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal membuat materi dengan AI'),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawLampiran = decoded['lampiran'];
      final lampiran = <LampiranItem>[];
      if (rawLampiran is List) {
        for (final entry in rawLampiran) {
          if (entry is Map<String, dynamic>) {
            final uploaded = UploadedPostinganFile.fromJson(entry);
            lampiran.add(_uploadedToLampiran(uploaded));
          }
        }
      }

      return (
        GeneratedMateriAiResult(
          judul: (decoded['judul'] ?? judul).toString().trim(),
          deskripsi: (decoded['deskripsi'] ?? '').toString().trim(),
          lampiran: lampiran,
        ),
        null,
      );
    } on TimeoutException {
      return (null, 'Pembuatan materi AI melebihi batas waktu. Coba lagi.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(KoreksiAiResult?, String?)> koreksiTugasAi({
    required String kodeKelas,
    required int postinganId,
    required List<int> penggunaIds,
    String deskripsiKunci = '',
    String? keyFileName,
    Uint8List? keyFileBytes,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _client.uri('/ai/koreksi'));
      request.fields['kode_kelas'] = kodeKelas;
      request.fields['postingan_id'] = postinganId.toString();
      if (penggunaIds.isNotEmpty) {
        request.fields['pengguna_ids'] = penggunaIds.join(',');
      }
      if (deskripsiKunci.trim().isNotEmpty) {
        request.fields['deskripsi_kunci'] = deskripsiKunci.trim();
      }
      if (keyFileBytes != null && keyFileBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'berkas_kunci',
            keyFileBytes,
            filename: (keyFileName == null || keyFileName.trim().isEmpty)
                ? 'kunci_jawaban.txt'
                : keyFileName.trim(),
          ),
        );
      }

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 150));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal melakukan koreksi AI'),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final scores = <int, int>{};
      final labels = <int, String>{};
      final feedback = <int, String>{};
      final rawHasil = decoded['hasil'];
      if (rawHasil is List) {
        for (final entry in rawHasil) {
          if (entry is Map<String, dynamic>) {
            final uid = (entry['pengguna_id'] as num?)?.toInt() ?? 0;
            final nilai = (entry['nilai'] as num?)?.round();
            if (uid > 0 && nilai != null) {
              scores[uid] = nilai.clamp(0, 100);
              final label = (entry['label'] ?? '').toString().trim();
              if (label.isNotEmpty) {
                labels[uid] = label;
              }
              final saran = (entry['saran'] ?? '').toString().trim();
              if (saran.isNotEmpty) {
                feedback[uid] = saran;
              }
            }
          }
        }
      }

      LampiranItem? rekapFile;
      final rawRekap = decoded['rekap_file'];
      if (rawRekap is Map<String, dynamic>) {
        rekapFile = _uploadedToLampiran(
          UploadedPostinganFile.fromJson(rawRekap),
        );
      }

      final analisa = <String>[];
      final rawAnalisa = decoded['analisa'];
      if (rawAnalisa is List) {
        for (final item in rawAnalisa) {
          final text = item.toString().trim();
          if (text.isNotEmpty) analisa.add(text);
        }
      }

      return (
        KoreksiAiResult(
          scoresByPenggunaId: scores,
          labelsByPenggunaId: labels,
          feedbackByPenggunaId: feedback,
          rekapFile: rekapFile,
          analisa: analisa,
        ),
        null,
      );
    } on TimeoutException {
      return (null, 'Koreksi AI melebihi batas waktu. Coba lagi.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(AssessmentCheckAiResult?, String?)> _runAssessmentCheckAi({
    required String endpoint,
    required String fallbackError,
    required String kodeKelas,
    required int postinganId,
    List<int> penggunaIds = const [],
    String jenjang = '',
    bool gunakanModelGratis = false,
  }) async {
    try {
      final response = await _client
          .post(
            _client.uri(endpoint),
            headers: _client.JSON,
            body: jsonEncode({
              'kode_kelas': kodeKelas,
              'postingan_id': postinganId,
              if (penggunaIds.isNotEmpty) 'pengguna_ids': penggunaIds,
              if (jenjang.trim().isNotEmpty) 'jenjang': jenjang.trim(),
              'gunakan_model_gratis': gunakanModelGratis,
            }),
          )
          .timeout(const Duration(seconds: 150));

      if (response.statusCode != 200) {
        return (null, _extractMessage(response.body, fallbackError));
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      LampiranItem? rekapFile;
      final rawRekap = decoded['rekap_file'];
      if (rawRekap is Map<String, dynamic>) {
        rekapFile = _uploadedToLampiran(
          UploadedPostinganFile.fromJson(rawRekap),
        );
      }

      List<String> parseStrings(dynamic raw) {
        final out = <String>[];
        if (raw is List) {
          for (final item in raw) {
            final text = item.toString().trim();
            if (text.isNotEmpty) out.add(text);
          }
        }
        return out;
      }

      return (
        AssessmentCheckAiResult(
          rekapFile: rekapFile,
          analisa: parseStrings(decoded['analisa']),
          ringkasan: parseStrings(decoded['ringkasan']),
        ),
        null,
      );
    } on TimeoutException {
      return (null, 'Analisis AI melebihi batas waktu. Coba lagi.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(AssessmentCheckAiResult?, String?)> cekKemiripanAi({
    required String kodeKelas,
    required int postinganId,
    List<int> penggunaIds = const [],
    bool gunakanModelGratis = false,
  }) {
    return _runAssessmentCheckAi(
      endpoint: '/ai/similarity',
      fallbackError: 'Gagal memeriksa kemiripan jawaban siswa',
      kodeKelas: kodeKelas,
      postinganId: postinganId,
      penggunaIds: penggunaIds,
      gunakanModelGratis: gunakanModelGratis,
    );
  }

  Future<(AssessmentCheckAiResult?, String?)> cekIndikasiAi({
    required String kodeKelas,
    required int postinganId,
    List<int> penggunaIds = const [],
    String jenjang = '',
    bool gunakanModelGratis = false,
  }) {
    return _runAssessmentCheckAi(
      endpoint: '/ai/indikasi',
      fallbackError: 'Gagal memeriksa indikasi penggunaan AI',
      kodeKelas: kodeKelas,
      postinganId: postinganId,
      penggunaIds: penggunaIds,
      jenjang: jenjang,
      gunakanModelGratis: gunakanModelGratis,
    );
  }
}
