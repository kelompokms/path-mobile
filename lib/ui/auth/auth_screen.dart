import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/ui/auth/oauth_buttons.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/login/login_controller.dart';

class AuthScreen extends StatefulWidget {
  static const String logoAsset = 'assets/images/path.svg';

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
            final vPad = height < 420 ? 16.0 : 24.0;
            final isWideOrShort =
                width >= ResponsiveBreakpoints.compact || height < 520;
            final logoSize = height < 520
                ? 96.0
                : width < ResponsiveBreakpoints.narrow
                ? 144.0
                : width < ResponsiveBreakpoints.compact
                ? 176.0
                : 184.0;

            final logo = Center(
              child: SvgPicture.asset(
                AuthScreen.logoAsset,
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
                semanticsLabel: 'Logo PATH',
              ),
            );

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
                      elevation: AppTheme.cardElevation,
                      shadowColor: AppTheme.shadowColor,
                      side: AppTheme.thinBorderSide,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign In'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
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
                    vertical: vPad,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      SizedBox(height: height < 520 ? 12 : 24),
                      actionsContent,
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, height - vPad * 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height * 0.35),
                      child: logo,
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height * 0.45),
                      child: Center(child: actionsContent),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
