import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/utils/http_client.dart';

class KelasRepository {
  final HttpClient _client;

  KelasRepository(this._client);

  String? _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message'] as String? ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  Future<(List<KelasModel>?, String?)> getListKelas() async {
    try {
      final response = await _client
          .get(_client.uri('/kelas'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (null, _extractMessage(response.body, 'Gagal memuat kelas'));
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final kelasList = data
          .map((x) => KelasModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (kelasList, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(KelasModel?, String?)> getKelas(String kodeKelas) async {
    try {
      final response = await _client
          .get(_client.uri('/kelas/$kodeKelas'))
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

  Future<String?> joinKelas(String kodeKelas) async {
    try {
      final response = await _client
          .post(
            _client.uri('/kelas/$kodeKelas/gabung'),
            headers: _client.JSON,
          )
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
      final response = await _client
          .post(
            _client.uri('/kelas/$kodeKelas/keluar'),
            headers: _client.JSON,
          )
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
    required int tipe,
    String? mapel,
  }) async {
    try {
      final queryParams = <String, String>{
        'tipe': tipe.toString(),
        if (mapel != null && mapel.isNotEmpty) 'mapel': mapel,
      };
      final uri = _client
          .uri('/kelas/$kodeKelas/posts')
          .replace(queryParameters: queryParams);

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
      final response = await _client
          .post(
            _client.uri('/kelas/$kodeKelas/posts'),
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
      final response = await _client
          .patch(
            _client.uri('/kelas/$kodeKelas/postingan/$postinganId'),
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
}
