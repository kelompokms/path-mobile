import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/data/register/register_repository.dart';
import 'package:path_mobile/ui/auth/oauth_buttons.dart';
import 'package:path_mobile/ui/auth/oauth_callback_screen.dart';
import 'package:path_mobile/ui/login/login_controller.dart';
import 'package:path_mobile/ui/login/login_screen.dart';
import 'package:path_mobile/ui/register/register_controller.dart';
import 'package:path_mobile/ui/register/register_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('LoginRepository OAuth', () {
    test('supports only Google OAuth provider', () {
      expect(OAuthProvider.values, [OAuthProvider.google]);
    });

    test('builds Google OAuth URI with mobile redirect_uri', () {
      final client = HttpClient();
      final repo = LoginRepository(client);

      final googleUri = repo.buildOAuthUri(
        OAuthProvider.google,
        clientState: 'sample-client-state-1234',
      );
      expect(googleUri.path, '/auth/oauth/google');
      expect(
        googleUri.queryParameters['redirect_uri'],
        LoginRepository.oauthRedirectUri,
      );
      expect(
        googleUri.queryParameters['client_state'],
        'sample-client-state-1234',
      );
    });

    test('launchOAuth delegates to launcher with client_state and handles failure', () async {
      final client = HttpClient();
      Uri? launchedUri;
      final repo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final err = await repo.launchOAuth(OAuthProvider.google);
      expect(err, isNull);
      expect(launchedUri?.path, '/auth/oauth/google');
      final clientState = launchedUri?.queryParameters['client_state'];
      expect(clientState, isNotNull);
      expect(clientState!.length, greaterThanOrEqualTo(16));

      final failingRepo = LoginRepository(
        client,
        urlLauncher: (_) async => false,
      );
      final failErr = await failingRepo.launchOAuth(OAuthProvider.google);
      expect(failErr, contains('Google'));
      expect(
        failingRepo.completeOAuthCallback(
          Uri.parse('pathmobile://app/oauth/callback?token=jwt.after.fail&state=anything'),
        ),
        contains('State OAuth'),
      );
      expect(client.token, isNull);
    });

    test('completeOAuthCallback verifies state and parses token from query and fragment', () async {
      final client = HttpClient();
      Uri? launchedUri;
      final repo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      await repo.launchOAuth(OAuthProvider.google);
      final queryState = launchedUri!.queryParameters['client_state']!;
      final queryErr = repo.completeOAuthCallback(
        Uri.parse(
          'pathmobile://app/oauth/callback?token=jwt.query.token&state=$queryState',
        ),
      );
      expect(queryErr, isNull);
      expect(client.token, 'jwt.query.token');

      // Replaying the same state is rejected (single-use).
      client.setToken(null);
      final replayErr = repo.completeOAuthCallback(
        Uri.parse(
          'pathmobile://app/oauth/callback?token=jwt.replay.token&state=$queryState',
        ),
      );
      expect(replayErr, contains('State OAuth'));
      expect(client.token, isNull);

      await repo.launchOAuth(OAuthProvider.google);
      final fragmentState = launchedUri!.queryParameters['client_state']!;
      final fragmentErr = repo.completeOAuthCallback(
        Uri.parse(
          'pathmobile://app/oauth/callback#token=jwt.fragment.token&state=$fragmentState',
        ),
      );
      expect(fragmentErr, isNull);
      expect(client.token, 'jwt.fragment.token');
    });

    test('completeOAuthCallback rejects invalid state and handles provider errors and missing token', () async {
      final client = HttpClient();
      Uri? launchedUri;
      final repo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      // Uninitiated callback rejected (Login CSRF protection).
      final uninitiatedErr = repo.completeOAuthCallback(
        Uri.parse('pathmobile://app/oauth/callback?token=evil.jwt.token&state=attacker'),
      );
      expect(uninitiatedErr, contains('State OAuth'));
      expect(client.token, isNull);

      // Mismatched state rejected.
      await repo.launchOAuth(OAuthProvider.google);
      final mismatchErr = repo.completeOAuthCallback(
        Uri.parse('pathmobile://app/oauth/callback?token=evil.jwt.token&state=wrong-state'),
      );
      expect(mismatchErr, contains('State OAuth'));
      expect(client.token, isNull);

      await repo.launchOAuth(OAuthProvider.google);
      final cancelState = launchedUri!.queryParameters['client_state']!;
      final deniedErr = repo.completeOAuthCallback(
        Uri.parse(
          'pathmobile://app/oauth/callback?error=access_denied&state=$cancelState',
        ),
      );
      expect(deniedErr, 'Login OAuth dibatalkan.');
      expect(client.token, isNull);

      await repo.launchOAuth(OAuthProvider.google);
      final emptyState = launchedUri!.queryParameters['client_state']!;
      final emptyErr = repo.completeOAuthCallback(
        Uri.parse('pathmobile://app/oauth/callback?state=$emptyState'),
      );
      expect(emptyErr, 'Token autentikasi OAuth tidak ditemukan.');
      expect(client.token, isNull);
    });
  });

  group('OAuth controllers', () {
    test('LoginController.loginWithOAuth surfaces launch errors', () async {
      final client = HttpClient();
      final repo = LoginRepository(client, urlLauncher: (_) async => false);
      final ctrl = LoginController(repo);
      addTearDown(ctrl.dispose);

      final ok = await ctrl.loginWithOAuth(OAuthProvider.google);
      expect(ok, isFalse);
      expect(ctrl.oauthLoadingProvider, isNull);
      expect(ctrl.errorMessage, isNotNull);
    });

    test('RegisterController.loginWithOAuth surfaces launch errors', () async {
      final client = HttpClient();
      final registerRepo = RegisterRepository(client);
      final loginRepo = LoginRepository(
        client,
        urlLauncher: (_) async => false,
      );
      final ctrl = RegisterController(
        registerRepo,
        loginRepository: loginRepo,
      );
      addTearDown(ctrl.dispose);

      expect(ctrl.supportsOAuth, isTrue);
      final ok = await ctrl.loginWithOAuth(OAuthProvider.google);
      expect(ok, isFalse);
      expect(ctrl.oauthLoadingProvider, isNull);
      expect(ctrl.errorMessage, contains('Google'));
    });
  });

  group('OAuth widgets', () {
    testWidgets('OAuthButtons renders Google SVG button without Discord', (
      tester,
    ) async {
      final tapped = <OAuthProvider>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OAuthButtons(onProviderTap: tapped.add),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Discord'), findsNothing);
      expect(find.text('atau masuk dengan'), findsOneWidget);

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      final svgWidget = tester.widget<SvgPicture>(svgFinder);
      expect(
        svgWidget.bytesLoader,
        isA<SvgAssetLoader>().having(
          (loader) => loader.assetName,
          'assetName',
          'assets/images/google.svg',
        ),
      );

      await tester.tap(find.text('Google'));
      expect(tapped, [OAuthProvider.google]);
    });

    testWidgets('LoginScreen uses google.svg button and launches Google OAuth', (
      tester,
    ) async {
      final client = HttpClient();
      Uri? launchedUri;
      final loginRepo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(controller: LoginController(loginRepo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Discord'), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);

      final googleButton = find.text('Google');
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pump();

      expect(launchedUri?.path, '/auth/oauth/google');
    });

    testWidgets(
      'RegisterScreen uses google.svg button and launches Google OAuth',
      (tester) async {
        final client = HttpClient();
        Uri? launchedUri;
        final registerRepo = RegisterRepository(client);
        final loginRepo = LoginRepository(
          client,
          urlLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RegisterScreen(
              controller: RegisterController(
                registerRepo,
                loginRepository: loginRepo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('atau daftar dengan'), findsOneWidget);
        expect(find.text('Google'), findsOneWidget);
        expect(find.text('Discord'), findsNothing);
        expect(find.byType(SvgPicture), findsOneWidget);

        final googleButton = find.text('Google');
        await tester.ensureVisible(googleButton);
        await tester.tap(googleButton);
        await tester.pump();

        expect(launchedUri?.path, '/auth/oauth/google');
      },
    );

    testWidgets('OAuthCallbackScreen stores token and navigates to /beranda', (
      tester,
    ) async {
      final client = HttpClient();
      Uri? launchedUri;
      final repo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );
      await repo.launchOAuth(OAuthProvider.google);
      final state = launchedUri!.queryParameters['client_state']!;

      var browserClosed = false;
      final router = GoRouter(
        initialLocation: '/oauth/callback?token=valid.jwt.token&state=$state',
        routes: [
          GoRoute(
            path: '/oauth/callback',
            builder: (_, state) => OAuthCallbackScreen(
              callbackUri: state.uri,
              loginRepository: repo,
              closeBrowser: () async {
                browserClosed = true;
              },
            ),
          ),
          GoRoute(
            path: '/beranda',
            builder: (_, _) => const Scaffold(body: Text('Beranda Screen')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(browserClosed, isTrue);
      expect(client.token, 'valid.jwt.token');
      expect(find.text('Beranda Screen'), findsOneWidget);
    });

    testWidgets('OAuthCallbackScreen renders error and back button on error', (
      tester,
    ) async {
      final client = HttpClient();
      Uri? launchedUri;
      final repo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );
      await repo.launchOAuth(OAuthProvider.google);
      final state = launchedUri!.queryParameters['client_state']!;

      final router = GoRouter(
        initialLocation: '/oauth/callback?error=access_denied&state=$state',
        routes: [
          GoRoute(
            path: '/oauth/callback',
            builder: (_, state) => OAuthCallbackScreen(
              callbackUri: state.uri,
              loginRepository: repo,
              closeBrowser: () async {},
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('Login Screen')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(client.token, isNull);
      expect(find.text('Login OAuth dibatalkan.'), findsOneWidget);

      await tester.tap(find.text('Kembali ke Login'));
      await tester.pumpAndSettle();
      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
