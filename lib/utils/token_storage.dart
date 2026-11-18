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

Map<String, dynamic>? _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final normalized = base64Url.normalize(parts[1]);
    final payloadJson = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(payloadJson);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}

/// Returns `true` when [token] is a 3-part JWT whose numeric `exp` claim is in
/// the past relative to [now]. Opaque/non-JWT tokens return `false`.
bool isJwtExpired(String token, {DateTime? now}) {
  final payload = _decodeJwtPayload(token);
  if (payload == null) return false;

  final exp = payload['exp'];
  if (exp is! num) return false;

  final currentMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  return currentMs >= (exp * 1000).round();
}

/// Returns the JWT `role` claim when present, or `null` for legacy/opaque tokens.
String? getJwtRole(String token) {
  final role = _decodeJwtPayload(token)?['role'];
  if (role is String && role.trim().isNotEmpty) {
    return role.trim().toLowerCase();
  }
  return null;
}

/// Returns `true` when [token] is a 3-part JWT with `role: 'admin'` or `admin: true`.
bool isJwtAdmin(String token) {
  final payload = _decodeJwtPayload(token);
  if (payload == null) return false;
  final role = payload['role'];
  if (role is String && role.trim().toLowerCase() == 'admin') {
    return true;
  }
  return payload['admin'] == true;
}
