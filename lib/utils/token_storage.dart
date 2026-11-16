import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistence contract for the authenticated session token.
abstract class TokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

/// Encrypted key-value storage backed by [FlutterSecureStorage].
class SecureTokenStorage implements TokenStorage {
  static const String tokenKey = 'path_mobile_auth_token';

  final FlutterSecureStorage _storage;

  const SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() async {
    try {
      final token = await _storage.read(key: tokenKey);
      if (token == null || token.trim().isEmpty) {
        return null;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: tokenKey, value: token);
    } catch (_) {}
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: tokenKey);
    } catch (_) {}
  }
}

/// In-memory [TokenStorage] implementation useful in tests.
class MemoryTokenStorage implements TokenStorage {
  String? _token;

  MemoryTokenStorage([String? initialToken]) : _token = initialToken;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}

/// Returns `true` when [token] is a 3-part JWT whose numeric `exp` claim is in
/// the past relative to [now]. Opaque/non-JWT tokens return `false`.
bool isJwtExpired(String token, {DateTime? now}) {
  final parts = token.split('.');
  if (parts.length != 3) return false;

  try {
    final normalized = base64Url.normalize(parts[1]);
    final payloadJson = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(payloadJson);
    if (payload is! Map<String, dynamic>) return false;

    final exp = payload['exp'];
    if (exp is! num) return false;

    final currentMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return currentMs >= (exp * 1000).round();
  } catch (_) {
    return false;
  }
}
