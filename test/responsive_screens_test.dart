import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/login/login_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/data/profil/profil_repository.dart';
import 'package:path_mobile/data/register/register_repository.dart';
import 'package:path_mobile/ui/auth/auth_screen.dart';
import 'package:path_mobile/ui/auth/oauth_callback_screen.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/layout_screen.dart';
import 'package:path_mobile/ui/dashboard/dashboard_screen.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/ui/kalender/kalender_screen.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/login/login_controller.dart';
import 'package:path_mobile/ui/login/login_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';
import 'package:path_mobile/ui/profil/profil_screen.dart';
import 'package:path_mobile/ui/register/register_controller.dart';
import 'package:path_mobile/ui/register/register_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

HttpClient _mockClient({bool emptyClasses = false}) {
  final now = DateTime.now();
  final isoNow = DateTime(
    now.year,
    now.month,
    now.day,
    9,
    30,
  ).toIso8601String();

  final classesJson = emptyClasses
      ? <Map<String, dynamic>>[]
      : [
          {
            'id': 1,
            'nama': 'Matematika Wajib Lanjutan',
            'tingkat': 10,
            'tahun_ajaran': '2026/2027',
            'kode_kelas': 'MAT10A',
            'pengampu': 1,
            'dibuat': isoNow,
          },
          {
            'id': 2,
            'nama': 'Fisika Dasar Eksperimen',
            'tingkat': 11,
            'tahun_ajaran': '2026/2027',
            'kode_kelas': 'FIS11B',
            'pengampu': 1,
            'dibuat': isoNow,
          },
          {
            'id': 3,
            'nama': 'Kimia Organik Terapan',
            'tingkat': 12,
            'tahun_ajaran': '2026/2027',
            'kode_kelas': 'KIM12C',
            'pengampu': 1,
            'dibuat': isoNow,
          },
        ];

  final materiJson = [
    {
      'id': 10,
      'judul': 'Persamaan Kuadrat dan Aplikasinya dalam Kehidupan',
      'deskripsi': 'Pelajari materi persamaan kuadrat lengkap beserta contoh.',
      'lampiran': ['modul_kuadrat.pdf', 'https://example.com/materi-kuadrat'],
      'pengguna_id': 1,
      'kelas_id': 1,
      'tipe_id': 2,
      'dibuat': isoNow,
    },
  ];

  final tugasJson = [
    {
      'id': 20,
      'judul': 'Latihan Soal Bab 1 Persamaan Kuadrat Lengkap',
      'deskripsi': 'Kerjakan semua soal pada lampiran dan unggah jawaban.',
      'lampiran': ['lembar_kerja_bab1.pdf', 'https://example.com/referensi'],
      'pengguna_id': 1,
      'kelas_id': 1,
      'tipe_id': 1,
      'dibuat': isoNow,
    },
  ];

  final kalenderJson = [
    {
      'id': 1,
      'nama_kegiatan': 'Ujian Tengah Semester Ganjil',
      'tanggal_mulai': isoNow,
      'tanggal_selesai': isoNow,
    },
  ];

  final profilJson = {
    'id': 1,
    'username': 'Rin Pratama Putra',
    'email': 'rin.pratama@example.com',
    'phone': '081234567890',
    'profile_picture': '',
  };

  return HttpClient(
    client: MockClient((request) async {
      final path = request.url.path;
      if (path == '/kelas') {
        return http.Response(jsonEncode(classesJson), 200);
      }
      if (path.endsWith('/posts')) {
        final tipe = request.url.queryParameters['tipe'];
        final body = tipe == '2' ? materiJson : tugasJson;
        return http.Response(jsonEncode(body), 200);
      }
      if (path == '/kalender') {
        return http.Response(jsonEncode(kalenderJson), 200);
      }
      if (path == '/pengguna') {
        return http.Response(jsonEncode(profilJson), 200);
      }
      return http.Response(jsonEncode({'message': 'Not found'}), 404);
    }),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  double textScale = 1.0,
  double bottomInset = 0.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.lightTheme,
      builder: (context, widget) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: widget!,
        );
      },
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: scrollables.first,
      );
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required Size size,
  required GoRouter router,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp.router(
      key: UniqueKey(),
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, widget) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: widget!,
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _shellRouter(
  HttpClient client, {
  String initialLocation = '/beranda',
}) {
  final kelasRepo = KelasRepository(client);
  final pengajarRepo = PengajarRepository(client);
  final kalenderRepo = KalenderRepository(client);
  final profilRepo = ProfilRepository(client);

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
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
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('Login')),
      ),
    ],
  );
}

int _gridColumnsCount(WidgetTester tester) {
  final boxes = tester
      .widgetList<ClassCard>(find.byType(ClassCard))
      .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
      .toList();
  if (boxes.isEmpty) return 0;
  final firstRowY = boxes.first;
  return boxes.where((y) => (y - firstRowY).abs() < 1.0).length;
}

void main() {
  group('LayoutScreen responsive navigation', () {
    testWidgets('uses BottomNavigationBar on narrow and standard phones', (
      tester,
    ) async {
      for (final size in [const Size(320, 480), const Size(390, 844)]) {
        final router = _shellRouter(_mockClient());
        addTearDown(router.dispose);
        await _pumpRouter(
          tester,
          size: size,
          textScale: 1.6,
          router: router,
        );

        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      }
    });

    testWidgets(
      'uses compact NavigationRail on 600-1023dp including short height',
      (
        tester,
      ) async {
        for (final size in [
          const Size(600, 900),
          const Size(768, 1024),
          const Size(768, 260),
        ]) {
          final router = _shellRouter(_mockClient());
          addTearDown(router.dispose);
          await _pumpRouter(tester, size: size, router: router);

          expect(find.byType(BottomNavigationBar), findsNothing);
          final rail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );
          expect(rail.extended, isFalse);
        }
      },
    );

    testWidgets('uses extended NavigationRail on >= 1024dp', (tester) async {
      final router = _shellRouter(_mockClient());
      addTearDown(router.dispose);
      await _pumpRouter(tester, size: const Size(1280, 800), router: router);

      expect(find.byType(BottomNavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });
  });

  group('Auth, Login, Register, OAuthCallback responsive screens', () {
    testWidgets('AuthScreen adapts across mobile, landscape, and tablet', (
      tester,
    ) async {
      final client = _mockClient();
      for (final entry in [
        (size: const Size(320, 480), scale: 1.6),
        (size: const Size(667, 375), scale: 1.0),
        (size: const Size(1024, 768), scale: 1.2),
      ]) {
        await _pumpApp(
          tester,
          size: entry.size,
          textScale: entry.scale,
          child: AuthScreen(loginRepository: LoginRepository(client)),
        );
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Sign Up'), findsOneWidget);
        expect(find.text('Google'), findsOneWidget);
      }
    });

    testWidgets('OAuthCallbackScreen adapts and frames with Card on >= 600dp', (
      tester,
    ) async {
      final repo = LoginRepository(_mockClient());
      final uri = Uri.parse(
        'https://api.pathclass.app/oauth/callback?error=access_denied',
      );

      await _pumpApp(
        tester,
        size: const Size(320, 480),
        textScale: 1.5,
        child: OAuthCallbackScreen(callbackUri: uri, loginRepository: repo),
      );
      expect(find.byType(Card), findsNothing);

      await _pumpApp(
        tester,
        size: const Size(840, 700),
        child: OAuthCallbackScreen(callbackUri: uri, loginRepository: repo),
      );
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets(
      'LoginScreen handles narrow 1.6x, landscape, keyboard, and wide',
      (
        tester,
      ) async {
        final repo = LoginRepository(_mockClient());
        for (final scenario in [
          (size: const Size(320, 480), scale: 1.6, inset: 0.0),
          (size: const Size(360, 640), scale: 1.0, inset: 280.0),
          (size: const Size(667, 375), scale: 1.0, inset: 0.0),
          (size: const Size(1024, 768), scale: 1.0, inset: 0.0),
        ]) {
          final ctrl = LoginController(repo);
          await _pumpApp(
            tester,
            size: scenario.size,
            textScale: scenario.scale,
            bottomInset: scenario.inset,
            child: Scaffold(body: LoginScreen(controller: ctrl)),
          );
          expect(find.text('Login'), findsNWidgets(2));
        }
      },
    );

    testWidgets(
      'RegisterScreen handles narrow 1.6x, landscape, keyboard, and wide',
      (
        tester,
      ) async {
        final client = _mockClient();
        final regRepo = RegisterRepository(client);
        final loginRepo = LoginRepository(client);
        for (final scenario in [
          (size: const Size(320, 480), scale: 1.6, inset: 0.0),
          (size: const Size(360, 640), scale: 1.0, inset: 280.0),
          (size: const Size(667, 375), scale: 1.0, inset: 0.0),
          (size: const Size(1024, 768), scale: 1.0, inset: 0.0),
        ]) {
          final ctrl = RegisterController(regRepo, loginRepository: loginRepo);
          await _pumpApp(
            tester,
            size: scenario.size,
            textScale: scenario.scale,
            bottomInset: scenario.inset,
            child: Scaffold(body: RegisterScreen(controller: ctrl)),
          );
          expect(find.text('New Account'), findsOneWidget);
        }
      },
    );
  });

  group('DashboardScreen responsive grids and tabs', () {
    testWidgets('scales class grid columns and toggles tabs cleanly', (
      tester,
    ) async {
      final client = _mockClient();
      final kelasRepo = KelasRepository(client);
      final pengajarRepo = PengajarRepository(client);

      Future<void> pumpAt(Size size, {double scale = 1.0}) async {
        final kCtrl = KelasController(kelasRepo);
        final pCtrl = PengajarController(pengajarRepo);
        addTearDown(kCtrl.dispose);
        addTearDown(pCtrl.dispose);
        await _pumpApp(
          tester,
          size: size,
          textScale: scale,
          child: Scaffold(
            body: DashboardScreen(
              kelasController: kCtrl,
              pengajarController: pCtrl,
            ),
          ),
        );
      }

      await pumpAt(const Size(320, 480), scale: 1.6);
      expect(_gridColumnsCount(tester), 1);

      await tester.tap(find.text('Pengajar'));
      await tester.pumpAndSettle();

      await pumpAt(const Size(390, 844));
      expect(_gridColumnsCount(tester), 2);

      await pumpAt(const Size(768, 1024));
      expect(_gridColumnsCount(tester), 3);

      await pumpAt(const Size(1280, 800));
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 5);
    });
  });

  group('KalenderScreen responsive 1-pane and 2-pane', () {
    testWidgets('uses 1-pane CustomScrollView < 720 and 2-pane >= 720', (
      tester,
    ) async {
      final repo = KalenderRepository(_mockClient());

      for (final scenario in [
        (size: const Size(320, 480), scale: 1.6, expectTwoPane: false),
        (size: const Size(667, 375), scale: 1.0, expectTwoPane: false),
        (size: const Size(768, 1024), scale: 1.4, expectTwoPane: true),
        (size: const Size(1280, 800), scale: 1.0, expectTwoPane: true),
      ]) {
        final ctrl = KalenderController(repo);
        addTearDown(ctrl.dispose);
        await _pumpApp(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          child: Scaffold(body: KalenderScreen(controller: ctrl)),
        );

        expect(
          find.byType(VerticalDivider),
          scenario.expectTwoPane ? findsOneWidget : findsNothing,
        );
        await tester.scrollUntilVisible(
          find.text('Ujian Tengah Semester Ganjil'),
          120,
          scrollable: find
              .descendant(
                of: find.byType(
                  scenario.expectTwoPane ? ListView : CustomScrollView,
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Ujian Tengah Semester Ganjil'), findsOneWidget);
      }
    });
  });

  group('KelasScreen & sub-screens responsive flows', () {
    testWidgets('renders JoinClassForm and sub-screens on narrow & desktop', (
      tester,
    ) async {
      final client = _mockClient();
      final repo = KelasRepository(client);

      for (final scenario in [
        (size: const Size(320, 480), scale: 1.6),
        (size: const Size(1024, 768), scale: 1.0),
      ]) {
        final ctrl = KelasController(repo);
        addTearDown(ctrl.dispose);
        await _pumpApp(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          child: Scaffold(body: KelasScreen(controller: ctrl)),
        );

        await _tapVisible(tester, find.text('Gabung Kelas'));
        await _tapVisible(tester, find.text('Batal'));

        await _tapVisible(tester, find.byType(ClassCard).first);

        await _tapVisible(
          tester,
          find.textContaining('Persamaan Kuadrat').first,
        );
        await _tapVisible(tester, find.text('Bantuan AI'));

        await _tapVisible(tester, find.byIcon(Icons.arrow_back).first);

        await _tapVisible(tester, find.text('Tugas'));
        await _tapVisible(tester, find.textContaining('Latihan Soal').first);
      }
    });
  });

  group('PengajarScreen & sub-screens responsive flows', () {
    testWidgets('renders class code, forms, and Cek Jawaban across sizes', (
      tester,
    ) async {
      final repo = PengajarRepository(_mockClient());

      for (final scenario in [
        (size: const Size(320, 480), scale: 1.6),
        (size: const Size(1024, 768), scale: 1.0),
      ]) {
        final ctrl = PengajarController(repo);
        addTearDown(ctrl.dispose);
        await _pumpApp(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          child: Scaffold(body: PengajarScreen(controller: ctrl)),
        );

        await _tapVisible(tester, find.text('Buat Kelas'));
        await _tapVisible(tester, find.text('Batal'));

        await _tapVisible(tester, find.byType(ClassCard).first);
        expect(find.text('MAT10A'), findsOneWidget);

        await _tapVisible(tester, find.text('Buat Materi'));
        await _tapVisible(tester, find.byIcon(Icons.arrow_back).first);

        await _tapVisible(tester, find.text('Tugas'));
        await _tapVisible(tester, find.text('Tambah Tugas'));
        await _tapVisible(tester, find.byIcon(Icons.arrow_back).first);

        await _tapVisible(tester, find.textContaining('Latihan Soal').first);
        await _tapVisible(tester, find.text('Cek jawaban'));

        await _tapVisible(tester, find.text('Koreksi menggunakan AI'));
      }
    });
  });

  group('ProfilScreen & sub-screens responsive flows', () {
    testWidgets('renders profile and sub-screens across narrow & wide sizes', (
      tester,
    ) async {
      final repo = ProfilRepository(_mockClient());

      for (final scenario in [
        (size: const Size(320, 480), scale: 1.6),
        (size: const Size(667, 375), scale: 1.0),
        (size: const Size(1024, 768), scale: 1.0),
      ]) {
        final ctrl = ProfilController(repo);
        addTearDown(ctrl.dispose);
        await _pumpApp(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          child: Scaffold(body: ProfilScreen(controller: ctrl)),
        );
        expect(find.text('Rin Pratama Putra'), findsOneWidget);

        await _tapVisible(tester, find.text('Edit profil'));
        await _tapVisible(tester, find.byIcon(Icons.arrow_back).first);

        await _tapVisible(tester, find.text('Ganti password'));
        await _tapVisible(tester, find.byIcon(Icons.arrow_back).first);

        await _tapVisible(tester, find.text('Bantuan'));
      }
    });
  });
}
