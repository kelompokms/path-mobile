import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/token_storage.dart';
import 'package:path_mobile/routes/slide_transition.dart';
import 'package:path_mobile/data/admin/admin_repository.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/admin/admin_dashboard_screen.dart';
import 'package:path_mobile/ui/admin/admin_kelas_screen.dart';
import 'package:path_mobile/ui/admin/admin_users_screen.dart';
import 'package:path_mobile/ui/auth/auth_screen.dart';
import 'package:path_mobile/ui/auth/oauth_callback_screen.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/layout_screen.dart';
import 'package:path_mobile/ui/dashboard/dashboard_controller.dart';
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

/// Holds router-scoped controllers for the active authenticated session so
/// `GoRouter` route rebuilds (e.g. pushing `/profil` or syncing role) preserve
/// loaded state instead of wiping mounted screens blank or leaking controllers.
class _RouterControllerScope {
  final HttpClient _client;
  final AdminRepository _adminRepo;
  final KelasRepository _kelasRepo;
  final PengajarRepository _pengajarRepo;
  final KalenderRepository _kalenderRepo;
  final ProfilRepository _profilRepo;

  String? _sessionToken;
  bool? _dashboardIsGuru;

  AdminController? _adminController;
  KelasController? _kelasController;
  PengajarController? _pengajarController;
  KalenderController? _kalenderController;
  ProfilController? _profilController;
  DashboardController? _dashboardController;

  _RouterControllerScope(
    this._client,
    this._adminRepo,
    this._kelasRepo,
    this._pengajarRepo,
    this._kalenderRepo,
    this._profilRepo,
  ) : _sessionToken = _client.token;

  void syncSession() {
    if (_sessionToken == _client.token) return;
    _sessionToken = _client.token;
    disposeAll();
  }

  AdminController get adminController {
    syncSession();
    return _adminController ??= AdminController(_adminRepo);
  }

  KelasController get kelasController {
    syncSession();
    return _kelasController ??= KelasController(_kelasRepo);
  }

  PengajarController get pengajarController {
    syncSession();
    return _pengajarController ??= PengajarController(_pengajarRepo);
  }

  KalenderController get kalenderController {
    syncSession();
    return _kalenderController ??= KalenderController(_kalenderRepo);
  }

  ProfilController get profilController {
    syncSession();
    return _profilController ??= ProfilController(_profilRepo);
  }

  DashboardController get dashboardController {
    syncSession();
    final isGuru = _client.isGuru;
    if (_dashboardController != null && _dashboardIsGuru != isGuru) {
      _dashboardController!.dispose();
      _dashboardController = null;
    }
    _dashboardIsGuru = isGuru;
    return _dashboardController ??= DashboardController(
      isGuruRole: isGuru,
      kelasController: kelasController,
      pengajarController: pengajarController,
      kalenderRepository: _kalenderRepo,
    );
  }

  void disposeAll() {
    _dashboardController?.dispose();
    _dashboardController = null;
    _dashboardIsGuru = null;
    _adminController?.dispose();
    _adminController = null;
    _kelasController?.dispose();
    _kelasController = null;
    _pengajarController?.dispose();
    _pengajarController = null;
    _kalenderController?.dispose();
    _kalenderController = null;
    _profilController?.dispose();
    _profilController = null;
  }
}

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
  final adminRepo = AdminRepository(client);
  final registerRepo = RegisterRepository(client);

  final controllers = _RouterControllerScope(
    client,
    adminRepo,
    kelasRepo,
    pengajarRepo,
    kalenderRepo,
    profilRepo,
  );

  final resolvedInitialLocation =
      initialLocation ??
      (kIsWeb && Uri.base.path == '/oauth/callback' ? '/oauth/callback' : null);

  return GoRouter(
    initialLocation: resolvedInitialLocation,
    refreshListenable: _AuthRefreshNotifier(
      client,
      controllers.syncSession,
    ),
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.secondaryText,
              ),
              const Text(
                'Halaman tidak ditemukan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              FilledButton(
                onPressed: () =>
                    context.go(client.isAuthenticated ? '/beranda' : '/'),
                child: Text(
                  client.isAuthenticated
                      ? 'Kembali ke Beranda'
                      : 'Kembali ke Halaman Awal',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      ShellRoute(
        redirect: (context, state) => client.isAuthenticated ? null : '/',
        builder: (context, state, child) => LayoutScreen(
          isAdmin: client.isAdmin,
          userRole: client.role,
          profilController: client.isAdmin ? controllers.profilController : null,
          onOpenProfile: () => GoRouter.of(context).push('/profil'),
          onLogout: () async {
            profilRepo.logout();
            await client.flushPersistence();
            if (context.mounted) {
              context.go('/login');
            }
          },
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/beranda',
            builder: (context, state) => client.isAdmin
                ? AdminDashboardScreen(
                    controller: controllers.adminController,
                    kalenderRepository: kalenderRepo,
                  )
                : DashboardScreen(
                    controller: controllers.dashboardController,
                    onOpenAllClasses: () => GoRouter.of(context).go('/kelas'),
                    onOpenCalendar: () => GoRouter.of(context).go('/kalender'),
                  ),
          ),
          GoRoute(
            path: '/admin/pengguna',
            redirect: (context, state) => client.isAdmin ? null : '/beranda',
            builder: (context, state) =>
                AdminUsersScreen(controller: controllers.adminController),
          ),
          GoRoute(
            path: '/pengajar',
            redirect: (context, state) => client.isAdmin ? '/beranda' : null,
            builder: (context, state) =>
                PengajarScreen(controller: controllers.pengajarController),
          ),
          GoRoute(
            path: '/kelas',
            builder: (context, state) => client.isAdmin
                ? AdminKelasScreen(
                    controller: controllers.adminController,
                    kelasRepository: kelasRepo,
                  )
                : KelasScreen(
                    controller: controllers.kelasController,
                    pengajarController: controllers.pengajarController,
                    isGuruRole: client.isGuru,
                  ),
            routes: [
              GoRoute(
                path: ':kode_kelas/anggota',
                builder: (context, state) {
                  final kodeKelas = state.pathParameters['kode_kelas'] ?? '';
                  return AnggotaKelasScreen(
                    kodeKelas: kodeKelas,
                    controller: controllers.kelasController,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/kalender',
            builder: (context, state) => KalenderScreen(
              controller: controllers.kalenderController,
              isAdmin: client.isAdmin,
            ),
          ),
          GoRoute(
            path: '/profil',
            builder: (context, state) =>
                ProfilScreen(controller: controllers.profilController),
          ),
        ],
      ),
      GoRoute(
        path: '/oauth/callback',
        builder: (context, state) {
          final uri =
              (kIsWeb &&
                  state.uri.fragment.isEmpty &&
                  state.uri.queryParameters.isEmpty &&
                  Uri.base.path == '/oauth/callback')
              ? Uri.base
              : state.uri;
          return OAuthCallbackScreen(
            callbackUri: uri,
            loginRepository: loginRepo,
          );
        },
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
  final VoidCallback? _onAuthChanged;
  bool _postFrameScheduled = false;
  bool _disposed = false;

  _AuthRefreshNotifier(this._client, [this._onAuthChanged]) {
    _client.addListener(_handleAuthChanged);
  }

  void _handleAuthChanged() {
    if (_disposed) return;
    _onAuthChanged?.call();
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
