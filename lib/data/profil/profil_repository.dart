import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/profil/profil_model.dart';
import 'package:path_mobile/utils/api_error_helper.dart';
import 'package:path_mobile/utils/http_client.dart';

class ProfilRepository {
  final HttpClient _client;

  ProfilRepository(this._client);

  String get baseUrl => _client.baseUrl;

  bool get isAdmin => _client.isAdmin;

  Future<void> flushPersistence() => _client.flushPersistence();

  String _extractMessage(String body, String fallback) =>
      extractApiErrorMessage(body, fallback);

  Future<(ProfilModel?, String?)> getProfil() async {
    try {
      final response = await _client
          .get(_client.uri('/pengguna'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat data pengguna'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final profil = ProfilModel.fromJson(data);
      if (data['role'] is String && profil.role.trim().isNotEmpty) {
        _client.setRole(profil.role);
      } else if (data['admin'] is bool) {
        _client.setAdmin(profil.admin);
      }
      return (profil, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(ProfilModel?, String?)> updateEmail(String email) async {
    try {
      final req = UpdateEmailRequest(email: email);
      final response = await _client
          .patch(
            _client.uri('/pengguna/email'),
            headers: _client.JSON,
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memperbarui email'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = UpdatePenggunaResponse.fromJson(data);
      return (parsed.data, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(ProfilModel?, String?)> updatePhone(String phone) async {
    try {
      final req = UpdatePhoneRequest(phone: phone);
      final response = await _client
          .patch(
            _client.uri('/pengguna/phone'),
            headers: _client.JSON,
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memperbarui nomor HP'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = UpdatePenggunaResponse.fromJson(data);
      return (parsed.data, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(ProfilModel?, String?)> updateProfilePicture(
    http.MultipartFile file,
  ) async {
    try {
      final request = http.MultipartRequest(
        'PATCH',
        _client.uri('/pengguna/profile-picture'),
      );
      request.files.add(file);

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memperbarui foto profil'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = UpdatePenggunaResponse.fromJson(data);
      return (parsed.data, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<String?> resetPassword(String oldPassword, String newPassword) async {
    try {
      final req = ResetPasswordRequest(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      final response = await _client
          .post(
            _client.uri('/pengguna/reset-password'),
            headers: _client.JSON,
            body: jsonEncode(req.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _extractMessage(response.body, 'Gagal mereset password');
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<(List<BantuanKontenModel>?, String?)> getBantuan() async {
    try {
      final response = await _client
          .get(_client.uri('/bantuan'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat konten bantuan'),
        );
      }
      final decoded = jsonDecode(response.body);
      final list = (decoded as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(BantuanKontenModel.fromJson)
          .toList();
      return (list, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(BantuanKontenModel?, String?)> updateBantuan(
    String kunci,
    String isi,
  ) async {
    try {
      final encoded = Uri.encodeComponent(kunci);
      final response = await _client
          .patch(
            _client.uri('/admin/bantuan/$encoded'),
            headers: _client.JSON,
            body: jsonEncode({'isi': isi}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memperbarui konten bantuan'),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return (BantuanKontenModel.fromJson(decoded), null);
      }
      return (null, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  void logout() {
    _client.setToken(null);
  }
}
