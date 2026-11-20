import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/utils/http_client.dart';

class PengajarRepository {
  final HttpClient _client;
  late final KelasRepository _kelasRepo = KelasRepository(_client);

  PengajarRepository(this._client);

  String get baseUrl => _client.baseUrl;

  String? _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message'] as String? ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

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
      final payload = UpdateGuruPayload(roleGuru: roleGuru);
      final response = await _client
          .patch(
            _client.uri('/$kodeKelas/guru'),
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
}
