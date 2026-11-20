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

  group('Pengumpulan & Penilaian repository routes', () {
    test(
      'getPengumpulanTugas hits /pengumpulan/saya, listPengumpulanTugas hits /pengumpulan, and simpanNilaiPengumpulan hits PATCH /pengumpulan/nilai',
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
                    'nilai': 90,
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
                    'nilai': null,
                    'dibuat': '2026-11-17T08:30:00Z',
                  },
                ]),
                200,
              );
            }
            if (request.url.path ==
                    '/kelas/MAT202/postingan/20/pengumpulan/nilai' &&
                request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final nilaiList = body['nilai'] as List<dynamic>;
              expect(nilaiList, [
                {'pengguna_id': 2, 'nilai': 95},
              ]);
              return http.Response(
                jsonEncode([
                  {
                    'id': 5,
                    'postingan_id': 20,
                    'pengguna_id': 2,
                    'nama': 'Budi Santoso',
                    'email': 'budi@example.com',
                    'profile_picture': '',
                    'lampiran': <String>[],
                    'nilai': 95,
                    'dibuat': '2026-11-17T08:00:00Z',
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
        expect(items[0].nilai, 90);
        expect(items[0].lampiran, hasLength(2));
        expect(items[0].isMarkAsDone, isFalse);
        expect(items[1].nama, 'Siti Aminah');
        expect(items[1].nilai, isNull);
        expect(items[1].isMarkAsDone, isTrue);

        final (graded, gradeErr) = await pengajarRepo.simpanNilaiPengumpulan(
          'MAT202',
          20,
          {2: 95},
        );
        expect(gradeErr, isNull);
        expect(graded, hasLength(1));
        expect(graded!.first.nilai, 95);

        expect(paths, [
          'GET /kelas/MAT202/postingan/20/pengumpulan/saya',
          'GET /kelas/MAT202/postingan/20/pengumpulan',
          'PATCH /kelas/MAT202/postingan/20/pengumpulan/nilai',
        ]);
      },
    );
  });

  group('PengumpulanPenilaianScreen unified monitoring & grading page', () {
    HttpClient createGuruClient({
      required List<Map<String, dynamic>> submissions,
      List<Map<String, dynamic>> members = const [],
      bool failFirstFetch = false,
      bool emptyAfterRefresh = false,
      List<Map<String, dynamic>>? savedPayloads,
    }) {
      final isoNow = DateTime(2026, 11, 17, 8, 0).toIso8601String();
      var listCalls = 0;
      final currentSubmissions = submissions
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

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
            return http.Response(jsonEncode(members), 200);
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
            return http.Response(jsonEncode(currentSubmissions), 200);
          }
          if (path == '/kelas/MAT202/postingan/20/pengumpulan/nilai' &&
              request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            savedPayloads?.add(body);
            final updates = (body['nilai'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
            for (final u in updates) {
              final uid = (u['pengguna_id'] as num).toInt();
              final score = (u['nilai'] as num?)?.toInt();
              final idx = currentSubmissions.indexWhere(
                (s) => s['pengguna_id'] == uid,
              );
              if (idx != -1) {
                currentSubmissions[idx] = {
                  ...currentSubmissions[idx],
                  'nilai': score,
                };
              } else {
                final member = members.firstWhere(
                  (m) => m['pengguna_id'] == uid,
                  orElse: () => {'nama': 'Murid #$uid', 'email': ''},
                );
                currentSubmissions.add({
                  'id': 99 + uid,
                  'postingan_id': 20,
                  'pengguna_id': uid,
                  'nama': member['nama'] ?? 'Murid #$uid',
                  'email': member['email'] ?? '',
                  'profile_picture': '',
                  'lampiran': <String>[],
                  'nilai': score,
                  'dibuat': isoNow,
                });
              }
            }
            return http.Response(jsonEncode(currentSubmissions), 200);
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
      'unified Pengumpulan & Penilaian merges submissions + unsubmitted students, opens attachment, saves grades to API, and refreshes',
      (tester) async {
        final launchedUris = <Uri>[];
        final savedPayloads = <Map<String, dynamic>>[];
        LampiranHelper.urlLauncherOverride =
            (uri, {mode = LaunchMode.platformDefault}) async {
          launchedUris.add(uri);
          return true;
        };

        final client = createGuruClient(
          emptyAfterRefresh: true,
          savedPayloads: savedPayloads,
          members: [
            {
              'pengguna_id': 1,
              'nama': 'Pak Guru',
              'email': 'guru@example.com',
              'guru': true,
            },
            {
              'pengguna_id': 2,
              'nama': 'Budi Santoso',
              'email': 'budi@example.com',
              'guru': false,
            },
            {
              'pengguna_id': 3,
              'nama': 'Siti Aminah',
              'email': 'siti@example.com',
              'guru': false,
            },
            {
              'pengguna_id': 4,
              'nama': 'Rina Belum',
              'email': 'rina@example.com',
              'guru': false,
            },
          ],
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
              'nilai': null,
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
              'nilai': null,
              'dibuat': '2026-11-17T08:30:00Z',
            },
          ],
        );

        await openGuruTugasDetail(tester, client);

        // Only the unified button exists (old dual buttons are merged)
        expect(find.text('Pengumpulan & Penilaian'), findsOneWidget);
        expect(find.text('Cek jawaban'), findsNothing);
        expect(find.text('Daftar pengumpulan'), findsNothing);

        await tester.ensureVisible(find.text('Pengumpulan & Penilaian'));
        await tester.tap(find.text('Pengumpulan & Penilaian'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(BackTitleRow, 'Pengumpulan & Penilaian'),
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

        // Enter score for Budi Santoso (user 2) and save to backend
        final budiScoreField = find.byKey(const ValueKey('nilai_input_u_2'));
        await tester.ensureVisible(budiScoreField);
        await tester.enterText(budiScoreField, '94');
        await tester.scrollUntilVisible(
          find.byKey(const Key('simpan_nilai_button')),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('simpan_nilai_button')));
        await tester.pumpAndSettle();

        expect(find.text('Nilai berhasil disimpan'), findsOneWidget);
        expect(savedPayloads, hasLength(1));
        expect(savedPayloads.first['nilai'], [
          {'pengguna_id': 2, 'nilai': 94},
        ]);

        // Filter to Ditugaskan -> student who has not submitted yet appears cleanly
        await tester.scrollUntilVisible(
          find.byKey(const Key('pengumpulan_status_filter')),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('pengumpulan_status_filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ditugaskan').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Rina Belum'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Rina Belum'), findsOneWidget);
        expect(find.text('Belum Mengumpulkan'), findsOneWidget);

        // Refresh -> now returns 0 submissions
        await tester.tap(find.byTooltip('Muat ulang'));
        await tester.pumpAndSettle();
        expect(find.text('0 Murid Mengumpulkan'), findsOneWidget);
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
        await tester.ensureVisible(find.text('Pengumpulan & Penilaian'));
        await tester.tap(find.text('Pengumpulan & Penilaian'));
        await tester.pumpAndSettle();

        expect(
          find.text('Hanya guru yang dapat melihat daftar pengumpulan tugas'),
          findsAtLeastNWidgets(1),
        );
        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.text('Budi Santoso'), findsOneWidget);

        // Non-guru cannot see unified Pengumpulan & Penilaian button
        await openGuruTugasDetail(tester, retryingClient, isGuru: false);
        expect(find.text('Pengumpulan & Penilaian'), findsNothing);
      },
    );
  });
}
