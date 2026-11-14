import 'dart:async';
import 'dart:convert';

import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/register/register_model.dart';
import 'package:path_mobile/utils/http_client.dart';

class RegisterRepository {
  final HttpClient _client;

  RegisterRepository(this._client);

  Future<String?> register(String username, String email, String password) async {
    final req = RegisterRequest(
      username: username,
      email: email,
      password: password,
    );

    try {
      final response = await _client
          .post(
            _client.uri('/register'),
            body: jsonEncode(req.toJson()),
            headers: _client.JSON,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 && response.statusCode != 201) {
        return data['message'] as String? ??
            'Failed to register. Please try again.';
      }

      final authRes = AuthSuccessResponse.fromJson(data);
      if (authRes.token.isEmpty) {
        return 'Failed to register. Please try again.';
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
