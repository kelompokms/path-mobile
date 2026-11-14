import 'package:go_router/go_router.dart';

import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/routes/slide_transition.dart';
import 'package:path_mobile/ui/auth/auth_screen.dart';
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

final _httpClient = HttpClient();

final _loginRepo = LoginRepository(_httpClient);
final _profilRepo = ProfilRepository(_httpClient);
final _kelasRepo = KelasRepository(_httpClient);
final _kalenderRepo = KalenderRepository(_httpClient);
final _pengajarRepo = PengajarRepository(_httpClient);
final _registerRepo = RegisterRepository(_httpClient);

final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => LayoutScreen(child: child),
      routes: [
        GoRoute(
          path: '/beranda',
          builder: (context, state) => DashboardScreen(
            kelasController: KelasController(_kelasRepo),
            pengajarController: PengajarController(_pengajarRepo),
          ),
        ),
        GoRoute(
          path: '/pengajar',
          builder: (context, state) =>
              PengajarScreen(controller: PengajarController(_pengajarRepo)),
        ),
        GoRoute(
          path: '/kelas',
          builder: (context, state) =>
              KelasScreen(controller: KelasController(_kelasRepo)),
        ),
        GoRoute(
          path: '/kalender',
          builder: (context, state) =>
              KalenderScreen(controller: KalenderController(_kalenderRepo)),
        ),
        GoRoute(
          path: '/profil',
          builder: (context, state) =>
              ProfilScreen(controller: ProfilController(_profilRepo)),
        ),
      ],
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthScreen(),
      routes: [
        GoRoute(
          path: 'login',
          pageBuilder: (context, state) => slideUpPage(
            state,
            LoginScreen(controller: LoginController(_loginRepo)),
          ),
        ),
        GoRoute(
          path: 'register',
          pageBuilder: (context, state) => slideUpPage(
            state,
            RegisterScreen(controller: RegisterController(_registerRepo)),
          ),
        ),
      ],
    ),
  ],
);
