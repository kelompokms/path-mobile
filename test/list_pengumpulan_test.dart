import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  tearDown(LampiranHelper.resetTestOverrides);

  group('ListPengumpulan repository route distinction', () {
    test(
      'getPengumpulanTugas hits /pengumpulan/saya and listPengumpulanTugas hits /pengumpulan',
      () async {
        final paths = <String>[];
        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            paths.add('${request.method} ${request.url.path}');
            if (request.url.path == '/kelas/MAT202/postingan/20/pengumpulan/saya') {
              return http.Response(
                jsonEncode({
                  'id': 0,
                  'postingan_id': 20,
                  'pengguna_id': 2,
                  'submitted': false,
                  'lampiran': <String>[],
                }),
                200,
              );
            }
            if (request.url.path == '/kelas/MAT202/postingan/20/pengumpulan') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 5,
                    'postingan_id': 20,
                    'pengguna_id': 2,
                    'nama': 'Budi Santoso',
                    'email': 'budi@example.com',
                    'profile_picture': '',
                    'lampiran': [
                      '/uploads/2026/11/16/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
                      'https://example.com/karya-budi',
                    ],
                    'dibuat': '2026-11-17T08:00:00Z',
                  },
                  {
                    'id': 6,
                    'postingan_id': 20,
                    'pengguna_id': 3,
                    'nama': 'Siti Aminah',
                    'email': 'siti@example.com',
                    'profile_picture': '',
                    'lampiran': <String>[],
                    'dibuat': '2026-11-17T08:30:00Z',
                  },
                ]),
                200,
              );
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        );

        final kelasRepo = KelasRepository(client);
        final pengajarRepo = PengajarRepository(client);

        final (mine, mineErr) = await kelasRepo.getPengumpulanTugas('MAT202', 20);
        expect(mineErr, isNull);
        expect(mine!.submitted, isFalse);

        final (items, listErr) = await pengajarRepo.listPengumpulanTugas('MAT202', 20);
        expect(listErr, isNull);
        expect(items, hasLength(2));
        expect(items![0].nama, 'Budi Santoso');
        expect(items[0].lampiran, hasLength(2));
        expect(items[0].isMarkAsDone, isFalse);
        expect(items[1].nama, 'Siti Aminah');
        expect(items[1].isMarkAsDone, isTrue);

        expect(paths, [
          'GET /kelas/MAT202/postingan/20/pengumpulan/saya',
          'GET /kelas/MAT202/postingan/20/pengumpulan',
        ]);
      },
    );
  });

  group('ListPengumpulanScreen monitoring page', () {
    HttpClient createGuruClient({
      required List<Map<String, dynamic>> submissions,
      bool failFirstFetch = false,
      bool emptyAfterRefresh = false,
    }) {
      final isoNow = DateTime(2026, 11, 17, 8, 0).toIso8601String();
      var listCalls = 0;

      return HttpClient(
        token: 'jwt.token',
        baseUrl: 'https://api.pathclass.app',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/kelas/MAT202/posts') {
            final tipe = request.url.queryParameters['tipe'];
            if (tipe == '2') {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 20,
                  'judul': 'Tugas Algoritma',
                  'deskripsi': 'Kumpulkan solusi latihan.',
                  'lampiran': <String>[],
                  'pengguna_id': 1,
                  'kelas_id': 2,
                  'tipe_id': 1,
                  'dibuat': isoNow,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/MAT202/anggota') {
            return http.Response(jsonEncode([]), 200);
          }
          if (path == '/kelas/MAT202/postingan/20/pengumpulan' &&
              request.method == 'GET') {
            listCalls++;
            if (failFirstFetch && listCalls == 1) {
              return http.Response(
                jsonEncode({
                  'message': 'Hanya guru yang dapat melihat daftar pengumpulan tugas',
                }),
                403,
              );
            }
            if (emptyAfterRefresh && listCalls > 1) {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(jsonEncode(submissions), 200);
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
    }

    Future<void> openGuruTugasDetail(
      WidgetTester tester,
      HttpClient client, {
      bool isGuru = true,
    }) async {
      final ctrl = PengajarController(PengajarRepository(client));
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PengajarDetailScreen(
              classData: ClassItem(
                title: 'Matematika XI',
                grade: 'Kelas XI',
                code: 'MAT202',
                isGuru: isGuru,
              ),
              controller: ctrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tugas Algoritma'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'teacher navigates to ListPengumpulanScreen, sees student submissions, opens attachment, and refreshes',
      (tester) async {
        final launchedUris = <Uri>[];
        LampiranHelper.urlLauncherOverride =
            (uri, {mode = LaunchMode.platformDefault}) async {
          launchedUris.add(uri);
          return true;
        };

        final client = createGuruClient(
          emptyAfterRefresh: true,
          submissions: [
            {
              'id': 5,
              'postingan_id': 20,
              'pengguna_id': 2,
              'nama': 'Budi Santoso',
              'email': 'budi@example.com',
              'profile_picture': '',
              'lampiran': [
                'https://example.com/jawaban-budi',
                '/uploads/2026/11/16/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
              ],
              'dibuat': '2026-11-17T08:00:00Z',
            },
            {
              'id': 6,
              'postingan_id': 20,
              'pengguna_id': 3,
              'nama': 'Siti Aminah',
              'email': 'siti@example.com',
              'profile_picture': '',
              'lampiran': <String>[],
              'dibuat': '2026-11-17T08:30:00Z',
            },
          ],
        );

        await openGuruTugasDetail(tester, client);

        expect(find.text('Cek jawaban'), findsOneWidget);
        expect(find.text('Daftar pengumpulan'), findsOneWidget);

        await tester.ensureVisible(find.text('Daftar pengumpulan'));
        await tester.tap(find.text('Daftar pengumpulan'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(BackTitleRow, 'Daftar Pengumpulan'),
          findsOneWidget,
        );
        expect(find.text('2 Murid Mengumpulkan'), findsOneWidget);
        expect(find.text('Budi Santoso'), findsOneWidget);
        expect(find.text('budi@example.com'), findsOneWidget);
        expect(find.text('2 Lampiran'), findsOneWidget);
        expect(find.text('https://example.com/jawaban-budi'), findsOneWidget);

        expect(find.text('Siti Aminah'), findsOneWidget);
        expect(find.text('Ditandai Selesai'), findsOneWidget);
        expect(
          find.text('Ditandai sebagai selesai tanpa lampiran'),
          findsOneWidget,
        );

        // Open student link attachment
        await tester.ensureVisible(find.text('https://example.com/jawaban-budi'));
        await tester.tap(find.text('https://example.com/jawaban-budi'));
        await tester.pumpAndSettle();
        expect(launchedUris, [Uri.parse('https://example.com/jawaban-budi')]);

        // Refresh -> now returns empty state
        await tester.tap(find.byTooltip('Muat ulang'));
        await tester.pumpAndSettle();
        expect(find.text('0 Murid Mengumpulkan'), findsOneWidget);
        expect(
          find.text('Belum ada murid yang mengumpulkan tugas'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays error and recovers on retry, and hides button for non-guru',
      (tester) async {
        final retryingClient = createGuruClient(
          failFirstFetch: true,
          submissions: [
            {
              'id': 5,
              'postingan_id': 20,
              'pengguna_id': 2,
              'nama': 'Budi Santoso',
              'email': 'budi@example.com',
              'profile_picture': '',
              'lampiran': ['https://example.com/jawaban-budi'],
              'dibuat': '2026-11-17T08:00:00Z',
            },
          ],
        );

        await openGuruTugasDetail(tester, retryingClient, isGuru: true);
        await tester.ensureVisible(find.text('Daftar pengumpulan'));
        await tester.tap(find.text('Daftar pengumpulan'));
        await tester.pumpAndSettle();

        expect(
          find.text('Hanya guru yang dapat melihat daftar pengumpulan tugas'),
          findsAtLeastNWidgets(1),
        );
        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.text('Budi Santoso'), findsOneWidget);

        // Non-guru cannot see monitoring button
        await openGuruTugasDetail(tester, retryingClient, isGuru: false);
        expect(find.text('Daftar pengumpulan'), findsNothing);
      },
    );
  });
}
