import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/utils/api_error_helper.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class KelasRepository {
  final HttpClient _client;

  KelasRepository(this._client);

  String get baseUrl => _client.baseUrl;

  int? get currentUserId => _client.userId;

  bool get isAdmin => _client.isAdmin;

  String _extractMessage(String body, String fallback) =>
      extractApiErrorMessage(body, fallback);

  Future<(List<KelasModel>?, String?)> getListKelas({bool? guru}) async {
    try {
      final baseUri = _client.uri('/kelas');
      final uri = guru == null
          ? baseUri
          : baseUri.replace(queryParameters: {'guru': guru.toString()});
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (null, _extractMessage(response.body, 'Gagal memuat kelas'));
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      var kelasList = data
          .map((x) => KelasModel.fromJson(x as Map<String, dynamic>))
          .toList();
      if (guru != null) {
        kelasList = kelasList.where((k) => k.guru == guru).toList();
      }

      return (kelasList, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<AnggotaKelasModel>?, String?)> getListAnggota(
    String kodeKelas,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .get(_client.uri('/kelas/$encodedCode/anggota'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat daftar anggota'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final members = data
          .map((x) => AnggotaKelasModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (members, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(KelasModel?, String?)> getKelas(String kodeKelas) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .get(_client.uri('/kelas/$encodedCode'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (null, _extractMessage(response.body, 'Gagal memuat kelas'));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final kelas = KelasModel.fromJson(data);

      return (kelas, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<String?> createKelas(CreateKelasRequest request) async {
    try {
      final response = await _client
          .post(
            _client.uri('/kelas'),
            headers: _client.JSON,
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return _extractMessage(response.body, 'Gagal membuat kelas');
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<(KelasModel?, String?)> updateKelas(
    String kodeKelas,
    UpdateKelasRequest request,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .patch(
            _client.uri('/kelas/$encodedCode'),
            headers: _client.JSON,
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memperbarui kelas'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (KelasModel.fromJson(data), null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<String?> promoteToGuru(String kodeKelas, int penggunaId) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .patch(
            _client.uri('/kelas/$encodedCode/anggota/$penggunaId/guru'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(
          response.body,
          'Gagal mengangkat murid menjadi guru',
        );
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<String?> demoteToMurid(String kodeKelas, int penggunaId) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .patch(
            _client.uri('/kelas/$encodedCode/anggota/$penggunaId/murid'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(
          response.body,
          'Gagal menurunkan guru menjadi murid',
        );
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<String?> joinKelas(String kodeKelas) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .post(_client.uri('/kelas/$encodedCode/gabung'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return _extractMessage(response.body, 'Gagal bergabung ke kelas');
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<String?> leaveKelas(String kodeKelas) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .post(_client.uri('/kelas/$encodedCode/keluar'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(response.body, 'Gagal keluar dari kelas');
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<(List<PostinganModel>?, String?)> getListPostingan(
    String kodeKelas, {
    int? tipe,
  }) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final baseUri = _client.uri('/kelas/$encodedCode/posts');
      final uri = tipe == null
          ? baseUri
          : baseUri.replace(queryParameters: {'tipe': tipe.toString()});

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat postingan'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final posts = data
          .map((x) => PostinganModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (posts, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(PostinganModel?, String?)> createPostingan(
    String kodeKelas,
    CreatePostinganPayload payload,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .post(
            _client.uri('/kelas/$encodedCode/posts'),
            headers: _client.JSON,
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return (
          null,
          _extractMessage(response.body, 'Gagal membuat postingan'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (PostinganModel.fromJson(data), null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(PostinganModel?, String?)> editPostingan(
    String kodeKelas,
    int postinganId,
    EditPostinganPayload payload,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .patch(
            _client.uri('/kelas/$encodedCode/postingan/$postinganId'),
            headers: _client.JSON,
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memperbarui postingan'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (PostinganModel.fromJson(data), null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<String?> deletePostingan(String kodeKelas, int postinganId) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .delete(_client.uri('/kelas/$encodedCode/postingan/$postinganId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        return _extractMessage(response.body, 'Gagal menghapus postingan');
      }
      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<(List<TipePostinganModel>?, String?)> getListTipePostingan() async {
    try {
      final response = await _client
          .get(_client.uri('/posts/tipe'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat tipe postingan'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final list = data
          .map((x) => TipePostinganModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (list, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<UploadedPostinganFile>?, String?)> uploadPostinganFiles(
    List<http.MultipartFile> files,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _client.uri('/files/postingan'),
      );
      request.files.addAll(files);

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        return (
          null,
          _extractMessage(response.body, 'Gagal mengunggah file lampiran'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = UploadPostinganFilesResponse.fromJson(data);
      return (parsed.files, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(PengumpulanTugasModel?, String?)> getPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .get(
            _client.uri(
              '/kelas/$encodedCode/postingan/$postinganId/pengumpulan/saya',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        return (
          PengumpulanTugasModel(postinganId: postinganId, submitted: false),
          null,
        );
      }

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat pengumpulan tugas'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (PengumpulanTugasModel.fromJson(data), null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<PengumpulanMuridModel>?, String?)> listPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .get(
            _client.uri('/kelas/$encodedCode/postingan/$postinganId/pengumpulan'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(
            response.body,
            'Gagal memuat daftar pengumpulan tugas',
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final items = data
          .map((x) => PengumpulanMuridModel.fromJson(x as Map<String, dynamic>))
          .toList();
      return (items, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<PengumpulanMuridModel>?, String?)> simpanNilaiPengumpulan(
    String kodeKelas,
    int postinganId,
    Map<int, int?> nilaiByPenggunaId,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final payload = {
        'nilai': [
          for (final entry in nilaiByPenggunaId.entries)
            {'pengguna_id': entry.key, 'nilai': entry.value},
        ],
      };
      final response = await _client
          .patch(
            _client.uri(
              '/kelas/$encodedCode/postingan/$postinganId/pengumpulan/nilai',
            ),
            headers: _client.JSON,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal menyimpan nilai pengumpulan'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final items = data
          .map((x) => PengumpulanMuridModel.fromJson(x as Map<String, dynamic>))
          .toList();
      return (items, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(PengumpulanTugasModel?, String?)> submitPengumpulanTugas(
    String kodeKelas,
    int postinganId,
    List<String> lampiran,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .post(
            _client.uri('/kelas/$encodedCode/postingan/$postinganId/pengumpulan'),
            headers: _client.JSON,
            body: jsonEncode({'lampiran': lampiran}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return (
          null,
          _extractMessage(response.body, 'Gagal mengumpulkan tugas'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (PengumpulanTugasModel.fromJson(data), null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<String>?, String?)> tarikPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .delete(
            _client.uri('/kelas/$encodedCode/postingan/$postinganId/pengumpulan'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        return (
          null,
          _extractMessage(response.body, 'Gagal menarik pengumpulan tugas'),
        );
      }

      if (response.body.trim().isEmpty) {
        return (const <String>[], null);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawLampiran = decoded['lampiran'];
        final list = rawLampiran is List
            ? rawLampiran.map((e) => e.toString()).toList()
            : const <String>[];
        return (list, null);
      }
      return (const <String>[], null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  static bool _isRefusalResponse(String jawaban) {
    final lower = jawaban.toLowerCase();
    return lower.contains('belum melampirkan') ||
        lower.contains('tempelkan (paste)') ||
        lower.contains('tempel (paste)') ||
        lower.contains('copy-paste') ||
        lower.contains('tidak ada di materi yang diberikan');
  }

  static bool _isSummarizeQuery(String text) {
    final lower = text.toLowerCase();
    return RegExp(
      r'\b(ringkas\w*|rangkum\w*|kesimpulan\w*|inti\s+materi|poin[\s-]+poin\s+penting|pokok\s+bahasan)\b',
    ).hasMatch(lower);
  }

  Future<(String?, String?)> chatAi({
    required String pesan,
    String isiMateri = '',
    List<String> lampiranPaths = const [],
    String jenjang = '',
    List<String> modes = const [],
    List<Map<String, String>> riwayat = const [],
    bool gunakanModelGratis = false,
  }) async {
    try {
      final trimmedMateri = isiMateri.trim();
      final topicTitle = trimmedMateri.isEmpty
          ? ''
          : trimmedMateri.split('\n').first.trim();

      // Avoid sending short post titles/instructions as strict closed-book isi_materi,
      // which causes ai.pathclass.app /v1/chat to refuse summarization or topic questions.
      final hasSubstantialMateriText = trimmedMateri.runes.length >= 400;
      String effectivePesan = pesan.trim();
      String effectiveIsiMateri = hasSubstantialMateriText ? trimmedMateri : '';

      if (!hasSubstantialMateriText && topicTitle.isNotEmpty) {
        if (_isSummarizeQuery(effectivePesan)) {
          effectivePesan =
              'Buatkan ringkasan materi pembelajaran dan poin-poin penting mengenai topik "$topicTitle"'
              '${trimmedMateri.length > topicTitle.length ? ' ($trimmedMateri)' : ''} '
              'untuk bahan belajar siswa.\n\nPermintaan siswa: $effectivePesan';
        } else {
          effectivePesan =
              'Konteks topik materi pembelajaran: $trimmedMateri\n\nPertanyaan: $effectivePesan';
        }
      }

      Future<http.Response> postChat({
        required String promptText,
        required String materiText,
        required bool useFree,
      }) {
        return _client
            .post(
              _client.uri('/ai/chat'),
              headers: _client.JSON,
              body: jsonEncode({
                'pesan': promptText,
                'isi_materi': materiText,
                if (lampiranPaths.isNotEmpty) 'lampiran_paths': lampiranPaths,
                'jenjang': jenjang,
                'modes': modes,
                'riwayat': riwayat,
                'gunakan_model_gratis': useFree,
              }),
            )
            .timeout(const Duration(seconds: 60));
      }

      var activeFree = gunakanModelGratis;
      var response = await postChat(
        promptText: effectivePesan,
        materiText: effectiveIsiMateri,
        useFree: activeFree,
      );

      // Automatic fallback to paid tier if free tier is rate-limited upstream (502/503/429).
      if (activeFree &&
          (response.statusCode == 429 ||
              response.statusCode == 502 ||
              response.statusCode == 503)) {
        activeFree = false;
        response = await postChat(
          promptText: effectivePesan,
          materiText: effectiveIsiMateri,
          useFree: false,
        );
      }

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal mendapatkan jawaban AI'),
        );
      }

      var decoded = jsonDecode(response.body) as Map<String, dynamic>;
      var jawaban = (decoded['jawaban'] ?? '').toString().trim();

      // If upstream LLM still thought no text/PDF was attached, retry with an explicit topic summary prompt.
      if (_isRefusalResponse(jawaban) && topicTitle.isNotEmpty) {
        final retryPrompt =
            'Buatkan ringkasan materi pembelajaran dan penjelasan poin-poin penting mengenai topik "$topicTitle" untuk bahan belajar siswa.\n\nPermintaan siswa: ${pesan.trim()}';
        final retryResp = await postChat(
          promptText: retryPrompt,
          materiText: '',
          useFree: activeFree,
        );
        if (retryResp.statusCode == 200) {
          final retryDecoded =
              jsonDecode(retryResp.body) as Map<String, dynamic>;
          final retryJawaban =
              (retryDecoded['jawaban'] ?? '').toString().trim();
          if (retryJawaban.isNotEmpty) {
            jawaban = retryJawaban;
          }
        }
      }

      if (jawaban.isEmpty) {
        return (null, 'Jawaban AI kosong');
      }
      return (jawaban, null);
    } on TimeoutException {
      return (null, 'Permintaan AI melebihi batas waktu. Coba lagi.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(ExplainMateriAiResult?, String?)> explainMateriAi({
    required String pertanyaan,
    String deskripsiMateri = '',
    String isiMateri = '',
    List<String> lampiranPaths = const [],
    String jenjang = '',
    bool tabel = false,
    bool diagram = false,
    bool ilustrasi = false,
    bool kombinasi = false,
    bool gunakanModelGratis = false,
  }) async {
    try {
      // Image generation on ai.pathclass.app cannot use the free model tier.
      final effectiveFree = gunakanModelGratis && !ilustrasi && !kombinasi;
      final response = await _client
          .post(
            _client.uri('/ai/materi/explain'),
            headers: _client.JSON,
            body: jsonEncode({
              'pertanyaan': pertanyaan,
              'deskripsi_materi': deskripsiMateri,
              'isi_materi': isiMateri,
              'lampiran_paths': lampiranPaths,
              'jenjang': jenjang,
              'tabel': tabel,
              'diagram': diagram,
              'ilustrasi': ilustrasi,
              'kombinasi': kombinasi,
              'gunakan_model_gratis': effectiveFree,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal membuat penjelasan visual AI'),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      LampiranItem? fileItem;
      final rawFile = decoded['file'];
      if (rawFile is Map<String, dynamic>) {
        final uploaded = UploadedPostinganFile.fromJson(rawFile);
        final ext = extractLampiranExtension(
          uploaded.nama.isNotEmpty ? uploaded.nama : uploaded.path,
        );
        fileItem = LampiranItem(
          name: uploaded.nama.isNotEmpty ? uploaded.nama : 'Penjelasan_AI.pdf',
          detail: ext.isEmpty ? 'PDF' : ext.toUpperCase(),
          url: uploaded.path,
        );
      }

      return (
        ExplainMateriAiResult(
          judul: (decoded['judul'] ?? '').toString().trim(),
          jawaban: (decoded['jawaban'] ?? '').toString().trim(),
          file: fileItem,
        ),
        null,
      );
    } on TimeoutException {
      return (null, 'Pembuatan penjelasan AI melebihi batas waktu. Coba lagi.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(ExplainMateriAiResult?, String?)> ringkasDokumenAi({
    required List<String> lampiranPaths,
    String judul = '',
    String deskripsiMateri = '',
    String fokus = '',
    String jenjang = '',
    bool diagram = false,
    bool gunakanModelGratis = false,
  }) async {
    try {
      final response = await _client
          .post(
            _client.uri('/ai/dokumen/ringkas'),
            headers: _client.JSON,
            body: jsonEncode({
              'lampiran_paths': lampiranPaths,
              'judul': judul,
              'fokus': fokus,
              'jenjang': jenjang,
              'diagram': diagram,
              'gunakan_model_gratis': gunakanModelGratis,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        LampiranItem? fileItem;
        final rawFile = decoded['file'];
        if (rawFile is Map<String, dynamic>) {
          final uploaded = UploadedPostinganFile.fromJson(rawFile);
          final ext = extractLampiranExtension(
            uploaded.nama.isNotEmpty ? uploaded.nama : uploaded.path,
          );
          fileItem = LampiranItem(
            name: uploaded.nama.isNotEmpty ? uploaded.nama : 'Ringkasan_AI.pdf',
            detail: ext.isEmpty ? 'PDF' : ext.toUpperCase(),
            url: uploaded.path,
          );
        }

        var jawaban = (decoded['jawaban'] ?? '').toString().trim();
        final resJudul = (decoded['judul'] ?? judul).toString().trim();

        // If backend only returned the generic PDF placeholder without summary text,
        // enrich with a text summary from chatAi so the student sees points immediately.
        if (jawaban.isEmpty ||
            jawaban.startsWith('Ringkasan dokumen AI telah selesai dibuat')) {
          final (chatSummary, _) = await chatAi(
            pesan: fokus.trim().isNotEmpty
                ? fokus.trim()
                : 'Ringkas materi ini beserta poin-poin pentingnya',
            isiMateri: [judul.trim(), deskripsiMateri.trim()]
                .where((s) => s.isNotEmpty)
                .join('\n\n'),
            lampiranPaths: lampiranPaths,
            jenjang: jenjang,
            gunakanModelGratis: gunakanModelGratis,
          );
          if (chatSummary != null && chatSummary.trim().isNotEmpty) {
            jawaban = chatSummary.trim();
          }
        }

        return (
          ExplainMateriAiResult(
            judul: resJudul,
            jawaban: jawaban,
            file: fileItem,
          ),
          null,
        );
      }

      // Fallback: if /ai/dokumen/ringkas fails (e.g. 403/502 forbidden_for_student on older backend
      // or unsupported attachment), fall back to explainMateriAi which reads berkas_materi for students too.
      if (lampiranPaths.isNotEmpty) {
        final topic = judul.trim().isNotEmpty ? judul.trim() : 'materi ini';
        final prompt = fokus.trim().isNotEmpty
            ? 'Ringkas dokumen materi "$topic" dengan fokus: ${fokus.trim()}'
            : 'Ringkas dan jelaskan poin-poin utama dari dokumen materi "$topic" secara lengkap dan terstruktur.';
        final ( fallbackRes, fallbackErr) = await explainMateriAi(
          pertanyaan: prompt,
          deskripsiMateri: deskripsiMateri,
          isiMateri: [judul.trim(), deskripsiMateri.trim()]
              .where((s) => s.isNotEmpty)
              .join('\n\n'),
          lampiranPaths: lampiranPaths,
          jenjang: jenjang,
          tabel: true,
          diagram: diagram,
          gunakanModelGratis: gunakanModelGratis,
        );
        if (fallbackRes != null && fallbackErr == null) {
          var jawaban = fallbackRes.jawaban;
          if (jawaban.runes.length < 220) {
            final (chatSummary, _) = await chatAi(
              pesan: prompt,
              isiMateri: [judul.trim(), deskripsiMateri.trim()]
                  .where((s) => s.isNotEmpty)
                  .join('\n\n'),
              lampiranPaths: lampiranPaths,
              jenjang: jenjang,
              gunakanModelGratis: gunakanModelGratis,
            );
            if (chatSummary != null && chatSummary.trim().isNotEmpty) {
              jawaban = '${fallbackRes.jawaban}\n\n---\n\n${chatSummary.trim()}';
            }
          }
          return (
            ExplainMateriAiResult(
              judul: fallbackRes.judul.isNotEmpty ? fallbackRes.judul : judul,
              jawaban: jawaban,
              file: fallbackRes.file,
            ),
            null,
          );
        }
      }

      return (
        null,
        _extractMessage(response.body, 'Gagal meringkas dokumen dengan AI'),
      );
    } on TimeoutException {
      return (null, 'Ringkasan dokumen AI melebihi batas waktu. Coba lagi.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }
}

class ExplainMateriAiResult {
  final String judul;
  final String jawaban;
  final LampiranItem? file;

  const ExplainMateriAiResult({
    required this.judul,
    required this.jawaban,
    this.file,
  });
}
