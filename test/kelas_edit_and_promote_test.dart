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
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Edit nama & deskripsi kelas', () {
    testWidgets(
      'hides Buat Kelas for non-admin and edits name & description via PengajarScreen menu and PengajarDetailScreen',
      (tester) async {
        final isoNow = DateTime(2026, 11, 16, 10, 0).toIso8601String();
        final classes = [
          {
            'id': 1,
            'nama': 'Matematika XI',
            'deskripsi': 'Deskripsi awal matematika',
            'tingkat': 11,
            'tahun_ajaran': '2026/2027',
            'kode_kelas': 'MAT202',
            'pengampu': 1,
            'guru': true,
            'dibuat': isoNow,
          },
        ];
        final updatedPayloads = <Map<String, dynamic>>[];

        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            final path = request.url.path;
            if (path == '/kelas' && request.method == 'GET') {
              return http.Response(jsonEncode(classes), 200);
            }
            if (path == '/kelas/MAT202' && request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              updatedPayloads.add(body);
              final idx = classes.indexWhere((c) => c['kode_kelas'] == 'MAT202');
              classes[idx] = {
                ...classes[idx],
                'nama': body['nama'],
                'deskripsi': body['deskripsi'],
              };
              return http.Response(jsonEncode(classes[idx]), 200);
            }
            if (path == '/kelas/MAT202/posts') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/kelas/MAT202/anggota') {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        );

        final ctrl = PengajarController(PengajarRepository(client));
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: PengajarScreen(controller: ctrl)),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Non-admin teachers cannot create classes directly
        expect(find.text('Buat Kelas'), findsNothing);
        expect(find.text('Matematika XI'), findsOneWidget);

        // 2. Edit via ClassCard popup menu on MAT202
        final matCard = find.ancestor(
          of: find.text('Matematika XI'),
          matching: find.byType(ClassCard),
        );
        await tester.tap(
          find.descendant(of: matCard, matching: find.byIcon(Icons.more_vert)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit kelas'));
        await tester.pumpAndSettle();

        // Clearing name disables Simpan
        await tester.enterText(
          find.widgetWithText(TextField, 'Matematika XI'),
          '   ',
        );
        await tester.pumpAndSettle();
        expect(find.text('Nama kelas wajib diisi'), findsOneWidget);
        final disabledSimpan = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Simpan'),
        );
        expect(disabledSimpan.onPressed, isNull);

        await tester.enterText(
          find.widgetWithText(TextField, '   '),
          'Matematika Peminatan',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Deskripsi awal matematika'),
          'Kalkulus dan vektor',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(updatedPayloads, hasLength(1));
        expect(updatedPayloads.first, {
          'nama': 'Matematika Peminatan',
          'deskripsi': 'Kalkulus dan vektor',
        });
        expect(find.text('Matematika Peminatan'), findsOneWidget);

        // 3. Open PengajarDetailScreen -> verify description & edit from detail icon
        await tester.tap(find.text('Matematika Peminatan'));
        await tester.pumpAndSettle();

        expect(find.text('Kalkulus dan vektor'), findsOneWidget);
        await tester.tap(find.byTooltip('Edit kelas'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Matematika Peminatan'),
          'Matematika Olimpiade',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Kalkulus dan vektor'),
          'Persiapan OSN Matematika',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(updatedPayloads, hasLength(2));
        expect(find.text('Matematika Olimpiade'), findsOneWidget);
        expect(find.text('Persiapan OSN Matematika'), findsOneWidget);
      },
    );

    testWidgets(
      'displays class description to students on ClassDetailScreen without edit actions',
      (tester) async {
        final isoNow = DateTime(2026, 11, 16, 10, 0).toIso8601String();
        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            final path = request.url.path;
            if (path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'Biologi Sel',
                    'deskripsi': 'Pembahasan struktur dan fungsi organel sel',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'BIO101',
                    'pengampu': 99,
                    'guru': false,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas/BIO101/posts') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/kelas/BIO101/anggota') {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        );

        final ctrl = KelasController(KelasRepository(client));
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: KelasScreen(controller: ctrl)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ClassCard).first);
        await tester.pumpAndSettle();

        expect(find.text('Biologi Sel'), findsWidgets);
        expect(
          find.text('Pembahasan struktur dan fungsi organel sel'),
          findsOneWidget,
        );
        expect(find.byTooltip('Edit kelas'), findsNothing);
      },
    );
  });

  group('Angkat murid menjadi guru', () {
    HttpClient createMemberRoleClient({
      required bool callerIsGuru,
      bool failPromote = false,
      List<String>? promoteCalls,
    }) {
      final isoNow = DateTime(2026, 11, 16, 10, 0).toIso8601String();
      final members = [
        {
          'pengguna_id': 99,
          'nama': 'Ibu Sari Guru',
          'email': 'sari@example.com',
          'profile_picture': '',
          'guru': true,
          'role': 'guru',
          'dibuat': isoNow,
        },
        {
          'pengguna_id': 2,
          'nama': 'Andi Murid',
          'email': 'andi@example.com',
          'profile_picture': '',
          'guru': false,
          'role': 'murid',
          'dibuat': isoNow,
        },
      ];

      return HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/kelas') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama': 'Matematika XI',
                  'deskripsi': 'Kelas matematika',
                  'tingkat': 11,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'MAT202',
                  'pengampu': 99,
                  'guru': callerIsGuru,
                  'dibuat': isoNow,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/MAT202') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'nama': 'Matematika XI',
                'deskripsi': 'Kelas matematika',
                'tingkat': 11,
                'tahun_ajaran': '2026/2027',
                'kode_kelas': 'MAT202',
                'pengampu': 99,
                'guru': callerIsGuru,
                'dibuat': isoNow,
              }),
              200,
            );
          }
          if (path == '/kelas/MAT202/posts') {
            return http.Response(jsonEncode([]), 200);
          }
          if (path == '/kelas/MAT202/anggota') {
            return http.Response(jsonEncode(members), 200);
          }
          if (path == '/kelas/MAT202/anggota/2/guru' &&
              request.method == 'PATCH') {
            promoteCalls?.add(path);
            if (failPromote) {
              return http.Response(
                jsonEncode({
                  'message': 'Hanya guru yang dapat mengangkat murid menjadi guru',
                }),
                403,
              );
            }
            members[1] = {
              ...members[1],
              'guru': true,
              'role': 'guru',
            };
            return http.Response(
              jsonEncode({'message': 'Berhasil mengangkat murid menjadi guru'}),
              200,
            );
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
    }

    testWidgets(
      'teacher promotes student to guru on PengajarDetailScreen Anggota tab after confirmation',
      (tester) async {
        final promoteCalls = <String>[];
        final ctrl = PengajarController(
          PengajarRepository(
            createMemberRoleClient(
              callerIsGuru: true,
              promoteCalls: promoteCalls,
            ),
          ),
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: PengajarScreen(controller: ctrl)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ClassCard).first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Anggota'));
        await tester.pumpAndSettle();

        expect(find.text('1 Orang'), findsNWidgets(2));

        // Canceling confirmation does not call API
        await tester.tap(find.byTooltip('Opsi anggota'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Angkat menjadi guru'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tidak'));
        await tester.pumpAndSettle();
        expect(promoteCalls, isEmpty);

        // Confirming calls PATCH /kelas/MAT202/anggota/2/guru and reloads members
        await tester.tap(find.byTooltip('Opsi anggota'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Angkat menjadi guru'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya'));
        await tester.pumpAndSettle();

        expect(promoteCalls, ['/kelas/MAT202/anggota/2/guru']);
        expect(find.text('2 Orang'), findsOneWidget);
        expect(find.text('0 Orang'), findsOneWidget);
        expect(find.text('Belum ada murid'), findsOneWidget);
        expect(find.byTooltip('Opsi anggota'), findsNothing);
      },
    );

    testWidgets(
      'supports promote on /kelas/:kode_kelas/anggota for guru and hides for murid',
      (tester) async {
        // 1. As guru
        final guruCalls = <String>[];
        final guruRouter = createRouter(
          httpClient: createMemberRoleClient(
            callerIsGuru: true,
            promoteCalls: guruCalls,
          ),
          initialLocation: '/kelas/MAT202/anggota',
        );
        addTearDown(guruRouter.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: guruRouter,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Opsi anggota'), findsOneWidget);

        await tester.tap(find.byTooltip('Opsi anggota'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Angkat menjadi guru'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ya'));
        await tester.pumpAndSettle();

        expect(guruCalls, ['/kelas/MAT202/anggota/2/guru']);
        expect(find.text('2 Orang'), findsOneWidget);

        // 2. As murid: promote option is hidden
        final muridRouter = createRouter(
          httpClient: createMemberRoleClient(callerIsGuru: false),
          initialLocation: '/kelas/MAT202/anggota',
        );
        addTearDown(muridRouter.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: muridRouter,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Opsi anggota'), findsNothing);
      },
    );

    testWidgets('shows error SnackBar when promote API fails', (tester) async {
      final ctrl = PengajarController(
        PengajarRepository(
          createMemberRoleClient(callerIsGuru: true, failPromote: true),
        ),
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: PengajarScreen(controller: ctrl)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ClassCard).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anggota'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opsi anggota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Angkat menjadi guru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya'));
      await tester.pumpAndSettle();

      expect(
        find.text('Hanya guru yang dapat mengangkat murid menjadi guru'),
        findsOneWidget,
      );
      expect(find.text('1 Orang'), findsNWidgets(2));
    });
  });
}
