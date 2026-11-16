import 'package:flutter/foundation.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/login_repository.dart';

/// Shared OAuth launch state and error handling for auth form controllers.
mixin OAuthControllerMixin on ChangeNotifier {
  @protected
  LoginRepository? get oauthRepository;

  @protected
  bool get isFormLoading;

  OAuthProvider? _oauthLoadingProvider;
  OAuthProvider? get oauthLoadingProvider => _oauthLoadingProvider;

  bool get isBusy => isFormLoading || _oauthLoadingProvider != null;

  bool get supportsOAuth => oauthRepository != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  @protected
  void setErrorMessage(String? message) {
    _errorMessage = message;
  }

  /// Launches OAuth for [provider] and records any launch error.
  Future<bool> loginWithOAuth(OAuthProvider provider) async {
    final repo = oauthRepository;
    if (repo == null) return false;

    _oauthLoadingProvider = provider;
    _errorMessage = null;
    notifyListeners();

    final err = await repo.launchOAuth(provider);

    _oauthLoadingProvider = null;
    _errorMessage = err;
    notifyListeners();

    return err == null;
  }
}
