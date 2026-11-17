import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/login/login_model.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/data/register/register_model.dart';
import 'package:path_mobile/data/register/register_repository.dart';
import 'package:path_mobile/ui/login/login_controller.dart';
import 'package:path_mobile/ui/register/register_controller.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Auth models', () {
    test('LoginRequest serializes email and password', () {
      const req = LoginRequest(email: 'a@b.com', password: 'secret');
      expect(req.toJson(), {'email': 'a@b.com', 'password': 'secret'});
    });

    test('AuthSuccessResponse parses token and defaults to empty string', () {
      expect(
        AuthSuccessResponse.fromJson({'token': 'abc.def.ghi'}).token,
        'abc.def.ghi',
      );
      expect(AuthSuccessResponse.fromJson({}).token, '');
    });

    test('RegisterRequest serializes username, email, and password', () {
      const req = RegisterRequest(
        username: 'budi',
        email: 'budi@example.com',
        password: 'password123',
      );
      expect(req.toJson(), {
        'username': 'budi',
        'email': 'budi@example.com',
        'password': 'password123',
      });
    });
  });

  group('LoginRepository.login', () {
    test('stores token and returns null on 200 success', () async {
      final client = HttpClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/login');
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'password': 'secret',
          });
          return http.Response(jsonEncode({'token': 'jwt.token.value'}), 200);
        }),
      );
      final repo = LoginRepository(client);

      final err = await repo.login('user@example.com', 'secret');
      expect(err, isNull);
      expect(client.token, 'jwt.token.value');
    });

    test('returns Token not found when 200 payload has empty token', () async {
      final client = HttpClient(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'token': ''}), 200),
        ),
      );
      final repo = LoginRepository(client);

      final err = await repo.login('user@example.com', 'secret');
      expect(err, 'Token not found');
      expect(client.token, isNull);
    });

    test('returns server message or fallback on non-200 status', () async {
      final repoWithMsg = LoginRepository(
        HttpClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'message': 'Email atau password salah'}),
              401,
            ),
          ),
        ),
      );
      expect(
        await repoWithMsg.login('u@x.com', 'wrong'),
        'Email atau password salah',
      );

      final repoFallback = LoginRepository(
        HttpClient(client: MockClient((_) async => http.Response('{}', 500))),
      );
      expect(await repoFallback.login('u@x.com', 'wrong'), 'Login failed');
    });

    test('handles TimeoutException and network exceptions', () async {
      final timeoutRepo = LoginRepository(
        HttpClient(
          client: MockClient((_) => throw TimeoutException('timeout')),
        ),
      );
      expect(
        await timeoutRepo.login('u@x.com', 'secret'),
        'Request timed out. Please try again.',
      );

      final netRepo = LoginRepository(
        HttpClient(client: MockClient((_) => throw StateError('offline'))),
      );
      expect(
        await netRepo.login('u@x.com', 'secret'),
        contains('Network error:'),
      );
    });
  });

  group('LoginController', () {
    test('validates empty email or password without calling API', () async {
      var called = false;
      final repo = LoginRepository(
        HttpClient(
          client: MockClient((_) async {
            called = true;
            return http.Response('{}', 200);
          }),
        ),
      );
      final ctrl = LoginController(repo);
      addTearDown(ctrl.dispose);

      ctrl.emailController.text = 'user@example.com';
      expect(await ctrl.login(), isFalse);
      expect(ctrl.errorMessage, 'email atau password tidak boleh kosong');
      expect(ctrl.isLoading, isFalse);
      expect(called, isFalse);
    });

    test('updates loading and errorMessage across success and failure', () async {
      var status = 200;
      final client = HttpClient(
        client: MockClient((_) async {
          if (status == 200) {
            return http.Response(jsonEncode({'token': 'ok.jwt'}), 200);
          }
          return http.Response(jsonEncode({'message': 'Akun terkunci'}), 403);
        }),
      );
      final ctrl = LoginController(LoginRepository(client));
      addTearDown(ctrl.dispose);

      var notifications = 0;
      ctrl.addListener(() => notifications++);

      ctrl.emailController.text = 'user@example.com';
      ctrl.passwordController.text = 'secret';
      expect(await ctrl.login(), isTrue);
      expect(ctrl.errorMessage, isNull);
      expect(ctrl.isLoading, isFalse);
      expect(client.token, 'ok.jwt');
      expect(notifications, greaterThanOrEqualTo(2));

      status = 403;
      expect(await ctrl.login(), isFalse);
      expect(ctrl.errorMessage, 'Akun terkunci');
      expect(ctrl.isLoading, isFalse);
    });
  });

  group('RegisterRepository.register', () {
    test('accepts 200/201 with token and stores it', () async {
      final client = HttpClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/register');
          expect(jsonDecode(request.body), {
            'username': 'Siti',
            'email': 'siti@example.com',
            'password': 'password123',
          });
          return http.Response(jsonEncode({'token': 'reg.jwt.token'}), 201);
        }),
      );
      final repo = RegisterRepository(client);

      final err = await repo.register(
        'Siti',
        'siti@example.com',
        'password123',
      );
      expect(err, isNull);
      expect(client.token, 'reg.jwt.token');
    });

    test('handles empty token, non-2xx messages, timeout, and network errors', () async {
      final emptyTokenRepo = RegisterRepository(
        HttpClient(
          client: MockClient(
            (_) async => http.Response(jsonEncode({'token': ''}), 201),
          ),
        ),
      );
      expect(
        await emptyTokenRepo.register('Siti', 'siti@example.com', 'pw'),
        'Failed to register. Please try again.',
      );

      final errMsgRepo = RegisterRepository(
        HttpClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'message': 'Email sudah terdaftar'}),
              400,
            ),
          ),
        ),
      );
      expect(
        await errMsgRepo.register('Siti', 'siti@example.com', 'pw'),
        'Email sudah terdaftar',
      );

      final timeoutRepo = RegisterRepository(
        HttpClient(client: MockClient((_) => throw TimeoutException('to'))),
      );
      expect(
        await timeoutRepo.register('Siti', 'siti@example.com', 'pw'),
        'Request timed out. Please try again.',
      );

      final netRepo = RegisterRepository(
        HttpClient(client: MockClient((_) => throw StateError('down'))),
      );
      expect(
        await netRepo.register('Siti', 'siti@example.com', 'pw'),
        contains('Network error:'),
      );
    });
  });

  group('RegisterController & OAuthControllerMixin', () {
    test('validates blank fields and runs register flow', () async {
      var called = false;
      final regRepo = RegisterRepository(
        HttpClient(
          client: MockClient((_) async {
            called = true;
            return http.Response(jsonEncode({'token': 'new.jwt'}), 201);
          }),
        ),
      );
      final ctrl = RegisterController(regRepo);
      addTearDown(ctrl.dispose);

      expect(ctrl.supportsOAuth, isFalse);
      expect(await ctrl.loginWithOAuth(OAuthProvider.google), isFalse);

      ctrl.usernameController.text = 'Budi';
      expect(await ctrl.register(), isFalse);
      expect(
        ctrl.errorMessage,
        'username, email, atau password tidak boleh kosong',
      );
      expect(called, isFalse);

      ctrl.emailController.text = 'budi@example.com';
      ctrl.passwordController.text = 'password123';
      expect(await ctrl.register(), isTrue);
      expect(ctrl.errorMessage, isNull);
      expect(called, isTrue);
    });

    test('OAuthControllerMixin updates busy and loading state while launching', () async {
      final completer = Completer<bool>();
      final loginRepo = LoginRepository(
        HttpClient(),
        urlLauncher: (_) => completer.future,
      );
      final ctrl = RegisterController(
        RegisterRepository(HttpClient()),
        loginRepository: loginRepo,
      );
      addTearDown(ctrl.dispose);

      expect(ctrl.supportsOAuth, isTrue);
      final future = ctrl.loginWithOAuth(OAuthProvider.google);
      expect(ctrl.oauthLoadingProvider, OAuthProvider.google);
      expect(ctrl.isBusy, isTrue);

      completer.complete(true);
      expect(await future, isTrue);
      expect(ctrl.oauthLoadingProvider, isNull);
      expect(ctrl.isBusy, isFalse);
      expect(ctrl.errorMessage, isNull);
    });
  });
}
