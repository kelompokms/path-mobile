import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/routes/router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/dashboard/dashboard_screen.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/list_pengumpulan_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

HttpClient _createMixedRoleClient({bool ignoreQueryFilter = false}) {
  final isoNow = DateTime(2026, 11, 16, 9, 0).toIso8601String();

  final allClasses = [
    {
      'id': 1,
      'nama': 'Kelas Siswa Biologi',
      'tingkat': 10,
      'tahun_ajaran': '2026/2027',
      'kode_kelas': 'BIO101',
      'pengampu': 99,
      'guru': false,
      'dibuat': isoNow,
    },
    {
      'id': 2,
      'nama': 'Kelas Pengajar Matematika',
      'tingkat': 11,
      'tahun_ajaran': '2026/2027',
      'kode_kelas': 'MAT202',
      'pengampu': 1,
      'guru': true,
      'dibuat': isoNow,
    },
  ];

  final materiJson = [
    {
      'id': 10,
      'judul': 'Materi Pertama',
      'deskripsi': 'Deskripsi materi',
      'lampiran': <String>[],
      'pengguna_id': 99,
      'kelas_id': 1,
      'tipe_id': 2,
      'dibuat': isoNow,
    },
  ];

  final tugasJson = [
    {
      'id': 20,
      'judul': 'Tugas Pertama',
      'deskripsi': 'Deskripsi tugas',
      'lampiran': <String>[],
      'pengguna_id': 99,
      'kelas_id': 1,
      'tipe_id': 1,
      'dibuat': isoNow,
    },
  ];

  final anggotaJson = [
    {
      'pengguna_id': 99,
      'nama': 'Ibu Sari Guru',
      'email': 'sari.guru@example.com',
      'profile_picture': '',
      'guru': true,
      'role': 'guru',
      'dibuat': isoNow,
    },
    {
      'pengguna_id': 1,
      'nama': 'Andi Murid',
      'email': 'andi.murid@example.com',
      'profile_picture': '',
      'guru': false,
      'role': 'murid',
      'dibuat': isoNow,
    },
    {
      'pengguna_id': 2,
      'nama': 'Citra Murid',
      'email': 'citra.murid@example.com',
      'profile_picture': '',
      'guru': false,
      'role': 'murid',
      'dibuat': isoNow,
    },
  ];

  return HttpClient(
    token: 'valid.jwt.token',
    client: MockClient((request) async {
      final path = request.url.path;
      if (path == '/kelas') {
        if (!ignoreQueryFilter) {
          final guruParam = request.url.queryParameters['guru'];
          if (guruParam == 'true') {
            return http.Response(
              jsonEncode(allClasses.where((c) => c['guru'] == true).toList()),
              200,
            );
          }
          if (guruParam == 'false') {
            return http.Response(
              jsonEncode(allClasses.where((c) => c['guru'] == false).toList()),
              200,
            );
          }
        }
        return http.Response(jsonEncode(allClasses), 200);
      }
      if (path == '/kelas/BIO101' || path == '/kelas/MAT202') {
        final code = path.split('/').last;
        final match = allClasses.firstWhere((c) => c['kode_kelas'] == code);
        return http.Response(jsonEncode(match), 200);
      }
      if (path.endsWith('/posts')) {
        final tipe = request.url.queryParameters['tipe'];
        return http.Response(
          jsonEncode(tipe == '2' ? materiJson : tugasJson),
          200,
        );
      }
      if (path.endsWith('/anggota')) {
        return http.Response(jsonEncode(anggotaJson), 200);
      }
      return http.Response(jsonEncode({'message': 'Not found'}), 404);
    }),
  );
}

void main() {
  group('Role separation on DashboardScreen, KelasScreen & PengajarScreen', () {
    testWidgets(
      'separates enrolled and teaching/assistant classes cleanly even if API ignores query filter',
      (tester) async {
        final client = _createMixedRoleClient(ignoreQueryFilter: true);
        final kCtrl = KelasController(KelasRepository(client));
        final pCtrl = PengajarController(PengajarRepository(client));
        addTearDown(kCtrl.dispose);
        addTearDown(pCtrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: DashboardScreen(
                kelasController: kCtrl,
                pengajarController: pCtrl,
                isGuruRole: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Beranda Murid'), findsOneWidget);
        expect(find.text('Murid • Asisten'), findsOneWidget);
        expect(find.text('Kelas Diikuti'), findsWidgets);
        expect(find.text('Kelas Didampingi (Asisten)'), findsOneWidget);
        expect(find.text('Kelas Siswa Biologi'), findsOneWidget);
        expect(find.text('Kelas Pengajar Matematika'), findsOneWidget);

        // On KelasScreen as Guru, Mengajar tab only contains guru:true classes,
        // and Diikuti tab only contains guru:false classes.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: KelasScreen(
                controller: kCtrl,
                pengajarController: pCtrl,
                isGuruRole: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kelas Pengajar Matematika'), findsOneWidget);
        expect(find.text('Kelas Siswa Biologi'), findsNothing);

        await tester.tap(find.byKey(const Key('kelas_tab_diikuti')));
        await tester.pumpAndSettle();

        expect(find.text('Kelas Siswa Biologi'), findsOneWidget);
        expect(find.text('Kelas Pengajar Matematika'), findsNothing);
      },
    );

    testWidgets('PengajarScreen only shows classes where user is guru', (
      tester,
    ) async {
      final client = _createMixedRoleClient(ignoreQueryFilter: true);
      final pCtrl = PengajarController(PengajarRepository(client));
      addTearDown(pCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: PengajarScreen(controller: pCtrl)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kelas Pengajar Matematika'), findsOneWidget);
      expect(find.text('Kelas Siswa Biologi'), findsNothing);
    });

    testWidgets(
      'PengajarDetailScreen hides teacher options when classData.isGuru is false',
      (tester) async {
        final client = _createMixedRoleClient();
        final pCtrl = PengajarController(PengajarRepository(client));
        addTearDown(pCtrl.dispose);

        const nonGuruClass = ClassItem(
          title: 'Kelas Siswa Biologi',
          grade: 'Kelas X',
          code: 'BIO101',
          isGuru: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: PengajarDetailScreen(
                classData: nonGuruClass,
                controller: pCtrl,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Buat Materi'), findsNothing);
        expect(find.text('Kode kelas'), findsNothing);
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(find.text('Materi Pertama'), findsOneWidget);

        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Tugas'), findsNothing);
        expect(find.byIcon(Icons.more_vert), findsNothing);

        await tester.tap(find.text('Tugas Pertama'));
        await tester.pumpAndSettle();
        expect(find.text('Cek jawaban'), findsNothing);
      },
    );

    testWidgets(
      'PengajarDetailScreen shows teacher options when classData.isGuru is true',
      (tester) async {
        final client = _createMixedRoleClient();
        final pCtrl = PengajarController(PengajarRepository(client));
        addTearDown(pCtrl.dispose);

        const guruClass = ClassItem(
          title: 'Kelas Pengajar Matematika',
          grade: 'Kelas XI',
          code: 'MAT202',
          isGuru: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: PengajarDetailScreen(
                classData: guruClass,
                controller: pCtrl,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Buat Materi'), findsOneWidget);
        expect(find.text('Kode kelas'), findsOneWidget);

        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();
        expect(find.text('Tambah Tugas'), findsOneWidget);
      },
    );
  });

  group('Daftar Anggota pada route kelas & tab Anggota', () {
    testWidgets(
      'displays both guru and murid on /kelas/:kode_kelas/anggota route',
      (tester) async {
        final client = _createMixedRoleClient();
        final router = createRouter(
          httpClient: client,
          initialLocation: '/kelas/BIO101/anggota',
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kelas Siswa Biologi'), findsWidgets);
        expect(find.text('1 Orang'), findsOneWidget);
        expect(find.text('2 Orang'), findsOneWidget);
        expect(find.text('Ibu Sari Guru'), findsOneWidget);
        expect(find.text('Andi Murid'), findsOneWidget);
        expect(find.text('Citra Murid'), findsOneWidget);
      },
    );

    testWidgets(
      'ClassDetailScreen Anggota tab displays both guru and murid',
      (tester) async {
        final client = _createMixedRoleClient();
        final kCtrl = KelasController(KelasRepository(client));
        addTearDown(kCtrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: KelasScreen(controller: kCtrl)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kelas Siswa Biologi'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Anggota'));
        await tester.pumpAndSettle();

        expect(find.text('Ibu Sari Guru'), findsOneWidget);
        expect(find.text('Andi Murid'), findsOneWidget);
        expect(find.text('Citra Murid'), findsOneWidget);
      },
    );
  });

  group('Role-based UI differentiation (Guru vs Murid & Assistant)', () {
    String roleJwt(String role) {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'})));
      final body = base64Url.encode(
        utf8.encode(jsonEncode({'user_id': 1, 'role': role, 'admin': false})),
      );
      return '$header.$body.sig';
    }

    HttpClient createRoleDashboardClient({
      required String role,
      bool includeAssistantClass = false,
    }) {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final classes = [
        if (role != 'guru')
          {
            'id': 1,
            'nama': 'Biologi X',
            'tingkat': 10,
            'tahun_ajaran': '2026/2027',
            'kode_kelas': 'BIO10',
            'pengampu': 2,
            'guru': false,
            'dibuat': now.toIso8601String(),
          },
        if (role == 'guru' || includeAssistantClass)
          {
            'id': 2,
            'nama': 'Fisika XI',
            'tingkat': 11,
            'tahun_ajaran': '2026/2027',
            'kode_kelas': 'FIS11',
            'pengampu': 1,
            'guru': true,
            'dibuat': now.toIso8601String(),
          },
      ];

      return HttpClient(
        token: roleJwt(role),
        client: MockClient((request) async {
          final path = request.url.path;
          final tipe = request.url.queryParameters['tipe'];
          if (path == '/kelas') {
            return http.Response(jsonEncode(classes), 200);
          }
          if (path == '/kalender') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama_kegiatan': 'Upacara Bendera',
                  'keterangan': 'Lapangan sekolah',
                  'tanggal_mulai': tomorrow.toIso8601String(),
                  'tanggal_selesai': tomorrow.toIso8601String(),
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/BIO10/posts') {
            if (tipe == '2') return http.Response(jsonEncode([]), 200);
            return http.Response(
              jsonEncode([
                {
                  'id': 101,
                  'judul': 'Quiz Sel',
                  'deskripsi': 'Kerjakan kuis',
                  'lampiran': <String>[],
                  'pengguna_id': 2,
                  'kelas_id': 1,
                  'tipe_id': 1,
                  'dibuat': now.toIso8601String(),
                },
                {
                  'id': 102,
                  'judul': 'PR Biologi',
                  'deskripsi': 'Buat ringkasan',
                  'lampiran': <String>[],
                  'pengguna_id': 2,
                  'kelas_id': 1,
                  'tipe_id': 1,
                  'dibuat': now.subtract(const Duration(hours: 2)).toIso8601String(),
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/BIO10/postingan/101/pengumpulan/saya') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'pengguna_id': 1,
                'postingan_id': 101,
                'lampiran': ['files/kumpul.pdf'],
                'submitted': true,
                'dibuat': now.toIso8601String(),
              }),
              200,
            );
          }
          if (path == '/kelas/BIO10/postingan/102/pengumpulan/saya') {
            return http.Response(jsonEncode({'message': 'Belum mengumpulkan'}), 404);
          }
          if (path == '/kelas/FIS11/posts') {
            if (tipe == '2') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 201,
                    'judul': 'Materi Dinamika',
                    'deskripsi': 'Hukum Newton',
                    'lampiran': <String>[],
                    'pengguna_id': 1,
                    'kelas_id': 2,
                    'tipe_id': 2,
                    'dibuat': now.toIso8601String(),
                  },
                ]),
                200,
              );
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 202,
                  'judul': 'Tugas Gerak Lurus',
                  'deskripsi': 'Soal latihan',
                  'lampiran': <String>[],
                  'pengguna_id': 1,
                  'kelas_id': 2,
                  'tipe_id': 1,
                  'dibuat': now.toIso8601String(),
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/FIS11/postingan/202/pengumpulan') {
            return http.Response(
              jsonEncode([
                {
                  'id': 10,
                  'pengguna_id': 5,
                  'nama': 'Aji Siswa',
                  'email': 'aji@school.id',
                  'profile_picture': '',
                  'lampiran': ['files/jawaban_aji.pdf'],
                  'dibuat': now.toIso8601String(),
                },
                {
                  'id': 11,
                  'pengguna_id': 6,
                  'nama': 'Bima Siswa',
                  'email': 'bima@school.id',
                  'profile_picture': '',
                  'lampiran': ['files/jawaban_bima.pdf'],
                  'dibuat': now.subtract(const Duration(hours: 1)).toIso8601String(),
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/BIO10/anggota' || path == '/kelas/FIS11/anggota') {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response('{}', 404);
        }),
      );
    }

    testWidgets(
      'pure Murid gets 4 tabs without Pengajar, sees Beranda Murid pending tasks & clean Kelas tab',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final client = createRoleDashboardClient(role: 'murid');
        final router = createRouter(httpClient: client, initialLocation: '/beranda');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            key: UniqueKey(),
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        final bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(
          bottomNav.items.map((e) => e.label).toList(),
          ['Beranda', 'Kelas', 'Kalender', 'Profil'],
        );

        // Beranda Murid highlights unsubmitted tasks & upcoming agenda
        expect(find.text('Beranda Murid'), findsOneWidget);
        expect(find.text('PR Biologi'), findsOneWidget);
        expect(find.text('Belum Dikumpul'), findsWidgets);
        expect(find.text('Quiz Sel'), findsOneWidget);
        expect(find.text('Dikumpulkan'), findsOneWidget);
        expect(find.text('Upacara Bendera'), findsOneWidget);
        expect(find.text('Kelas Didampingi (Asisten)'), findsNothing);

        // Navigate to Kelas tab -> pure murid has no Mengajar/Mendampingi switcher
        await tester.tap(find.text('Kelas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('kelas_tab_mengajar')), findsNothing);
        expect(find.byKey(const Key('kelas_tab_mendampingi')), findsNothing);
        expect(find.text('Biologi X'), findsOneWidget);
        expect(find.text('Gabung Kelas'), findsOneWidget);
      },
    );

    testWidgets(
      'Murid promoted as class assistant adaptively unlocks Mendampingi tab on KelasScreen',
      (tester) async {
        final client = createRoleDashboardClient(
          role: 'murid',
          includeAssistantClass: true,
        );
        final kCtrl = KelasController(KelasRepository(client));
        final pCtrl = PengajarController(PengajarRepository(client));
        addTearDown(kCtrl.dispose);
        addTearDown(pCtrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: KelasScreen(
                controller: kCtrl,
                pengajarController: pCtrl,
                isGuruRole: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('kelas_tab_diikuti')), findsOneWidget);
        expect(find.byKey(const Key('kelas_tab_mendampingi')), findsOneWidget);
        expect(find.text('Biologi X'), findsOneWidget);

        await tester.tap(find.byKey(const Key('kelas_tab_mendampingi')));
        await tester.pumpAndSettle();

        expect(find.text('Fisika XI'), findsOneWidget);
        await tester.tap(find.text('Fisika XI'));
        await tester.pumpAndSettle();
        expect(find.byType(PengajarDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Guru gets 4 tabs, sees Beranda Guru submission summary & defaults Kelas tab to Mengajar',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final client = createRoleDashboardClient(role: 'guru');
        final router = createRouter(httpClient: client, initialLocation: '/beranda');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            key: UniqueKey(),
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        final bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(
          bottomNav.items.map((e) => e.label).toList(),
          ['Beranda', 'Kelas', 'Kalender', 'Profil'],
        );

        // Beranda Guru shows teaching stats & submission monitoring
        expect(find.text('Beranda Guru'), findsOneWidget);
        expect(find.text('Monitoring Pengumpulan Tugas'), findsOneWidget);
        expect(find.text('Tugas Gerak Lurus'), findsOneWidget);
        expect(find.text('2 kumpul'), findsOneWidget);
        expect(find.textContaining('Terbaru: Aji Siswa'), findsOneWidget);

        // Tapping submission card opens ListPengumpulanScreen directly
        await tester.tap(find.byKey(const Key('guru_submission_FIS11_202')));
        await tester.pumpAndSettle();
        expect(find.byType(ListPengumpulanScreen), findsOneWidget);
        expect(find.text('Aji Siswa'), findsOneWidget);

        // Back and open Kelas tab -> Guru defaults directly to Mengajar tab
        await tester.tap(find.text('Kelas'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('kelas_tab_mengajar')), findsOneWidget);
        expect(find.byKey(const Key('kelas_tab_diikuti')), findsOneWidget);
        expect(find.text('Fisika XI'), findsOneWidget);

        await tester.tap(find.byKey(const Key('kelas_tab_diikuti')));
        await tester.pumpAndSettle();
        expect(find.text('Anda belum bergabung kelas manapun'), findsOneWidget);
      },
    );
  });
}
