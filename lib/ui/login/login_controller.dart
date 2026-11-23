import 'package:flutter/material.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/ui/auth/oauth_controller_mixin.dart';

class LoginController extends ChangeNotifier with OAuthControllerMixin {
  final LoginRepository _repo;

  LoginController(this._repo);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  LoginRepository get oauthRepository => _repo;

  @override
  bool get isFormLoading => _isLoading;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> login() async {
    if (_disposed) return false;
    _isLoading = true;
    setErrorMessage(null);
    _safeNotify();

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      setErrorMessage('email atau password tidak boleh kosong');
      _safeNotify();
      return false;
    }

    final err = await _repo.login(email, password);
    if (_disposed) return err == null;

    _isLoading = false;
    setErrorMessage(err);
    _safeNotify();

    return err == null;
  }

  @override
  void dispose() {
    _disposed = true;
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
