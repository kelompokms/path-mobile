import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/utils/token_storage.dart';

class HttpClient extends http.BaseClient with ChangeNotifier {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode
        ? 'http://localhost:3000'
        : 'https://api.pathclass.app',
  );

  final String baseUrl;
  final http.Client _inner;
  final TokenStorage? _tokenStorage;
  String? _token;
  bool? _isAdminOverride;
  Future<void> _storageQueue = Future<void>.value();
  bool _disposed = false;

  HttpClient({
    http.Client? client,
    String? token,
    String? baseUrl,
    this._tokenStorage,
    bool? isAdmin,
  }) : _inner = client ?? http.Client(),
       baseUrl = baseUrl ?? defaultBaseUrl,
       _token = _normalizeToken(token),
       _isAdminOverride = isAdmin;

  static String? _normalizeToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token;
  }

  String? get token => _token;

  bool get isAuthenticated => _token != null;

  String? get role {
    if (!isAuthenticated) return null;
    if (_isAdminOverride == true) return 'admin';
    final jwtRole = _token != null ? getJwtRole(_token!) : null;
    if (jwtRole != null) return jwtRole;
    return isAdmin ? 'admin' : 'murid';
  }

  bool get isAdmin =>
      isAuthenticated &&
      (_isAdminOverride ?? (_token != null && isJwtAdmin(_token!)));

  void setAdmin(bool? value) {
    final prev = isAdmin;
    _isAdminOverride = value;
    if (prev != isAdmin && !_disposed) {
      notifyListeners();
    }
  }

  @visibleForTesting
  Future<void> get pendingPersistence => _storageQueue;

  /// Loads any persisted session token into memory before routing starts,
  /// clearing it if expired.
  Future<void> restoreToken({DateTime? now}) async {
    final storage = _tokenStorage;
    if (storage == null || _token != null) return;

    final stored = _normalizeToken(await storage.readToken());
    if (stored == null || _disposed) return;

    if (isJwtExpired(stored, now: now)) {
      _storageQueue = _storageQueue.then((_) => storage.deleteToken());
      return;
    }

    // Do not clobber a token written while storage read was in flight.
    if (_token != null) return;

    _token = stored;
    notifyListeners();
  }

  void setToken(String? token) {
    final normalized = _normalizeToken(token);
    if (_token == normalized) return;
    _token = normalized;
    _isAdminOverride = null;

    final storage = _tokenStorage;
    if (storage != null) {
      _storageQueue = _storageQueue.then((_) async {
        if (normalized == null) {
          await storage.deleteToken();
        } else {
          await storage.writeToken(normalized);
        }
      });
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  Uri uri(String path) => Uri.parse('$baseUrl$path');

  final Map<String, String> JSON = {'content-type': 'application/json'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sentAuthToken = _token != null && _token!.isNotEmpty;
    if (sentAuthToken) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    final response = await _inner.send(request);
    if (sentAuthToken && response.statusCode == 401) {
      setToken(null);
    }
    return response;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
