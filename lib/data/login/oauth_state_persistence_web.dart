import 'dart:js_interop';

const String _oauthStateKey = 'path_mobile_oauth_state';

@JS('sessionStorage.setItem')
external void _sessionStorageSetItem(String key, String value);

@JS('sessionStorage.getItem')
external String? _sessionStorageGetItem(String key);

@JS('sessionStorage.removeItem')
external void _sessionStorageRemoveItem(String key);

void savePersistedOAuthState(String state, DateTime expiresAt) {
  try {
    _sessionStorageSetItem(
      _oauthStateKey,
      '${expiresAt.millisecondsSinceEpoch}:$state',
    );
  } catch (_) {}
}

String? takePersistedOAuthState(DateTime now) {
  try {
    final raw = _sessionStorageGetItem(_oauthStateKey)?.trim();
    _sessionStorageRemoveItem(_oauthStateKey);
    if (raw == null || raw.isEmpty) return null;
    final sep = raw.indexOf(':');
    if (sep <= 0) return null;
    final expiresMs = int.tryParse(raw.substring(0, sep));
    final state = raw.substring(sep + 1);
    if (expiresMs == null ||
        state.isEmpty ||
        now.millisecondsSinceEpoch > expiresMs) {
      return null;
    }
    return state;
  } catch (_) {
    return null;
  }
}

void clearPersistedOAuthState() {
  try {
    _sessionStorageRemoveItem(_oauthStateKey);
  } catch (_) {}
}
