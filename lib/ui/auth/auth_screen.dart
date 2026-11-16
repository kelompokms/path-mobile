import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/ui/auth/oauth_buttons.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/login/login_controller.dart';

class AuthScreen extends StatefulWidget {
  final LoginRepository? loginRepository;

  const AuthScreen({super.key, this.loginRepository});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  LoginController? _oauthController;

  @override
  void initState() {
    super.initState();
    if (widget.loginRepository != null) {
      _oauthController = LoginController(widget.loginRepository!);
    }
  }

  @override
  void dispose() {
    _oauthController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final oauthCtrl = _oauthController;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final hPad = width < ResponsiveBreakpoints.narrow ? 16.0 : 24.0;
            final isWideOrShort =
                width >= ResponsiveBreakpoints.compact || height < 520;

            final actionsContent = ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width >= ResponsiveBreakpoints.compact ? 440 : 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign In'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => context.go('/register'),
                    child: const Text('Sign Up'),
                  ),
                  if (oauthCtrl != null)
                    ListenableBuilder(
                      listenable: oauthCtrl,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          const SizedBox(height: 4),
                          OAuthButtons(
                            loadingProvider: oauthCtrl.oauthLoadingProvider,
                            onProviderTap: oauthCtrl.loginWithOAuth,
                          ),
                          if (oauthCtrl.errorMessage != null)
                            Text(
                              oauthCtrl.errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.error),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );

            if (isWideOrShort) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: 24,
                  ),
                  child: actionsContent,
                ),
              );
            }

            return Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height * 0.45),
                  child: Center(child: actionsContent),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
