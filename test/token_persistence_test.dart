import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/data/profil/profil_repository.dart';
import 'package:path_mobile/data/register/register_repository.dart';
import 'package:path_mobile/routes/router.dart';
import 'package:path_mobile/ui/auth/auth_screen.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/dashboard/dashboard_screen.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/token_storage.dart';

String _encodeJwt(Map<String, dynamic> payload) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final body = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return '$header.$body.signature';
}

HttpClient _createClient({
  required TokenStorage storage,
  bool unauthorizedProtectedRoutes = false,
  String? loginToken,
  String? registerToken,
}) {
  return HttpClient(
    tokenStorage: storage,
    client: MockClient((request) async {
      final path = request.url.path;
      if (path == '/login') {
        return http.Response(
          jsonEncode({'token': loginToken ?? 'login.jwt.token'}),
          200,
        );
      }
      if (path == '/register') {
        return http.Response(
          jsonEncode({'token': registerToken ?? 'register.jwt.token'}),
          201,
        );
      }
      if (unauthorizedProtectedRoutes) {
        return http.Response(
          jsonEncode({'message': 'JWT tidak valid atau tidak ada'}),
          401,
        );
      }
      if (path == '/kelas' || path == '/kalender') {
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response(jsonEncode({'message': 'Not found'}), 404);
    }),
  );
}

void main() {
  group('TokenStorage & JWT expiry', () {
    test('SecureTokenStorage reads, writes, and deletes via FlutterSecureStorage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = SecureTokenStorage();

      expect(await storage.readToken(), isNull);

      await storage.writeToken('saved.jwt.token');
      expect(await storage.readToken(), 'saved.jwt.token');

      await storage.deleteToken();
      expect(await storage.readToken(), isNull);
    });

    test('isJwtExpired detects expired and non-expired JWTs accurately', () {
      final now = DateTime.utc(2026, 11, 16, 12, 0);
      final expiredJwt = _encodeJwt({
        'user_id': 1,
        'exp': now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/
            1000,
      });
      final validJwt = _encodeJwt({
        'user_id': 1,
        'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      });

      expect(isJwtExpired(expiredJwt, now: now), isTrue);
      expect(isJwtExpired(validJwt, now: now), isFalse);
      expect(isJwtExpired('opaque.test.token', now: now), isFalse);
    });
  });

  group('Persistent auth session lifecycle', () {
    testWidgets(
      'login persists token across simulated app restarts and opens /beranda',
      (tester) async {
        final storage = MemoryTokenStorage();
        final validJwt = _encodeJwt({
          'user_id': 7,
          'exp': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 7))
                  .millisecondsSinceEpoch ~/
              1000,
        });

        final initialClient = _createClient(
          storage: storage,
          loginToken: validJwt,
        );
        final loginRepo = LoginRepository(initialClient);

        final err = await loginRepo.login('rin@example.com', 'password123');
        expect(err, isNull);
        await initialClient.pendingPersistence;
        expect(await storage.readToken(), validJwt);

        // Simulate killing app and cold-starting with a fresh HttpClient & GoRouter
        final restartedClient = _createClient(storage: storage);
        await restartedClient.restoreToken();
        expect(restartedClient.isAuthenticated, isTrue);
        expect(restartedClient.token, validJwt);

        final router = createRouter(httpClient: restartedClient);
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          '/beranda',
        );
        expect(find.byType(DashboardScreen), findsOneWidget);
      },
    );

    test('register and OAuth callback persist token to storage, logout clears it', () async {
      final storage = MemoryTokenStorage();
      final client = _createClient(
        storage: storage,
        registerToken: 'reg.jwt.token',
      );

      final regRepo = RegisterRepository(client);
      expect(await regRepo.register('rin', 'rin@example.com', 'pw123456'), isNull);
      await client.pendingPersistence;
      expect(await storage.readToken(), 'reg.jwt.token');

      final profilRepo = ProfilRepository(client);
      profilRepo.logout();
      await client.pendingPersistence;
      expect(await storage.readToken(), isNull);

      Uri? launched;
      final oauthRepo = LoginRepository(
        client,
        urlLauncher: (uri) async {
          launched = uri;
          return true;
        },
      );
      await oauthRepo.launchOAuth(OAuthProvider.google);
      final state = launched!.queryParameters['client_state']!;
      expect(
        oauthRepo.completeOAuthCallback(
          Uri.parse('pathmobile://app/oauth/callback?token=oauth.jwt&state=$state'),
        ),
        isNull,
      );
      await client.pendingPersistence;
      expect(await storage.readToken(), 'oauth.jwt');
    });

    test('restoreToken discards and deletes expired JWT from storage', () async {
      final now = DateTime.utc(2026, 11, 16, 12, 0);
      final expiredJwt = _encodeJwt({
        'user_id': 1,
        'exp': now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
            1000,
      });
      final storage = MemoryTokenStorage(expiredJwt);
      final client = _createClient(storage: storage);

      await client.restoreToken(now: now);
      await client.pendingPersistence;

      expect(client.isAuthenticated, isFalse);
      expect(await storage.readToken(), isNull);
    });

    test('sequential token updates keep final logout state consistent', () async {
      final storage = MemoryTokenStorage();
      final client = _createClient(storage: storage);

      client.setToken('first.jwt');
      client.setToken(null);
      await client.pendingPersistence;

      expect(await storage.readToken(), isNull);
    });

    testWidgets(
      '401 response clears persisted token and redirects protected route to /',
      (tester) async {
        final storage = MemoryTokenStorage('stale.jwt.token');
        final client = _createClient(
          storage: storage,
          unauthorizedProtectedRoutes: true,
        );
        await client.restoreToken();
        expect(client.isAuthenticated, isTrue);

        final router = createRouter(
          httpClient: client,
          initialLocation: '/beranda',
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(client.isAuthenticated, isFalse);
        await client.pendingPersistence;
        expect(await storage.readToken(), isNull);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(find.byType(AuthScreen), findsOneWidget);
      },
    );
  });
}
