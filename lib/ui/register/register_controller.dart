import 'package:flutter/material.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/data/register/register_repository.dart';
import 'package:path_mobile/ui/auth/oauth_controller_mixin.dart';

class RegisterController extends ChangeNotifier with OAuthControllerMixin {
  final RegisterRepository _repo;
  final LoginRepository? _loginRepo;

  RegisterController(this._repo, {LoginRepository? loginRepository})
    : _loginRepo = loginRepository;

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  LoginRepository? get oauthRepository => _loginRepo;

  @override
  bool get isFormLoading => _isLoading;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> register() async {
    if (_disposed) return false;
    _isLoading = true;
    setErrorMessage(null);
    _safeNotify();

    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _isLoading = false;
      setErrorMessage('username, email, atau password tidak boleh kosong');
      _safeNotify();
      return false;
    }

    final err = await _repo.register(username, email, password);
    if (_disposed) return err == null;

    _isLoading = false;
    setErrorMessage(err);
    _safeNotify();

    return err == null;
  }

  @override
  void dispose() {
    _disposed = true;
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
