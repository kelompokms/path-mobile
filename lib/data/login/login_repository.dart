import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/oauth_state_persistence.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:url_launcher/url_launcher.dart';

typedef OAuthUrlLauncher = Future<bool> Function(Uri uri);

class LoginRepository {
  static const String oauthRedirectUri = 'pathmobile://app/oauth/callback';
  static const Duration _oauthStateTTL = Duration(minutes: 10);

  final HttpClient _client;
  final OAuthUrlLauncher _launchUrl;
  String? _pendingOAuthState;

  LoginRepository(this._client, {OAuthUrlLauncher? urlLauncher})
    : _launchUrl = urlLauncher ?? _defaultLaunchUrl;

  static Future<bool> _defaultLaunchUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  static String _generateClientState() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Builds the backend OAuth initiation URL with the mobile deep-link target.
  Uri buildOAuthUri(OAuthProvider provider, {String? clientState}) {
    final endpoint = _client.uri('/auth/oauth/${provider.id}');
    final params = <String, String>{
      ...endpoint.queryParameters,
      'redirect_uri': oauthRedirectUri,
    };
    if (clientState != null && clientState.isNotEmpty) {
      params['client_state'] = clientState;
    }
    return endpoint.replace(queryParameters: params);
  }

  /// Opens the backend OAuth login flow in an external browser / Custom Tab.
  /// Returns an error message on failure, or `null` when launched.
  Future<String?> launchOAuth(OAuthProvider provider) async {
    final clientState = _generateClientState();
    _pendingOAuthState = clientState;
    savePersistedOAuthState(
      clientState,
      DateTime.now().add(_oauthStateTTL),
    );

    try {
      final launched = await _launchUrl(
        buildOAuthUri(provider, clientState: clientState),
      );
      if (!launched) {
        _pendingOAuthState = null;
        clearPersistedOAuthState();
        return 'Gagal membuka halaman login ${provider.label}.';
      }
      return null;
    } catch (e) {
      _pendingOAuthState = null;
      clearPersistedOAuthState();
      return 'Gagal membuka browser OAuth: $e';
    }
  }

  /// Parses the OAuth callback deep-link URI, verifies state, stores the JWT
  /// token, and returns an error message on failure or `null` on success.
  String? completeOAuthCallback(Uri callbackUri) {
    final expectedState =
        _pendingOAuthState ?? takePersistedOAuthState(DateTime.now());
    _pendingOAuthState = null;
    clearPersistedOAuthState();

    final fragmentParams = callbackUri.fragment.isNotEmpty
        ? Uri.splitQueryString(callbackUri.fragment)
        : const <String, String>{};

    final returnedState =
        callbackUri.queryParameters['state'] ?? fragmentParams['state'] ?? '';
    if (expectedState == null ||
        expectedState.isEmpty ||
        !_constantTimeEquals(returnedState, expectedState)) {
      return 'State OAuth tidak valid atau sesi login telah kedaluwarsa. Silakan coba login ulang.';
    }

    final oauthError =
        callbackUri.queryParameters['error'] ?? fragmentParams['error'];
    if (oauthError != null && oauthError.isNotEmpty) {
      return _mapOAuthError(oauthError);
    }

    final token =
        callbackUri.queryParameters['token'] ?? fragmentParams['token'] ?? '';
    if (token.isEmpty) {
      return 'Token autentikasi OAuth tidak ditemukan.';
    }

    _client.setToken(token);
    return null;
  }

  String _mapOAuthError(String code) {
    return switch (code) {
      'access_denied' => 'Login OAuth dibatalkan.',
      'email_unverified' =>
        'Email akun OAuth belum terverifikasi atau tidak tersedia.',
      'token_exchange_failed' => 'Gagal memverifikasi kode OAuth ke provider.',
      'userinfo_failed' => 'Gagal mengambil profil akun dari provider OAuth.',
      'account_error' => 'Gagal memproses akun OAuth di server.',
      'token_creation_failed' => 'Gagal membuat token autentikasi.',
      _ => 'Login OAuth gagal ($code).',
    };
  }

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
