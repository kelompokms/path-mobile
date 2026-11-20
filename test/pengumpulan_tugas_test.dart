import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(LampiranHelper.resetTestOverrides);

  group('Pengumpulan Tugas repository tests', () {
    test('get, submit, and tarik pengumpulan call expected endpoints', () async {
      final calls = <({String method, String path, String body})>[];
      const uploadedPath =
          '/uploads/2026/11/16/11111111111111111111111111111111.pdf';
      final client = HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          calls.add((
            method: request.method,
            path: request.url.path,
            body: request.body,
          ));
          if (request.url.path == '/kelas/BIO101/postingan/20/pengumpulan/saya' &&
              request.method == 'GET') {
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
          if (request.url.path == '/kelas/BIO101/postingan/20/pengumpulan') {
            if (request.method == 'POST') {
              final req = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'id': 5,
                  'postingan_id': 20,
                  'pengguna_id': 2,
                  'submitted': true,
                  'lampiran': req['lampiran'],
                  'dibuat': '2026-11-16T10:00:00Z',
                }),
                201,
              );
            }
            if (request.method == 'DELETE') {
              return http.Response(
                jsonEncode({
                  'message': 'Pengumpulan tugas berhasil ditarik',
                  'lampiran': [uploadedPath],
                }),
                200,
              );
            }
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
      final repo = KelasRepository(client);

      final (initial, getErr) = await repo.getPengumpulanTugas('BIO101', 20);
      expect(getErr, isNull);
      expect(initial!.submitted, isFalse);
      expect(initial.lampiran, isEmpty);

      final (submitted, submitErr) = await repo.submitPengumpulanTugas(
        'BIO101',
        20,
        [uploadedPath],
      );
      expect(submitErr, isNull);
      expect(submitted!.submitted, isTrue);
      expect(submitted.lampiran, [uploadedPath]);

      final (withdrawn, tarikErr) = await repo.tarikPengumpulanTugas(
        'BIO101',
        20,
      );
      expect(tarikErr, isNull);
      expect(withdrawn, [uploadedPath]);

      expect(calls.map((c) => '${c.method} ${c.path}').toList(), [
        'GET /kelas/BIO101/postingan/20/pengumpulan/saya',
        'POST /kelas/BIO101/postingan/20/pengumpulan',
        'DELETE /kelas/BIO101/postingan/20/pengumpulan',
      ]);
      expect(jsonDecode(calls[1].body), {
        'lampiran': [uploadedPath],
      });
    });

    test('surfaces server error message when tarikPengumpulanTugas fails', () async {
      final client = HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Pengumpulan tugas tidak ditemukan'}),
            404,
          );
        }),
      );
      final repo = KelasRepository(client);

      final (res, err) = await repo.tarikPengumpulanTugas('BIO101', 20);
      expect(res, isNull);
      expect(err, 'Pengumpulan tugas tidak ditemukan');
    });
  });

  group('Murid tarik pengumpulan tugas UI flows', () {
    HttpClient createStudentClient({
      required List<String> initialSubmittedLampiran,
      required bool initiallySubmitted,
      int? initialNilai,
      bool failTarik = false,
      List<({String method, String path, dynamic body})>? requestLog,
    }) {
      var submitted = initiallySubmitted;
      var storedLampiran = List<String>.from(initialSubmittedLampiran);
      var storedNilai = initialNilai;
      final isoNow = DateTime(2026, 11, 16, 9, 0).toIso8601String();
      const uploadedPath =
          '/uploads/2026/11/16/11111111111111111111111111111111.pdf';

      return HttpClient(
        token: 'jwt.token',
        baseUrl: 'https://api.pathclass.app',
        client: MockClient((request) async {
          final path = request.url.path;
          final isJson = (request.headers['content-type'] ?? '').contains(
            'application/json',
          );
          requestLog?.add((
            method: request.method,
            path: path,
            body: (isJson && request.body.isNotEmpty)
                ? jsonDecode(request.body)
                : null,
          ));

          if (path == '/kelas') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama': 'Biologi Kelas X',
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
            final tipe = request.url.queryParameters['tipe'];
            if (tipe == '2') {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 20,
                  'judul': 'Tugas Praktikum',
                  'deskripsi': 'Kerjakan sesuai petunjuk.',
                  'lampiran': ['https://example.com/referensi-tugas'],
                  'pengguna_id': 99,
                  'kelas_id': 1,
                  'tipe_id': 1,
                  'dibuat': isoNow,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/BIO101/anggota') {
            return http.Response(jsonEncode([]), 200);
          }
          if (path == '/files/postingan' && request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'nama': 'jawaban.pdf',
                    'path': uploadedPath,
                    'ukuran': 12,
                  },
                ],
              }),
              201,
            );
          }
          if (path == '/kelas/BIO101/postingan/20/pengumpulan/saya' &&
              request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': submitted ? 5 : 0,
                'postingan_id': 20,
                'pengguna_id': 2,
                'submitted': submitted,
                'lampiran': storedLampiran,
                if (storedNilai != null) 'nilai': storedNilai,
                if (submitted) 'dibuat': isoNow,
              }),
              200,
            );
          }
          if (path == '/kelas/BIO101/postingan/20/pengumpulan') {
            if (request.method == 'POST') {
              final req = jsonDecode(request.body) as Map<String, dynamic>;
              storedLampiran = (req['lampiran'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();
              submitted = true;
              return http.Response(
                jsonEncode({
                  'id': 5,
                  'postingan_id': 20,
                  'pengguna_id': 2,
                  'submitted': true,
                  'lampiran': storedLampiran,
                  'dibuat': isoNow,
                }),
                201,
              );
            }
            if (request.method == 'DELETE') {
              if (failTarik) {
                return http.Response(
                  jsonEncode({'message': 'Gagal menarik pengumpulan tugas'}),
                  500,
                );
              }
              final withdrawn = List<String>.from(storedLampiran);
              storedLampiran = [];
              storedNilai = null;
              submitted = false;
              return http.Response(
                jsonEncode({
                  'message': 'Pengumpulan tugas berhasil ditarik',
                  'lampiran': withdrawn,
                }),
                200,
              );
            }
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
    }

    Future<void> openTugasDetail(
      WidgetTester tester,
      HttpClient client,
    ) async {
      final ctrl = KelasController(KelasRepository(client));
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.lightTheme,
          home: Scaffold(body: KelasScreen(controller: ctrl)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ClassCard).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tugas Praktikum'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'submits attachments, withdraws submission to editable drafts, edits, and resubmits',
      (tester) async {
        const uploadedPath =
            '/uploads/2026/11/16/11111111111111111111111111111111.pdf';
        final requestLog = <({String method, String path, dynamic body})>[];

        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'jawaban.pdf',
            size: 12,
            readBytes: () async =>
                Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
          ),
        ];

        final client = createStudentClient(
          initiallySubmitted: false,
          initialSubmittedLampiran: const [],
          requestLog: requestLog,
        );

        await openTugasDetail(tester, client);

        expect(find.text('Ditugaskan'), findsOneWidget);
        expect(find.text('https://example.com/referensi-tugas'), findsOneWidget);

        await _tapVisible(tester, find.text('Tambah'));
        await _tapVisible(tester, find.text('File'));
        expect(find.text('jawaban.pdf'), findsOneWidget);

        await _tapVisible(tester, find.text('Link').last);
        await tester.enterText(find.byType(TextField).last, 'example.org/karya');
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Tambah link'));
        expect(find.text('https://example.org/karya'), findsOneWidget);

        // Serahkan submission
        await _tapVisible(tester, find.text('Serahkan'));
        expect(find.text('Dikumpulkan'), findsOneWidget);
        expect(find.text('Tugas berhasil diserahkan'), findsOneWidget);
        expect(find.text('Tarik Pengumpulan'), findsOneWidget);
        expect(find.byTooltip('Hapus lampiran'), findsNothing);

        // Cancel withdraw confirmation keeps Dikumpulkan
        await _tapVisible(tester, find.text('Tarik Pengumpulan'));
        expect(
          find.text('Apakah anda yakin ingin menarik pengumpulan tugas ini?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Tidak'));
        await tester.pumpAndSettle();
        expect(find.text('Dikumpulkan'), findsOneWidget);

        // Confirm withdraw moves attachments back to drafts with status Ditugaskan
        await _tapVisible(tester, find.text('Tarik Pengumpulan'));
        await tester.tap(find.text('Ya'));
        await tester.pumpAndSettle();

        expect(find.text('Ditugaskan'), findsOneWidget);
        expect(find.text('Pengumpulan tugas berhasil ditarik'), findsOneWidget);
        expect(find.text('jawaban.pdf'), findsOneWidget);
        expect(find.text('https://example.org/karya'), findsOneWidget);
        expect(find.byTooltip('Hapus lampiran'), findsNWidgets(2));
        expect(find.text('Serahkan'), findsOneWidget);

        // Remove the link draft and resubmit
        await _tapVisible(tester, find.byTooltip('Hapus lampiran').last);
        expect(find.text('https://example.org/karya'), findsNothing);

        await _tapVisible(tester, find.text('Serahkan'));
        expect(find.text('Dikumpulkan'), findsOneWidget);

        // Navigate back and reopen Tugas -> GET syncs Dikumpulkan from server
        await _tapVisible(tester, find.byIcon(Icons.arrow_back).first);
        await _tapVisible(tester, find.text('Tugas Praktikum'));
        expect(find.text('Dikumpulkan'), findsOneWidget);
        expect(find.text('jawaban.pdf'), findsOneWidget);
        expect(find.text('Tarik Pengumpulan'), findsOneWidget);

        final submissionCalls = requestLog
            .where((r) => r.path.startsWith('/kelas/BIO101/postingan/20/pengumpulan'))
            .toList();
        expect(submissionCalls.map((c) => '${c.method} ${c.path}').toList(), [
          'GET /kelas/BIO101/postingan/20/pengumpulan/saya',
          'POST /kelas/BIO101/postingan/20/pengumpulan',
          'DELETE /kelas/BIO101/postingan/20/pengumpulan',
          'POST /kelas/BIO101/postingan/20/pengumpulan',
          'GET /kelas/BIO101/postingan/20/pengumpulan/saya',
        ]);
        expect(submissionCalls[1].body, {
          'lampiran': [uploadedPath, 'https://example.org/karya'],
        });
        expect(submissionCalls[3].body, {
          'lampiran': [uploadedPath],
        });
      },
    );

    testWidgets(
      'withdraws mark-as-done submission and resubmits cleanly',
      (tester) async {
        final requestLog = <({String method, String path, dynamic body})>[];
        final markDoneClient = createStudentClient(
          initiallySubmitted: true,
          initialSubmittedLampiran: const [],
          requestLog: requestLog,
        );

        await openTugasDetail(tester, markDoneClient);

        expect(find.text('Ditandai Sebagai Selesai'), findsOneWidget);
        expect(find.text('Tarik Pengumpulan'), findsOneWidget);

        await _tapVisible(tester, find.text('Tarik Pengumpulan'));
        await tester.tap(find.text('Ya'));
        await tester.pumpAndSettle();

        expect(find.text('Ditugaskan'), findsOneWidget);
        expect(find.text('Tambah'), findsOneWidget);
        expect(find.text('Tandai Sebagai Selesai'), findsOneWidget);

        // Re-mark as done
        await _tapVisible(tester, find.text('Tandai Sebagai Selesai'));
        expect(find.text('Ditandai Sebagai Selesai'), findsOneWidget);

        final postCall = requestLog.lastWhere(
          (r) =>
              r.method == 'POST' &&
              r.path == '/kelas/BIO101/postingan/20/pengumpulan',
        );
        expect(postCall.body, {'lampiran': []});
      },
    );

    testWidgets(
      'preserves submitted state and shows SnackBar when withdraw fails on server',
      (tester) async {
        const uploadedPath =
            '/uploads/2026/11/16/11111111111111111111111111111111.pdf';
        final failingClient = createStudentClient(
          initiallySubmitted: true,
          initialSubmittedLampiran: const [uploadedPath],
          failTarik: true,
        );

        await openTugasDetail(tester, failingClient);
        expect(find.text('Dikumpulkan'), findsOneWidget);
        expect(
          find.text('11111111111111111111111111111111.pdf'),
          findsOneWidget,
        );

        await _tapVisible(tester, find.text('Tarik Pengumpulan'));
        await tester.tap(find.text('Ya'));
        await tester.pumpAndSettle();

        expect(find.text('Gagal menarik pengumpulan tugas'), findsOneWidget);
        expect(find.text('Dikumpulkan'), findsOneWidget);
        expect(
          find.text('11111111111111111111111111111111.pdf'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays graded nilai (including 0) from server instead of .../100 and resets on withdraw',
      (tester) async {
        const uploadedPath =
            '/uploads/2026/11/16/11111111111111111111111111111111.pdf';
        final gradedClient = createStudentClient(
          initiallySubmitted: true,
          initialSubmittedLampiran: const [uploadedPath],
          initialNilai: 92,
        );

        await openTugasDetail(tester, gradedClient);
        expect(find.byKey(const Key('murid_nilai_text')), findsOneWidget);
        expect(find.text('92/100'), findsOneWidget);
        expect(find.text('.../100'), findsNothing);
        expect(find.text('Dinilai'), findsOneWidget);
        expect(
          find.text('11111111111111111111111111111111.pdf'),
          findsOneWidget,
        );

        // Pulling submission resets displayed nilai back to .../100
        await _tapVisible(tester, find.text('Tarik Pengumpulan'));
        await tester.tap(find.text('Ya'));
        await tester.pumpAndSettle();

        expect(find.text('.../100'), findsOneWidget);
        expect(find.text('Ditugaskan'), findsOneWidget);

        // Score of 0 is displayed explicitly as 0/100
        final zeroClient = createStudentClient(
          initiallySubmitted: true,
          initialSubmittedLampiran: const [],
          initialNilai: 0,
        );
        await openTugasDetail(tester, zeroClient);
        expect(find.text('0/100'), findsOneWidget);
        expect(find.text('Dinilai'), findsOneWidget);
      },
    );
  });
}
