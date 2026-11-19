import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/admin/admin_repository.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/routes/router.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/admin/admin_dashboard_screen.dart';
import 'package:path_mobile/ui/admin/admin_kelas_screen.dart';
import 'package:path_mobile/ui/admin/admin_users_screen.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/dashboard/dashboard_screen.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/ui/kalender/kalender_screen.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/ui/profil/profil_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

String _adminJwt({bool isAdmin = true, String? role}) {
  final effectiveRole = role ?? (isAdmin ? 'admin' : 'murid');
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'user_id': 1,
        'admin': effectiveRole == 'admin',
        'role': effectiveRole,
      }),
    ),
  );
  return '$header.$payload.sig';
}

HttpClient _createAdminMockClient({
  required DateTime today,
  bool failUsers = false,
}) {
  final kalenderEvents = <Map<String, dynamic>>[
    {
      'id': 1,
      'nama_kegiatan': 'Upacara Bendera',
      'keterangan': 'Wajib pakai seragam lengkap',
      'tanggal_mulai': KalenderController.formatApiDate(today),
      'tanggal_selesai': KalenderController.formatApiDate(today),
    },
  ];

  final guruUsers = <Map<String, dynamic>>[
    {
      'id': 2,
      'nama': 'Eko Kusnandar',
      'email': 'eko@school.id',
      'phone': '',
      'profile_picture': '',
      'role': 'guru',
      'kelas': ['X PPLG 1', 'X PPLG 2'],
    },
  ];

  final muridUsers = <Map<String, dynamic>>[
    {
      'id': 5,
      'nama': 'Aji Sasongko',
      'email': 'aji@school.id',
      'phone': '',
      'profile_picture': '',
      'role': 'murid',
      'kelas': ['X PPLG 1'],
    },
  ];

  final classesJson = <Map<String, dynamic>>[
    {
      'id': 1,
      'nama': 'X PPLG 1',
      'deskripsi': 'Pemrograman Dasar',
      'tingkat': 10,
      'tahun_ajaran': '2026/2027',
      'kode_kelas': 'PPLG10',
      'pengampu': 2,
      'nama_pengampu': 'Eko Kusnandar',
      'dibuat': today.toIso8601String(),
    },
    {
      'id': 2,
      'nama': 'XI RPL 1',
      'deskripsi': 'Basis Data',
      'tingkat': 11,
      'tahun_ajaran': '2026/2027',
      'kode_kelas': 'RPL11',
      'pengampu': 3,
      'nama_pengampu': 'Siti Rahmawati',
      'dibuat': today.toIso8601String(),
    },
    {
      'id': 3,
      'nama': 'XII TKJ 1',
      'deskripsi': 'Jaringan Komputer',
      'tingkat': 12,
      'tahun_ajaran': '2025/2026',
      'kode_kelas': 'TKJ12',
      'pengampu': 4,
      'nama_pengampu': 'Budi Santoso',
      'dibuat': today.toIso8601String(),
    },
  ];

  return HttpClient(
    token: _adminJwt(isAdmin: true),
    client: MockClient((request) async {
      final path = request.url.path;
      if (path == '/admin/pengguna' && request.method == 'GET') {
        if (failUsers) {
          return http.Response(
            jsonEncode({'message': 'Gagal memuat pengguna'}),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'guru': guruUsers,
            'murid': muridUsers,
          }),
          200,
        );
      }
      if (path.startsWith('/admin/pengguna/') &&
          path.endsWith('/role') &&
          request.method == 'PATCH') {
        final segments = request.url.pathSegments;
        final userId = int.parse(segments[2]);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final newRole = body['role'] as String;
        Map<String, dynamic>? target;
        final guruIdx = guruUsers.indexWhere((u) => u['id'] == userId);
        if (guruIdx != -1) {
          target = Map<String, dynamic>.from(guruUsers.removeAt(guruIdx));
        } else {
          final muridIdx = muridUsers.indexWhere((u) => u['id'] == userId);
          if (muridIdx != -1) {
            target = Map<String, dynamic>.from(muridUsers.removeAt(muridIdx));
          }
        }
        if (target == null) {
          return http.Response(
            jsonEncode({'message': 'Pengguna tidak ditemukan'}),
            404,
          );
        }
        target['role'] = newRole;
        if (newRole == 'guru') {
          guruUsers.add(target);
        } else {
          muridUsers.add(target);
        }
        return http.Response(
          jsonEncode({'message': 'Role pengguna berhasil diperbarui'}),
          200,
        );
      }
      if (path == '/admin/kelas' && request.method == 'GET') {
        return http.Response(jsonEncode(classesJson), 200);
      }
      if (path == '/admin/kelas' && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final id = classesJson.length + 1;
        classesJson.insert(0, {
          'id': id,
          'nama': body['nama'],
          'deskripsi': body['deskripsi'] ?? '',
          'tingkat': body['tingkat'],
          'tahun_ajaran': body['tahun_ajaran'],
          'kode_kelas': 'NEW0$id',
          'pengampu': null,
          'nama_pengampu': '',
          'dibuat': today.toIso8601String(),
        });
        return http.Response(jsonEncode({'message': 'Kelas berhasil dibuat'}), 201);
      }
      if (path == '/admin/kelas/csv' && request.method == 'POST') {
        final bodyText = utf8.decode(request.bodyBytes);
        final lines = bodyText
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        var count = 0;
        var inCsv = false;
        for (final line in lines) {
          if (line.startsWith('--')) {
            if (inCsv) break;
            continue;
          }
          if (line.startsWith('nama,')) {
            inCsv = true;
            continue;
          }
          if (!inCsv || !line.contains(',')) continue;
          final parts = line.split(',');
          final id = classesJson.length + 1;
          classesJson.insert(0, {
            'id': id,
            'nama': parts[0].trim(),
            'deskripsi': parts.length > 3 ? parts[3].trim() : '',
            'tingkat': int.tryParse(parts[1].trim()) ?? 10,
            'tahun_ajaran': parts[2].trim(),
            'kode_kelas': 'CSV0$id',
            'pengampu': null,
            'nama_pengampu': '',
            'dibuat': today.toIso8601String(),
          });
          count++;
        }
        return http.Response(
          jsonEncode({'message': '$count kelas berhasil dibuat dari CSV'}),
          201,
        );
      }
      if (path.startsWith('/admin/kelas/') &&
          path.endsWith('/pengampu') &&
          request.method == 'PATCH') {
        final kode = request.url.pathSegments[2];
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final pid = body['pengampu_id'] as int?;
        final idx = classesJson.indexWhere((c) => c['kode_kelas'] == kode);
        if (idx == -1) {
          return http.Response(
            jsonEncode({'message': 'Kelas tidak ditemukan'}),
            404,
          );
        }
        var namaPengampu = '';
        if (pid != null) {
          final guruMatch = guruUsers.where((g) => g['id'] == pid);
          if (guruMatch.isNotEmpty) {
            namaPengampu = guruMatch.first['nama'] as String;
          }
        }
        classesJson[idx] = {
          ...classesJson[idx],
          'pengampu': pid,
          'nama_pengampu': namaPengampu,
        };
        return http.Response(jsonEncode(classesJson[idx]), 200);
      }
      if (path == '/kelas/PPLG10/posts') {
        final tipe = request.url.queryParameters['tipe'];
        if (tipe == '2') {
          return http.Response(
            jsonEncode([
              {
                'id': 11,
                'judul': 'Pengenalan Algoritma',
                'deskripsi': 'Materi minggu pertama',
                'lampiran': <String>[],
                'pengguna_id': 2,
                'kelas_id': 1,
                'tipe_id': 2,
                'dibuat': today.toIso8601String(),
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 12,
              'judul': 'Latihan Flowchart',
              'deskripsi': 'Kerjakan soal 1-5',
              'lampiran': <String>[],
              'pengguna_id': 2,
              'kelas_id': 1,
              'tipe_id': 1,
              'dibuat': today.toIso8601String(),
            },
          ]),
          200,
        );
      }
      if (path == '/kelas/PPLG10/anggota') {
        return http.Response(
          jsonEncode([
            {
              'pengguna_id': 2,
              'nama': 'Eko Kusnandar',
              'email': 'eko@school.id',
              'profile_picture': '',
              'guru': true,
              'role': 'guru',
              'dibuat': today.toIso8601String(),
            },
          ]),
          200,
        );
      }
      if (path == '/kalender') {
        return http.Response(jsonEncode(kalenderEvents), 200);
      }
      if (path == '/admin/kalender/agenda' && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final created = {
          'id': kalenderEvents.length + 1,
          'nama_kegiatan': body['nama_kegiatan'],
          'keterangan': body['keterangan'] ?? '',
          'tanggal_mulai': body['tanggal_mulai'],
          'tanggal_selesai': body['tanggal_selesai'],
        };
        kalenderEvents.add(created);
        return http.Response(jsonEncode(created), 201);
      }
      if (path == '/kelas') {
        return http.Response(jsonEncode([]), 200);
      }
      if (path == '/pengguna') {
        return http.Response(
          jsonEncode({
            'id': 1,
            'nama': 'Admin Sekolah',
            'email': 'admin@example.com',
            'phone': '',
            'profile_picture': '',
            'admin': true,
            'role': 'admin',
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'message': 'Not found'}), 404);
    }),
  );
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      key: UniqueKey(),
      theme: AppTheme.lightTheme,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Admin shell, 4-tab navigation, and role isolation', () {
    testWidgets('admin navbar shows exactly 4 tabs on mobile & desktop, with header profile/logout', (
      tester,
    ) async {
      final today = DateTime.now();
      final client = _createAdminMockClient(today: today);
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpRouter(tester, router);

      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.items, hasLength(4));
      expect(
        bottomNav.items.map((item) => item.label).toList(),
        ['Beranda', 'Guru & Murid', 'Kelas', 'Kalender'],
      );
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.text('Rangkuman Statistik Sekolah'), findsOneWidget);
      expect(find.text('Ringkasan Penggunaan AI'), findsOneWidget);

      // Navigate via all 4 bottom nav tabs
      await tester.tap(find.text('Guru & Murid'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersScreen), findsOneWidget);
      expect(find.text('Daftar Guru'), findsOneWidget);
      expect(find.text('Daftar Murid'), findsOneWidget);

      await tester.tap(find.text('Kelas').last);
      await tester.pumpAndSettle();
      expect(find.byType(AdminKelasScreen), findsOneWidget);

      await tester.tap(find.text('Kalender').last);
      await tester.pumpAndSettle();
      expect(find.byType(KalenderScreen), findsOneWidget);
      expect(find.byKey(const Key('admin_add_agenda_button')), findsOneWidget);

      // Top-right header icon opens Profil with back button
      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilScreen), findsOneWidget);
      expect(find.text('admin@example.com'), findsOneWidget);

      // Desktop layout switches to 4-destination NavigationRail
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(4));
    });

    testWidgets('admin cannot enter /pengajar and non-admin cannot enter /admin/pengguna', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final today = DateTime.now();
      final adminClient = _createAdminMockClient(today: today);
      final adminRouter = createRouter(
        httpClient: adminClient,
        initialLocation: '/pengajar',
      );
      addTearDown(adminRouter.dispose);
      await _pumpRouter(tester, adminRouter);
      expect(
        adminRouter.routeInformationProvider.value.uri.path,
        '/beranda',
      );
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      final userClient = HttpClient(
        token: _adminJwt(isAdmin: false),
        client: MockClient((request) async {
          if (request.url.path == '/kelas') {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response('{}', 404);
        }),
      );
      final userRouter = createRouter(
        httpClient: userClient,
        initialLocation: '/admin/pengguna',
      );
      addTearDown(userRouter.dispose);
      await _pumpRouter(tester, userRouter);
      expect(
        userRouter.routeInformationProvider.value.uri.path,
        '/beranda',
      );
      final userBottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(userBottomNav.items, hasLength(4));
      expect(
        userBottomNav.items.map((item) => item.label).toList(),
        ['Beranda', 'Kelas', 'Kalender', 'Profil'],
      );
    });

    testWidgets('admin header logout prompts confirmation and clears auth state', (
      tester,
    ) async {
      final client = _createAdminMockClient(today: DateTime.now());
      final router = createRouter(httpClient: client);
      addTearDown(router.dispose);

      await _pumpRouter(tester, router);
      await tester.tap(find.byTooltip('Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ya'));
      await tester.pumpAndSettle();

      expect(client.isAuthenticated, isFalse);
      expect(client.isAdmin, isFalse);
      expect(router.routeInformationProvider.value.uri.path, '/login');
    });
  });

  group('Admin screens & calendar interactions', () {
    testWidgets('AdminDashboardScreen renders stat cards and interactive AI role filters without overflow on 320px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = _createAdminMockClient(today: DateTime.now());
      final adminCtrl = AdminController(AdminRepository(client));
      final kalenderRepo = KalenderRepository(client);
      addTearDown(adminCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AdminDashboardScreen(
            controller: adminCtrl,
            kalenderRepository: kalenderRepo,
            random: math.Random(42),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Guru'), findsOneWidget);
      expect(find.text('1 Guru'), findsOneWidget);
      expect(find.text('Total Siswa'), findsOneWidget);
      expect(find.text('1 Siswa'), findsOneWidget);
      expect(find.text('Total Pakai AI (Semua)'), findsOneWidget);
      expect(find.text('Total Event'), findsOneWidget);
      expect(find.text('1 Event'), findsOneWidget);

      // Verify both real users appear with randomized AI usage and real class details
      expect(find.text('Eko Kusnandar (Guru)'), findsOneWidget);
      expect(find.text('Mengampu: X PPLG 1, X PPLG 2'), findsOneWidget);
      expect(find.text('Aji Sasongko (Siswa)'), findsOneWidget);
      expect(find.text('Kelas: X PPLG 1'), findsOneWidget);

      final guruChip = find.byKey(const Key('admin_ai_filter_guru'));
      final siswaChip = find.byKey(const Key('admin_ai_filter_siswa'));

      await tester.ensureVisible(guruChip);
      await tester.pumpAndSettle();
      await tester.tap(guruChip);
      await tester.pumpAndSettle();
      expect(find.text('Eko Kusnandar (Guru)'), findsOneWidget);
      expect(find.text('Aji Sasongko (Siswa)'), findsNothing);

      await tester.ensureVisible(siswaChip);
      await tester.pumpAndSettle();
      await tester.tap(siswaChip);
      await tester.pumpAndSettle();
      expect(find.text('Aji Sasongko (Siswa)'), findsOneWidget);
      expect(find.text('Eko Kusnandar (Guru)'), findsNothing);
    });

    testWidgets('AdminUsersScreen displays separate Daftar Guru and Daftar Murid sections and supports search', (
      tester,
    ) async {
      final client = _createAdminMockClient(today: DateTime.now());
      final router = createRouter(
        httpClient: client,
        initialLocation: '/admin/pengguna',
      );
      addTearDown(router.dispose);

      await _pumpRouter(tester, router);

      expect(find.text('Daftar Guru'), findsOneWidget);
      expect(find.text('Eko Kusnandar'), findsOneWidget);
      expect(find.text('Mengampu: X PPLG 1, X PPLG 2'), findsOneWidget);
      expect(find.text('Daftar Murid'), findsOneWidget);
      expect(find.text('Aji Sasongko'), findsOneWidget);
      expect(find.text('Kelas: X PPLG 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Aji');
      await tester.pumpAndSettle();
      expect(find.text('Aji Sasongko'), findsOneWidget);
      expect(find.text('Eko Kusnandar'), findsNothing);
    });

    testWidgets('AdminKelasScreen filters by tahun ajaran, tingkat, and nama kelas, and opens detail', (
      tester,
    ) async {
      final client = _createAdminMockClient(today: DateTime.now());
      final router = createRouter(
        httpClient: client,
        initialLocation: '/kelas',
      );
      addTearDown(router.dispose);

      await _pumpRouter(tester, router);

      expect(find.text('Menampilkan 3 dari 3 kelas'), findsOneWidget);
      expect(find.text('X PPLG 1'), findsOneWidget);
      expect(find.text('XI RPL 1'), findsOneWidget);
      expect(find.text('XII TKJ 1'), findsOneWidget);

      // Filter by tahun ajaran
      await tester.tap(find.byKey(const Key('admin_filter_tahun_ajaran')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026/2027').last);
      await tester.pumpAndSettle();
      expect(find.text('Menampilkan 2 dari 3 kelas'), findsOneWidget);
      expect(find.text('XII TKJ 1'), findsNothing);

      // Filter by tingkat
      await tester.tap(find.byKey(const Key('admin_filter_tingkat')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kelas X (10)').last);
      await tester.pumpAndSettle();
      expect(find.text('Menampilkan 1 dari 3 kelas'), findsOneWidget);
      expect(find.text('X PPLG 1'), findsOneWidget);

      // Filter by nama kelas
      await tester.tap(find.text('Reset Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Menampilkan 3 dari 3 kelas'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('admin_filter_nama_kelas')),
        'rpl',
      );
      await tester.pumpAndSettle();
      expect(find.text('XI RPL 1'), findsOneWidget);
      expect(find.text('X PPLG 1'), findsNothing);

      // Clear and open X PPLG 1 read-only detail
      await tester.tap(find.text('Reset Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('X PPLG 1'));
      await tester.pumpAndSettle();
      expect(find.text('Pengenalan Algoritma'), findsOneWidget);
      expect(find.text('Latihan Flowchart'), findsOneWidget);
    });

    testWidgets('Admin can add agenda with nama event & keterangan, visible to regular user too', (
      tester,
    ) async {
      final today = DateTime.now();
      final adminClient = _createAdminMockClient(today: today);
      final adminRouter = createRouter(
        httpClient: adminClient,
        initialLocation: '/kalender',
      );
      addTearDown(adminRouter.dispose);

      await _pumpRouter(tester, adminRouter);
      expect(find.text('Upacara Bendera'), findsOneWidget);
      expect(find.text('Wajib pakai seragam lengkap'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_add_agenda_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('agenda_nama_field')),
        'Pentas Seni Sekolah',
      );
      await tester.enterText(
        find.byKey(const Key('agenda_keterangan_field')),
        'Seluruh kelas wajib hadir di aula pukul 08.00',
      );
      await tester.tap(find.byKey(const Key('agenda_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Agenda berhasil ditambahkan'), findsOneWidget);
      expect(find.text('Pentas Seni Sekolah'), findsOneWidget);
      expect(
        find.text('Seluruh kelas wajib hadir di aula pukul 08.00'),
        findsOneWidget,
      );

      // Verify regular user sees shared keterangan and does not see Tambah Agenda
      final userCtrl = KalenderController(KalenderRepository(adminClient));
      addTearDown(userCtrl.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: KalenderScreen(controller: userCtrl)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin_add_agenda_button')), findsNothing);
      expect(find.text('Pentas Seni Sekolah'), findsOneWidget);
      expect(
        find.text('Seluruh kelas wajib hadir di aula pukul 08.00'),
        findsOneWidget,
      );
    });
  });

  group('Admin class creation (manual & CSV), pengampu assignment, and role management', () {
    testWidgets('non-admin DashboardScreen and PengajarScreen hide class creation controls', (
      tester,
    ) async {
      final client = HttpClient(
        token: _adminJwt(role: 'guru'),
        client: MockClient((request) async {
          if (request.url.path == '/kelas') {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response('{}', 404);
        }),
      );
      final kelasCtrl = KelasController(KelasRepository(client));
      final pengajarCtrl = PengajarController(PengajarRepository(client));
      addTearDown(kelasCtrl.dispose);
      addTearDown(pengajarCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DashboardScreen(
              kelasController: kelasCtrl,
              pengajarController: pengajarCtrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('atau Tambah Kelas'), findsNothing);
      expect(find.text('Tambah Kelas'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: PengajarScreen(controller: pengajarCtrl)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buat Kelas'), findsNothing);
      expect(
        find.text('Hanya admin yang dapat membuat atau menetapkan pengampu kelas'),
        findsOneWidget,
      );
    });

    testWidgets('AdminUsersScreen switches user role between Murid and Guru', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = _createAdminMockClient(today: DateTime.now());
      final ctrl = AdminController(AdminRepository(client));
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: AdminUsersScreen(controller: ctrl)),
        ),
      );
      await tester.pumpAndSettle();

      expect(ctrl.guruList, hasLength(1));
      expect(ctrl.muridList, hasLength(1));

      // Promote Aji Sasongko (id 5) from Murid to Guru
      await tester.ensureVisible(find.byKey(const Key('user_role_menu_5')));
      await tester.tap(find.byKey(const Key('user_role_menu_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jadikan Guru'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ya'));
      await tester.pumpAndSettle();

      expect(find.text('Aji Sasongko kini menjadi Guru'), findsOneWidget);
      expect(find.text('Belum ada murid terdaftar'), findsOneWidget);
      expect(ctrl.guruList, hasLength(2));
      expect(ctrl.muridList, isEmpty);

      // Demote Aji Sasongko back to Murid
      await tester.tap(find.byKey(const Key('user_role_menu_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jadikan Murid'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ya'));
      await tester.pumpAndSettle();

      expect(find.text('Aji Sasongko kini menjadi Murid'), findsOneWidget);
      expect(find.text('Belum ada murid terdaftar'), findsNothing);
      expect(ctrl.guruList, hasLength(1));
      expect(ctrl.muridList, hasLength(1));
    });

    testWidgets('AdminKelasScreen creates class manually, uploads CSV, and changes pengampu without overflow on 320px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = _createAdminMockClient(today: DateTime.now());
      final ctrl = AdminController(AdminRepository(client));
      addTearDown(ctrl.dispose);
      final kelasRepo = KelasRepository(client);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AdminKelasScreen(
              controller: ctrl,
              kelasRepository: kelasRepo,
              onPickCsvFile: () async => http.MultipartFile.fromString(
                'file_csv',
                'nama,tingkat,tahun_ajaran,deskripsi\n'
                    'X AKL 1,10,2026/2027,Akuntansi Dasar\n'
                    'XI AKL 1,11,2026/2027,Akuntansi Keuangan\n',
                filename: 'kelas.csv',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Create single class manually (pengampu defaults to Belum ditentukan)
      await tester.tap(find.byKey(const Key('admin_add_kelas_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('admin_create_kelas_nama')),
        'X DKV 1',
      );
      await tester.tap(find.byKey(const Key('admin_create_kelas_tingkat')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kelas X (10)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('admin_create_kelas_tahun')),
        '2026/2027',
      );
      await tester.enterText(
        find.byKey(const Key('admin_create_kelas_deskripsi')),
        'Desain Komunikasi Visual',
      );
      await tester.ensureVisible(
        find.byKey(const Key('admin_create_kelas_submit')),
      );
      await tester.tap(find.byKey(const Key('admin_create_kelas_submit')));
      await tester.pumpAndSettle();

      expect(find.text('X DKV 1'), findsOneWidget);
      expect(find.text('Pengampu: Belum ditentukan'), findsOneWidget);

      // 2. Bulk create classes via CSV
      await tester.tap(find.byKey(const Key('admin_upload_csv_kelas_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_csv_pick_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.text('2 kelas berhasil dibuat dari CSV'), findsOneWidget);
      expect(find.text('X AKL 1'), findsOneWidget);
      expect(find.text('XI AKL 1'), findsOneWidget);

      // 3. Assign pengampu from Daftar Guru via ClassCard menu on X DKV 1
      await tester.scrollUntilVisible(
        find.text('X DKV 1'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final dkvCard = find.ancestor(
        of: find.text('X DKV 1'),
        matching: find.byType(ClassCard),
      );
      final dkvMore = find.descendant(
        of: dkvCard,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.ensureVisible(dkvMore);
      await tester.tap(dkvMore);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ubah pengampu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eko Kusnandar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_save_pengampu_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pengampu kelas berhasil diperbarui'), findsOneWidget);
      expect(
        find.descendant(
          of: dkvCard,
          matching: find.text('Pengampu: Eko Kusnandar'),
        ),
        findsOneWidget,
      );

      // 4. Open detail screen & clear pengampu back to Belum ditentukan
      await tester.tap(find.text('X DKV 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_detail_ubah_pengampu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kosongkan Pengampu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_save_pengampu_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pengampu: Belum ditentukan'), findsWidgets);
    });
  });
}
