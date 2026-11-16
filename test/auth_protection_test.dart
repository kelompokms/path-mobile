import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/routes/router.dart';
import 'package:path_mobile/ui/auth/auth_screen.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/dashboard/dashboard_screen.dart';
import 'package:path_mobile/ui/kalender/kalender_screen.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/login/login_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/ui/profil/profil_screen.dart';
import 'package:path_mobile/ui/register/register_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

HttpClient _createMockHttpClient({
  String? token,
  List<String>? requestedPaths,
}) {
  return HttpClient(
    token: token,
    client: MockClient((request) async {
      final path = request.url.path;
      requestedPaths?.add(path);

      if (path == '/login') {
        return http.Response(jsonEncode({'token': 'login.jwt.token'}), 200);
      }
      if (path == '/register') {
        return http.Response(jsonEncode({'token': 'register.jwt.token'}), 201);
      }
      if (path == '/kelas' || path == '/kalender') {
        return http.Response(jsonEncode([]), 200);
      }
      if (path == '/pengguna') {
        return http.Response(
          jsonEncode({
            'id': 1,
            'username': 'Rin Pratama',
            'email': 'rin@example.com',
            'phone': '08123456789',
            'profile_picture': '',
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'message': 'Not found'}), 404);
    }),
  );
}

Future<void> _pumpAppRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      key: UniqueKey(),
      theme: AppTheme.lightTheme,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

String _currentPath(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

void main() {
  group('HttpClient authentication state', () {
    test('normalizes empty tokens and notifies listeners on changes', () {
      final client = HttpClient(token: '   ');
      expect(client.token, isNull);
      expect(client.isAuthenticated, isFalse);

      var notifications = 0;
      client.addListener(() => notifications++);

      client.setToken('');
      expect(notifications, 0);

      client.setToken('jwt.token');
      expect(client.isAuthenticated, isTrue);
      expect(notifications, 1);

      // Setting the same token does not re-notify.
      client.setToken('jwt.token');
      expect(notifications, 1);

      client.setToken(null);
      expect(client.isAuthenticated, isFalse);
      expect(notifications, 2);
    });
  });

  group('Auth protection when unauthenticated', () {
    testWidgets('stays at / when unauthenticated', (tester) async {
      final client = _createMockHttpClient();
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);

      expect(_currentPath(router), '/');
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('allows /login and /register when unauthenticated', (
      tester,
    ) async {
      final client = _createMockHttpClient();
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);

      router.go('/login');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);

      router.go('/register');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/register');
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('redirects all ShellRoute protected routes to /', (
      tester,
    ) async {
      const protectedRoutes = [
        '/beranda',
        '/pengajar',
        '/kelas',
        '/kalender',
        '/profil',
      ];

      for (final route in protectedRoutes) {
        final requestedPaths = <String>[];
        final client = _createMockHttpClient(requestedPaths: requestedPaths);
        final router = createRouter(
          httpClient: client,
          initialLocation: route,
        );
        addTearDown(router.dispose);

        await _pumpAppRouter(tester, router);

        expect(_currentPath(router), '/', reason: 'initialLocation $route');
        expect(find.byType(AuthScreen), findsOneWidget);
        expect(requestedPaths, isEmpty);
      }

      final requestedPaths = <String>[];
      final client = _createMockHttpClient(requestedPaths: requestedPaths);
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      for (final route in protectedRoutes) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(_currentPath(router), '/', reason: 'router.go($route)');
        expect(find.byType(AuthScreen), findsOneWidget);
      }
      expect(requestedPaths, isEmpty);
    });
  });

  group('Auth protection when authenticated', () {
    testWidgets('redirects / directly to /beranda', (tester) async {
      final client = _createMockHttpClient(token: 'valid.jwt.token');
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);

      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('redirects /login and /register to /beranda', (tester) async {
      final client = _createMockHttpClient(token: 'valid.jwt.token');
      final router = createRouter(
        httpClient: client,
        initialLocation: '/login',
      );
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);

      router.go('/register');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('allows navigating across all ShellRoute protected routes', (
      tester,
    ) async {
      final client = _createMockHttpClient(token: 'valid.jwt.token');
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);

      router.go('/pengajar');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/pengajar');
      expect(find.byType(PengajarScreen), findsOneWidget);

      router.go('/kelas');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/kelas');
      expect(find.byType(KelasScreen), findsOneWidget);

      router.go('/kalender');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/kalender');
      expect(find.byType(KalenderScreen), findsOneWidget);

      router.go('/profil');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/profil');
      expect(find.byType(ProfilScreen), findsOneWidget);
    });
  });

  group('Auth state transitions', () {
    testWidgets('token assignment on / automatically redirects to /beranda', (
      tester,
    ) async {
      final client = _createMockHttpClient();
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/');

      client.setToken('new.jwt.token');
      await tester.pumpAndSettle();

      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('clearing token on protected route redirects to /', (
      tester,
    ) async {
      final client = _createMockHttpClient(token: 'valid.jwt.token');
      final router = createRouter(
        httpClient: client,
        initialLocation: '/kelas',
      );
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/kelas');
      expect(find.byType(KelasScreen), findsOneWidget);

      client.setToken(null);
      await tester.pumpAndSettle();

      expect(_currentPath(router), '/');
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('login form submission redirects to /beranda', (tester) async {
      final client = _createMockHttpClient();
      final router = createRouter(
        httpClient: client,
        initialLocation: '/login',
      );
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/login');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'rin@example.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(client.isAuthenticated, isTrue);
      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('register form submission redirects to /beranda', (
      tester,
    ) async {
      final client = _createMockHttpClient();
      final router = createRouter(
        httpClient: client,
        initialLocation: '/register',
      );
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/register');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'rin');
      await tester.enterText(fields.at(1), 'rin@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();

      expect(client.isAuthenticated, isTrue);
      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('logout on ProfilScreen clears token and protects routes', (
      tester,
    ) async {
      final client = _createMockHttpClient(token: 'valid.jwt.token');
      final router = createRouter(
        httpClient: client,
        initialLocation: '/profil',
      );
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);
      expect(_currentPath(router), '/profil');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Keluar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Ya'));
      await tester.pumpAndSettle();

      expect(client.isAuthenticated, isFalse);
      expect(_currentPath(router), '/login');

      router.go('/beranda');
      await tester.pumpAndSettle();
      expect(_currentPath(router), '/');
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('OAuth callback works through guarded router without build errors', (
      tester,
    ) async {
      final client = _createMockHttpClient();
      Uri? launchedUri;
      final loginRepo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launchedUri = uri;
          return true;
        },
      );
      await loginRepo.launchOAuth(OAuthProvider.google);
      final state = launchedUri!.queryParameters['client_state']!;

      final router = createRouter(
        httpClient: client,
        loginRepository: loginRepo,
        initialLocation: '/oauth/callback?token=oauth.jwt.token&state=$state',
      );
      addTearDown(router.dispose);

      await _pumpAppRouter(tester, router);

      expect(client.token, 'oauth.jwt.token');
      expect(_currentPath(router), '/beranda');
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
