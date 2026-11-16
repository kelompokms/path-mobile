import 'dart:io';

const String _oauthStateFilename = 'path_mobile_oauth_state.txt';

File _stateFile() =>
    File('${Directory.systemTemp.path}${Platform.pathSeparator}$_oauthStateFilename');

void savePersistedOAuthState(String state, DateTime expiresAt) {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  try {
    _stateFile().writeAsStringSync(
      '${expiresAt.millisecondsSinceEpoch}:$state',
      flush: true,
    );
  } catch (_) {}
}

String? takePersistedOAuthState(DateTime now) {
  if (!(Platform.isAndroid || Platform.isIOS)) return null;
  try {
    final file = _stateFile();
    if (!file.existsSync()) return null;
    final raw = file.readAsStringSync().trim();
    file.deleteSync();
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
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  try {
    final file = _stateFile();
    if (file.existsSync()) {
      file.deleteSync();
    }
  } catch (_) {}
}
