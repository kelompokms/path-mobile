import 'package:flutter/foundation.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/login_repository.dart';

/// Shared OAuth launch state and error handling for auth form controllers.
mixin OAuthControllerMixin on ChangeNotifier {
  @protected
  LoginRepository? get oauthRepository;

  @protected
  bool get isFormLoading;

  @protected
  bool get isDisposed => false;

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
    if (repo == null || isDisposed) return false;

    _oauthLoadingProvider = provider;
    _errorMessage = null;
    if (!isDisposed) notifyListeners();

    final err = await repo.launchOAuth(provider);
    if (isDisposed) return err == null;

    _oauthLoadingProvider = null;
    _errorMessage = err;
    notifyListeners();

    return err == null;
  }
}
