import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpClient extends http.BaseClient with ChangeNotifier {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.pathclass.app',
  );

  final String baseUrl;
  final http.Client _inner;
  String? _token;

  HttpClient({http.Client? client, String? token, String? baseUrl})
    : _inner = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl,
      _token = _normalizeToken(token);

  static String? _normalizeToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token;
  }

  String? get token => _token;

  bool get isAuthenticated => _token != null;

  void setToken(String? token) {
    final normalized = _normalizeToken(token);
    if (_token == normalized) return;
    _token = normalized;
    notifyListeners();
  }

  Uri uri(String path) => Uri.parse('$baseUrl$path');

  final Map<String, String> JSON = {'content-type': 'application/json'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_token != null && _token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
