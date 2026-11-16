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
  group('Role separation on DashboardScreen & PengajarScreen', () {
    testWidgets(
      'non-guru classes do not appear in Pengajar tab even if API ignores query filter',
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
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kelas Siswa Biologi'), findsOneWidget);
        expect(find.text('Kelas Pengajar Matematika'), findsNothing);

        await tester.tap(find.text('Pengajar'));
        await tester.pumpAndSettle();

        expect(find.text('Kelas Pengajar Matematika'), findsOneWidget);
        expect(find.text('Kelas Siswa Biologi'), findsNothing);
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
}
