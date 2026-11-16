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

  @override
  LoginRepository get oauthRepository => _repo;

  @override
  bool get isFormLoading => _isLoading;

  Future<bool> login() async {
    _isLoading = true;
    setErrorMessage(null);
    notifyListeners();

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _isLoading = false;
      setErrorMessage('email atau password tidak boleh kosong');
      notifyListeners();
      return false;
    }

    final err = await _repo.login(
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
