import 'dart:async';
import 'dart:convert';

import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/utils/http_client.dart';

class LoginRepository {
  final HttpClient _client;

  LoginRepository(this._client);

  /// Returns an error message on failure, or `null` on success (like Go's `error`).
  Future<String?> login(String email, String password) async {
    final req = LoginRequest(email: email, password: password);

    try {
      final response = await _client
          .post(
            _client.uri('/login'),
            body: jsonEncode(req.toJson()),
            headers: _client.JSON,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return data['message'] as String? ?? 'Login failed';
      }

      final authRes = AuthSuccessResponse.fromJson(data);
      if (authRes.token.isEmpty) {
        return 'Token not found';
      }
      _client.setToken(authRes.token);
      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }
}
