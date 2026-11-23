import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CloseInAppBrowserFn = Future<void> Function();

class OAuthCallbackScreen extends StatefulWidget {
  final Uri callbackUri;
  final LoginRepository loginRepository;
  final CloseInAppBrowserFn? closeBrowser;

  const OAuthCallbackScreen({
    super.key,
    required this.callbackUri,
    required this.loginRepository,
    this.closeBrowser,
  });

  @override
  State<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<OAuthCallbackScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processCallback();
  }

  @override
  void didUpdateWidget(covariant OAuthCallbackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callbackUri != widget.callbackUri) {
      setState(() {
        _errorMessage = null;
        _processCallback();
      });
    }
  }

  void _processCallback() {
    if (!kIsWeb) {
      final closeFn = widget.closeBrowser ?? closeInAppWebView;
      unawaited(
        Future<void>.sync(closeFn).catchError((_) {}),
      );
    }

    final effectiveUri =
        (kIsWeb &&
            widget.callbackUri.fragment.isEmpty &&
            widget.callbackUri.queryParameters.isEmpty &&
            Uri.base.path == '/oauth/callback')
        ? Uri.base
        : widget.callbackUri;

    final err = widget.loginRepository.completeOAuthCallback(effectiveUri);
    if (err == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/beranda');
        }
      });
      return;
    }

    _errorMessage = err;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isWide = width >= ResponsiveBreakpoints.compact;
            final padding = responsiveHorizontalPadding(width);

            final content = ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 460 : 400),
              child: _errorMessage == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        CircularProgressIndicator(),
                        Text(
                          'Menyelesaikan login OAuth...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.text),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 240 : double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Kembali ke Login'),
                          ),
                        ),
                      ],
                    ),
            );

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: isWide
                    ? Card(
                        elevation: AppTheme.cardElevation,
                        shadowColor: AppTheme.shadowColor,
                        color: AppColors.card,
                        surfaceTintColor: Colors.transparent,
                        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: content,
                        ),
                      )
                    : content,
              ),
            );
          },
        ),
      ),
    );
  }
}
