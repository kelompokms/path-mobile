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

  @override
  LoginRepository? get oauthRepository => _loginRepo;

  @override
  bool get isFormLoading => _isLoading;

  Future<bool> register() async {
    _isLoading = true;
    setErrorMessage(null);
    notifyListeners();

    if (usernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _isLoading = false;
      setErrorMessage('username, email, atau password tidak boleh kosong');
      notifyListeners();
      return false;
    }

    final err = await _repo.register(
      usernameController.text,
      emailController.text,
      passwordController.text,
    );

    _isLoading = false;
    setErrorMessage(err);
    notifyListeners();

    return err == null;
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
