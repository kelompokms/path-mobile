import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/token_storage.dart';
import 'package:path_mobile/routes/slide_transition.dart';
import 'package:path_mobile/ui/auth/auth_screen.dart';
import 'package:path_mobile/ui/auth/oauth_callback_screen.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/layout_screen.dart';
import 'package:path_mobile/ui/dashboard/dashboard_screen.dart';

import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/ui/kalender/kalender_screen.dart';

import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';

import 'package:path_mobile/data/register/register_repository.dart';
import 'package:path_mobile/ui/register/register_controller.dart';
import 'package:path_mobile/ui/register/register_screen.dart';

import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';

import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/ui/login/login_controller.dart';
import 'package:path_mobile/ui/login/login_screen.dart';

import 'package:path_mobile/data/profil/profil_repository.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';
import 'package:path_mobile/ui/profil/profil_screen.dart';

final appHttpClient = HttpClient(tokenStorage: const SecureTokenStorage());

Future<void> initializeAuth() => appHttpClient.restoreToken();

GoRouter? _router;
GoRouter get router => _router ??= createRouter(httpClient: appHttpClient);

/// Creates the application [GoRouter] configured with auth protection for
/// `ShellRoute` protected routes and `/` auth routes.
GoRouter createRouter({
  HttpClient? httpClient,
  LoginRepository? loginRepository,
  String? initialLocation,
}) {
  final client = httpClient ?? HttpClient();
  final loginRepo = loginRepository ?? LoginRepository(client);
  final profilRepo = ProfilRepository(client);
  final kelasRepo = KelasRepository(client);
  final kalenderRepo = KalenderRepository(client);
  final pengajarRepo = PengajarRepository(client);
  final registerRepo = RegisterRepository(client);

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: _AuthRefreshNotifier(client),
    routes: [
      ShellRoute(
        redirect: (context, state) => client.isAuthenticated ? null : '/',
        builder: (context, state, child) => LayoutScreen(child: child),
        routes: [
          GoRoute(
            path: '/beranda',
            builder: (context, state) => DashboardScreen(
              kelasController: KelasController(kelasRepo),
              pengajarController: PengajarController(pengajarRepo),
            ),
          ),
          GoRoute(
            path: '/pengajar',
            builder: (context, state) =>
                PengajarScreen(controller: PengajarController(pengajarRepo)),
          ),
          GoRoute(
            path: '/kelas',
            builder: (context, state) =>
                KelasScreen(controller: KelasController(kelasRepo)),
            routes: [
              GoRoute(
                path: ':kode_kelas/anggota',
                builder: (context, state) {
                  final kodeKelas = state.pathParameters['kode_kelas'] ?? '';
                  return AnggotaKelasScreen(
                    kodeKelas: kodeKelas,
                    controller: KelasController(kelasRepo),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/kalender',
            builder: (context, state) =>
                KalenderScreen(controller: KalenderController(kalenderRepo)),
          ),
          GoRoute(
            path: '/profil',
            builder: (context, state) =>
                ProfilScreen(controller: ProfilController(profilRepo)),
          ),
        ],
      ),
      GoRoute(
        path: '/oauth/callback',
        builder: (context, state) => OAuthCallbackScreen(
          callbackUri: state.uri,
          loginRepository: loginRepo,
        ),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            client.isAuthenticated ? '/beranda' : null,
        builder: (context, state) => AuthScreen(loginRepository: loginRepo),
        routes: [
          GoRoute(
            path: 'login',
            pageBuilder: (context, state) => slideUpPage(
              state,
              LoginScreen(controller: LoginController(loginRepo)),
            ),
          ),
          GoRoute(
            path: 'register',
            pageBuilder: (context, state) => slideUpPage(
              state,
              RegisterScreen(
                controller: RegisterController(
                  registerRepo,
                  loginRepository: loginRepo,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Bridges [HttpClient] token updates to `GoRouter.refreshListenable`,
/// deferring notifications made during a build phase until post-frame.
class _AuthRefreshNotifier extends ChangeNotifier {
  final HttpClient _client;
  bool _postFrameScheduled = false;
  bool _disposed = false;

  _AuthRefreshNotifier(this._client) {
    _client.addListener(_handleAuthChanged);
  }

  void _handleAuthChanged() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_postFrameScheduled) return;
      _postFrameScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _postFrameScheduled = false;
        if (!_disposed) {
          notifyListeners();
        }
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.removeListener(_handleAuthChanged);
    super.dispose();
  }
}
