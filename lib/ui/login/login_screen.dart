import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/auth/oauth_buttons.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/login/login_controller.dart';

class LoginScreen extends StatefulWidget {
  final LoginController _controller;

  const LoginScreen({super.key, required this._controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Like Go's `defer controller.Close()`
    widget._controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (widget._controller.isBusy) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final res = await widget._controller.login();
    if (res && mounted) {
      context.go('/beranda');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ResponsiveAuthSheet(
        builder: (context, viewport, _) {
          final isShort = viewport.maxHeight < 540;
          final sectionSpacing = isShort ? 16.0 : 24.0;
          final fieldSpacing = isShort ? 14.0 : 20.0;

          return ListenableBuilder(
            listenable: widget._controller,
            builder: (context, _) {
              final ctrl = widget._controller;

              return Column(
                spacing: sectionSpacing,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthSheetHeader(
                    title: 'Login',
                    viewportWidth: viewport.maxWidth,
                  ),
                  Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: fieldSpacing,
                      children: [
                        TextFormField(
                          controller: ctrl.emailController,
                          enabled: !ctrl.isBusy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: ctrl.passwordController,
                          enabled: !ctrl.isBusy,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password tidak boleh kosong';
                            }

                            if (value.length < 8) {
                              return 'Password terlalu singkat';
                            }
                            return null;
                          },
                        ),
                        if (ctrl.errorMessage != null)
                          Text(
                            ctrl.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.error),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: ctrl.isBusy ? null : _handleLogin,
                    child: ctrl.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Login'),
                  ),
                  OAuthButtons(
                    loadingProvider: ctrl.oauthLoadingProvider,
                    disabled: ctrl.isLoading,
                    onProviderTap: ctrl.loginWithOAuth,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
