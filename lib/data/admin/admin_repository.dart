import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/utils/api_error_helper.dart';
import 'package:path_mobile/utils/http_client.dart';

/// HTTP repository for school admin endpoints (`/admin/pengguna`, `/admin/kelas`).
class AdminRepository {
  final HttpClient _client;

  AdminRepository(this._client);

  String get baseUrl => _client.baseUrl;

  String _extractMessage(String body, String fallback) =>
      extractApiErrorMessage(body, fallback);

  Future<(AdminGuruMuridData?, String?)> getGuruDanMurid() async {
    try {
      final response = await _client
          .get(_client.uri('/admin/pengguna'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat daftar guru dan murid'),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (null, 'Format data pengguna tidak valid');
      }
      return (AdminGuruMuridData.fromJson(decoded), null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<AdminKelasModel>?, String?)> getAllKelas({
    String? tahunAjaran,
    int? tingkat,
    String? nama,
  }) async {
    try {
      final queryParams = <String, String>{};
      final normalizedYear = tahunAjaran?.trim() ?? '';
      if (normalizedYear.isNotEmpty) {
        queryParams['tahun_ajaran'] = normalizedYear;
      }
      if (tingkat != null) {
        queryParams['tingkat'] = tingkat.toString();
      }
      final normalizedNama = nama?.trim() ?? '';
      if (normalizedNama.isNotEmpty) {
        queryParams['nama'] = normalizedNama;
      }

      final baseUri = _client.uri('/admin/kelas');
      final uri = queryParams.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParams);

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat daftar kelas'),
        );
      }

      final decoded = jsonDecode(response.body);
      final list = (decoded as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AdminKelasModel.fromJson)
          .toList();

      return (list, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<String?> createUser({
    required String nama,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _client
          .post(
            _client.uri('/admin/pengguna'),
            headers: _client.JSON,
            body: jsonEncode({
              'nama': nama,
              'email': email,
              'password': password,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return _extractMessage(response.body, 'Gagal menambahkan pengguna');
      }
      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<String?> deleteUser(int penggunaId) async {
    try {
      final response = await _client
          .delete(_client.uri('/admin/pengguna/$penggunaId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        return _extractMessage(response.body, 'Gagal menghapus pengguna');
      }
      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<String?> updateUserRole(int penggunaId, String role) async {
    try {
      final response = await _client
          .patch(
            _client.uri('/admin/pengguna/$penggunaId/role'),
            headers: _client.JSON,
            body: jsonEncode({'role': role}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(
          response.body,
          'Gagal memperbarui role pengguna',
        );
      }
      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<String?> createKelas({
    required String nama,
    String mapel = '',
    String deskripsi = '',
    required int tingkat,
    required String tahunAjaran,
    int? pengampuId,
  }) async {
    try {
      final response = await _client
          .post(
            _client.uri('/admin/kelas'),
            headers: _client.JSON,
            body: jsonEncode({
              'nama': nama,
              if (mapel.isNotEmpty) 'mapel': mapel,
              'deskripsi': deskripsi,
              'tingkat': tingkat,
              'tahun_ajaran': tahunAjaran,
              'pengampu_id': ?pengampuId,
            }),
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

  Future<(String?, String?)> uploadKelasCsv(http.MultipartFile fileCsv) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _client.uri('/admin/kelas/csv'),
      );
      request.files.add(fileCsv);

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200 && response.statusCode != 201) {
        return (
          null,
          _extractMessage(response.body, 'Gagal mengunggah CSV kelas'),
        );
      }

      return (
        _extractMessage(response.body, 'Kelas dari CSV berhasil dibuat'),
        null,
      );
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<String?> updatePengampuKelas(String kodeKelas, int? pengampuId) async {
    try {
      final encodedCode = Uri.encodeComponent(kodeKelas);
      final response = await _client
          .patch(
            _client.uri('/admin/kelas/$encodedCode/pengampu'),
            headers: _client.JSON,
            body: jsonEncode({'pengampu_id': pengampuId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(
          response.body,
          'Gagal memperbarui pengampu kelas',
        );
      }
      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<(Map<int, int>?, String?)> getAiUsage({int? bulan, int? tahun}) async {
    try {
      final queryParams = <String, String>{};
      if (bulan != null) queryParams['bulan'] = bulan.toString();
      if (tahun != null) queryParams['tahun'] = tahun.toString();
      final baseUri = _client.uri('/admin/ai/usage');
      final uri = queryParams.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParams);

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        return (const <int, int>{}, null);
      }
      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat ringkasan AI'),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (const <int, int>{}, null);
      }
      final rawUsers = decoded['users'] as List<dynamic>? ?? const <dynamic>[];
      final result = <int, int>{};
      for (final item in rawUsers.whereType<Map<String, dynamic>>()) {
        final uid = (item['pengguna_id'] as num?)?.toInt() ?? 0;
        final total = (item['total_pakai'] as num?)?.toInt() ?? 0;
        if (uid > 0) {
          result[uid] = total;
        }
      }
      return (result, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(AdminAiOpsUsageModel?, String?)> getAiOpsUsage() async {
    try {
      final response = await _client
          .get(_client.uri('/ai/ops/usage'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (null, null);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (null, null);
      }
      return (AdminAiOpsUsageModel.fromJson(decoded), null);
    } catch (_) {
      return (null, null);
    }
  }
}
