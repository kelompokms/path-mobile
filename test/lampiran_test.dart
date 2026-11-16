import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  tearDown(LampiranHelper.resetTestOverrides);

  group('LampiranHelper & PostinganModel unit tests', () {
    test('normalizeLampiranLink normalizes valid links and rejects unsafe schemes', () {
      expect(
        normalizeLampiranLink('https://example.com/a?b=1'),
        'https://example.com/a?b=1',
      );
      expect(
        normalizeLampiranLink('http://localhost:8080/file'),
        'http://localhost:8080/file',
      );
      expect(
        normalizeLampiranLink('  example.com/materi  '),
        'https://example.com/materi',
      );
      expect(
        normalizeLampiranLink('localhost:3000/test'),
        'https://localhost:3000/test',
      );

      expect(normalizeLampiranLink(''), isNull);
      expect(normalizeLampiranLink('   '), isNull);
      expect(normalizeLampiranLink('https://example.com/with space'), isNull);
      expect(normalizeLampiranLink('javascript:alert(1)'), isNull);
      expect(normalizeLampiranLink('data:text/html,<script>'), isNull);
      expect(normalizeLampiranLink('file:///etc/passwd'), isNull);
      expect(normalizeLampiranLink('https://'), isNull);
    });

    test('resolveLampiranUri resolves links and upload paths against baseUrl', () {
      expect(
        resolveLampiranUri(
          const LampiranItem(
            name: 'Link',
            detail: 'example.org/docs',
            isLink: true,
          ),
        ).toString(),
        'https://example.org/docs',
      );
      expect(
        resolveLampiranUri(
          const LampiranItem(
            name: 'tugas.pdf',
            detail: 'PDF',
            url: '/uploads/2026/11/16/abc.pdf',
          ),
          baseUrl: 'https://staging.pathclass.app',
        ).toString(),
        'https://staging.pathclass.app/uploads/2026/11/16/abc.pdf',
      );
      expect(
        resolveLampiranUri(
          const LampiranItem(
            name: 'tugas.pdf',
            detail: 'PDF',
            url: 'uploads/2026/11/16/abc.pdf',
          ),
        ).toString(),
        '${HttpClient.defaultBaseUrl}/uploads/2026/11/16/abc.pdf',
      );
      expect(
        resolveLampiranUri(
          const LampiranItem(name: 'Materi_AI_Test.pdf', detail: 'PDF'),
        ),
        isNull,
      );
    });

    test('PostinganModel.lampiranItems preserves URLs and distinguishes links vs uploads', () {
      final post = PostinganModel.fromJson({
        'id': 1,
        'judul': 'Materi 1',
        'deskripsi': 'Desc',
        'lampiran': [
          'https://example.com/materi',
          'https://example.com/blog/uploads/notes',
          '/uploads/2026/11/16/9f8e7d6c5b4a39281706f5e4d3c2b1a0.pdf',
          'https://api.pathclass.app/uploads/2026/11/16/11111111111111111111111111111111.docx',
        ],
        'pengguna_id': 1,
        'kelas_id': 1,
        'tipe_id': 2,
        'dibuat': '2026-11-16T09:00:00Z',
      });

      final items = post.lampiranItems;
      expect(items, hasLength(4));

      expect(items[0].isLink, isTrue);
      expect(items[0].targetUrl, 'https://example.com/materi');

      expect(items[1].isLink, isTrue);
      expect(items[1].targetUrl, 'https://example.com/blog/uploads/notes');

      expect(items[2].isLink, isFalse);
      expect(items[2].name, '9f8e7d6c5b4a39281706f5e4d3c2b1a0.pdf');
      expect(items[2].detail, 'PDF');
      expect(
        items[2].targetUrl,
        '/uploads/2026/11/16/9f8e7d6c5b4a39281706f5e4d3c2b1a0.pdf',
      );

      expect(items[3].isLink, isFalse);
      expect(items[3].name, '11111111111111111111111111111111.docx');
      expect(items[3].detail, 'DOCX');
      expect(
        items[3].targetUrl,
        'https://api.pathclass.app/uploads/2026/11/16/11111111111111111111111111111111.docx',
      );
    });

    test('uploadPickedLampiranFiles validates limits, sizes, and extensions', () async {
      var apiCalled = false;
      Future<(List<UploadedPostinganFile>?, String?)> fakeUpload(
        List<http.MultipartFile> files,
      ) async {
        apiCalled = true;
        return (
          [
            for (final f in files)
              UploadedPostinganFile(
                nama: f.filename ?? 'file',
                path: '/uploads/2026/11/16/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
                ukuran: f.length,
              ),
          ],
          null,
        );
      }

      // Unsupported extension
      final (badExt, badExtErr) = await uploadPickedLampiranFiles(
        [
          PickedLampiranFile(
            name: 'evil.html',
            size: 10,
            readBytes: () async => Uint8List.fromList([1, 2, 3]),
          ),
        ],
        currentCount: 0,
        onUploadFiles: fakeUpload,
      );
      expect(badExt, isNull);
      expect(badExtErr, contains('tidak didukung'));
      expect(apiCalled, isFalse);

      // Too large (> 10 MB)
      final (tooBig, tooBigErr) = await uploadPickedLampiranFiles(
        [
          PickedLampiranFile(
            name: 'huge.pdf',
            size: maxPostinganFileSizeBytes + 1,
            readBytes: () async => Uint8List(0),
          ),
        ],
        currentCount: 0,
        onUploadFiles: fakeUpload,
      );
      expect(tooBig, isNull);
      expect(tooBigErr, contains('10 MB'));
      expect(apiCalled, isFalse);

      // Empty file
      final (emptyFile, emptyErr) = await uploadPickedLampiranFiles(
        [
          PickedLampiranFile(
            name: 'empty.pdf',
            size: 0,
            readBytes: () async => Uint8List(0),
          ),
        ],
        currentCount: 0,
        onUploadFiles: fakeUpload,
      );
      expect(emptyFile, isNull);
      expect(emptyErr, contains('kosong'));
      expect(apiCalled, isFalse);

      // Exceeds max 5 files
      final (tooMany, tooManyErr) = await uploadPickedLampiranFiles(
        [
          PickedLampiranFile(
            name: 'a.pdf',
            size: 5,
            readBytes: () async => Uint8List.fromList([1, 2, 3, 4, 5]),
          ),
          PickedLampiranFile(
            name: 'b.pdf',
            size: 5,
            readBytes: () async => Uint8List.fromList([1, 2, 3, 4, 5]),
          ),
        ],
        currentCount: 4,
        onUploadFiles: fakeUpload,
      );
      expect(tooMany, isNull);
      expect(tooManyErr, contains('Maksimal $maxPostinganFiles'));
      expect(apiCalled, isFalse);

      // Successful upload returns LampiranItem with API path URL
      final (okItems, okErr) = await uploadPickedLampiranFiles(
        [
          PickedLampiranFile(
            name: 'catatan.pdf',
            size: 4,
            readBytes: () async => Uint8List.fromList([37, 80, 68, 70]),
          ),
        ],
        currentCount: 0,
        onUploadFiles: fakeUpload,
      );
      expect(okErr, isNull);
      expect(apiCalled, isTrue);
      expect(okItems, hasLength(1));
      expect(okItems!.first.name, 'catatan.pdf');
      expect(okItems.first.detail, 'PDF');
      expect(
        okItems.first.url,
        '/uploads/2026/11/16/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
      );
    });

    test('PengajarController.resolveLampiranPaths maps uploaded URLs and links without re-uploading', () {
      final ctrl = PengajarController(PengajarRepository(HttpClient()));
      addTearDown(ctrl.dispose);

      final resolved = ctrl.resolveLampiranPaths(const [
        LampiranItem(
          name: 'modul.pdf',
          detail: 'PDF',
          url: '/uploads/2026/11/16/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.pdf',
        ),
        LampiranItem(
          name: 'Link',
          detail: 'example.com/video',
          isLink: true,
        ),
        LampiranItem(name: 'Materi_AI_Stub.pdf', detail: 'PDF'),
      ]);

      expect(resolved, [
        '/uploads/2026/11/16/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.pdf',
        'https://example.com/video',
      ]);
    });
  });

  group('KelasScreen lampiran links & file upload', () {
    HttpClient createKelasTestClient({
      List<String>? uploadRequests,
      String uploadedPath =
          '/uploads/2026/11/16/11111111111111111111111111111111.pdf',
    }) {
      final isoNow = DateTime(2026, 11, 16, 9, 0).toIso8601String();
      return HttpClient(
        token: 'jwt.token',
        baseUrl: 'https://api.pathclass.app',
        client: MockClient((request) async {
          final path = request.url.path;
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
              return http.Response(
                jsonEncode([
                  {
                    'id': 10,
                    'judul': 'Materi Sel',
                    'deskripsi': 'Pelajari materi ini.',
                    'lampiran': [
                      'https://example.com/materi-sel',
                      '/uploads/2026/11/16/abcdef0123456789abcdef0123456789.pdf',
                    ],
                    'pengguna_id': 99,
                    'kelas_id': 1,
                    'tipe_id': 2,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
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
            uploadRequests?.add(request.headers['content-type'] ?? '');
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
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
    }

    testWidgets('opens link and uploaded file attachments on Materi detail', (
      tester,
    ) async {
      final launchedUris = <Uri>[];
      var shouldSucceed = true;
      LampiranHelper.urlLauncherOverride = (uri, {mode = LaunchMode.platformDefault}) async {
        launchedUris.add(uri);
        return shouldSucceed;
      };

      final ctrl = KelasController(KelasRepository(createKelasTestClient()));
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

      await tester.tap(find.text('Materi Sel'));
      await tester.pumpAndSettle();

      // Tap link attachment
      await tester.tap(find.text('https://example.com/materi-sel'));
      await tester.pumpAndSettle();
      expect(launchedUris, [Uri.parse('https://example.com/materi-sel')]);

      // Tap uploaded PDF attachment
      await tester.tap(
        find.text('abcdef0123456789abcdef0123456789.pdf'),
      );
      await tester.pumpAndSettle();
      expect(launchedUris, [
        Uri.parse('https://example.com/materi-sel'),
        Uri.parse(
          'https://api.pathclass.app/uploads/2026/11/16/abcdef0123456789abcdef0123456789.pdf',
        ),
      ]);

      // Launch failure surfaces SnackBar
      shouldSucceed = false;
      await tester.tap(find.text('https://example.com/materi-sel'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak dapat membuka lampiran'), findsOneWidget);
    });

    testWidgets(
      'opens link attachments and uploads file immediately on Tugas detail',
      (tester) async {
        final launchedUris = <Uri>[];
        final uploadHeaders = <String>[];
        LampiranHelper.urlLauncherOverride = (uri, {mode = LaunchMode.platformDefault}) async {
          launchedUris.add(uri);
          return true;
        };
        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'jawaban.pdf',
            size: 12,
            readBytes: () async =>
                Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
          ),
        ];

        final ctrl = KelasController(
          KelasRepository(createKelasTestClient(uploadRequests: uploadHeaders)),
        );
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

        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tugas Praktikum'));
        await tester.pumpAndSettle();

        // Tap existing link attachment on Tugas
        await tester.tap(find.text('https://example.com/referensi-tugas'));
        await tester.pumpAndSettle();
        expect(launchedUris, [
          Uri.parse('https://example.com/referensi-tugas'),
        ]);

        // Add uploaded file draft
        await tester.ensureVisible(find.text('Tambah'));
        await tester.tap(find.text('Tambah'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('File'));
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();

        expect(uploadHeaders, hasLength(1));
        expect(uploadHeaders.first, contains('multipart/form-data'));
        expect(find.text('jawaban.pdf'), findsOneWidget);

        // Tap newly uploaded draft file card -> opens uploaded URL
        await tester.ensureVisible(find.text('jawaban.pdf'));
        await tester.tap(find.text('jawaban.pdf'));
        await tester.pumpAndSettle();
        expect(launchedUris.last.toString(),
          'https://api.pathclass.app/uploads/2026/11/16/11111111111111111111111111111111.pdf',
        );

        // Add draft link: invalid javascript: link rejected, valid domain normalized
        await tester.ensureVisible(find.text('Link').last);
        await tester.tap(find.text('Link').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).last, 'javascript:alert(1)');
        await tester.pumpAndSettle();
        expect(find.text('Masukkan link http(s) yang valid'), findsOneWidget);
        final addBtn = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Tambah link'),
        );
        expect(addBtn.onPressed, isNull);

        await tester.enterText(find.byType(TextField).last, 'example.org/karya');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tambah link'));
        await tester.pumpAndSettle();

        expect(find.text('https://example.org/karya'), findsOneWidget);
        await tester.ensureVisible(find.text('https://example.org/karya'));
        await tester.tap(find.text('https://example.org/karya'));
        await tester.pumpAndSettle();
        expect(launchedUris.last, Uri.parse('https://example.org/karya'));
      },
    );
  });

  group('PengajarScreen immediate file upload & post submission', () {
    testWidgets(
      'uploads file immediately before post materi and sends returned URL on submit',
      (tester) async {
        final apiCalls = <({String method, String path, String body})>[];
        final isoNow = DateTime(2026, 11, 16, 9, 0).toIso8601String();
        const uploadedUrl =
            '/uploads/2026/11/16/22222222222222222222222222222222.pdf';

        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            final path = request.url.path;
            apiCalls.add((
              method: request.method,
              path: path,
              body: request.body,
            ));

            if (path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 2,
                    'nama': 'Matematika XI',
                    'tingkat': 11,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'MAT202',
                    'pengampu': 1,
                    'guru': true,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas/MAT202/posts' && request.method == 'GET') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/kelas/MAT202/anggota') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/files/postingan' && request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'nama': 'modul_aljabar.pdf',
                      'path': uploadedUrl,
                      'ukuran': 15,
                    },
                  ],
                }),
                201,
              );
            }
            if (path == '/kelas/MAT202/posts' && request.method == 'POST') {
              final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'id': 55,
                  'judul': reqJson['judul'],
                  'deskripsi': reqJson['deskripsi'] ?? '',
                  'lampiran': reqJson['lampiran'] ?? [],
                  'pengguna_id': 1,
                  'kelas_id': 2,
                  'tipe_id': reqJson['tipe'],
                  'dibuat': isoNow,
                }),
                201,
              );
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        );

        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'modul_aljabar.pdf',
            size: 15,
            readBytes: () async =>
                Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
          ),
        ];

        final ctrl = PengajarController(PengajarRepository(client));
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

        await tester.tap(find.text('Buat Materi'));
        await tester.pumpAndSettle();

        // Enter title
        await tester.enterText(
          find.widgetWithText(TextField, 'Ketikkan judul materi'),
          'Materi Aljabar',
        );
        await tester.pumpAndSettle();

        // Tap File -> immediate upload request happens BEFORE Simpan!
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();

        final uploadCallsBeforeSave = apiCalls
            .where((c) => c.path == '/files/postingan')
            .toList();
        expect(uploadCallsBeforeSave, hasLength(1));
        expect(find.text('modul_aljabar.pdf'), findsOneWidget);

        // Also attach a link
        await tester.tap(find.text('Link'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'example.com/video');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tambah link'));
        await tester.pumpAndSettle();

        // Submit materi -> sends uploaded URL directly without another /files/postingan upload
        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        final uploadCallsAfterSave = apiCalls
            .where((c) => c.path == '/files/postingan')
            .toList();
        expect(uploadCallsAfterSave, hasLength(1));

        final createPostCalls = apiCalls
            .where((c) => c.path == '/kelas/MAT202/posts' && c.method == 'POST')
            .toList();
        expect(createPostCalls, hasLength(1));
        final sentBody =
            jsonDecode(createPostCalls.first.body) as Map<String, dynamic>;
        expect(sentBody['judul'], 'Materi Aljabar');
        expect(sentBody['tipe'], PostinganModel.tipeMateri);
        expect(sentBody['lampiran'], [uploadedUrl, 'https://example.com/video']);
      },
    );

    testWidgets(
      'disables Simpan while upload is in-flight and handles upload API error in TugasForm',
      (tester) async {
        final uploadCompleter = Completer<http.Response>();
        final isoNow = DateTime(2026, 11, 16, 9, 0).toIso8601String();
        final patchedBodies = <Map<String, dynamic>>[];

        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            final path = request.url.path;
            if (path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 2,
                    'nama': 'Matematika XI',
                    'tingkat': 11,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'MAT202',
                    'pengampu': 1,
                    'guru': true,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas/MAT202/posts' && request.method == 'GET') {
              final tipe = request.url.queryParameters['tipe'];
              if (tipe == '1') {
                return http.Response(
                  jsonEncode([
                    {
                      'id': 77,
                      'judul': 'Tugas Lama',
                      'deskripsi': 'Deskripsi lama',
                      'lampiran': [
                        '/uploads/2026/11/16/33333333333333333333333333333333.pdf',
                      ],
                      'pengguna_id': 1,
                      'kelas_id': 2,
                      'tipe_id': 1,
                      'dibuat': isoNow,
                    },
                  ]),
                  200,
                );
              }
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/kelas/MAT202/anggota') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/files/postingan' && request.method == 'POST') {
              return uploadCompleter.future;
            }
            if (path == '/kelas/MAT202/postingan/77' &&
                request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              patchedBodies.add(body);
              return http.Response(
                jsonEncode({
                  'id': 77,
                  'judul': body['judul'],
                  'deskripsi': body['deskripsi'] ?? '',
                  'lampiran': body['lampiran'] ?? [],
                  'pengguna_id': 1,
                  'kelas_id': 2,
                  'tipe_id': 1,
                  'dibuat': isoNow,
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        );

        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'baru.pdf',
            size: 10,
            readBytes: () async => Uint8List.fromList([37, 80, 68, 70]),
          ),
        ];

        final ctrl = PengajarController(PengajarRepository(client));
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

        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        // Open Edit Tugas form
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(
          find.text('33333333333333333333333333333333.pdf'),
          findsOneWidget,
        );

        // Start file upload
        await tester.ensureVisible(find.text('File'));
        await tester.tap(find.text('File'));
        await tester.pump();

        // While uploading: spinner label visible and Simpan disabled
        expect(find.text('Mengunggah...'), findsOneWidget);
        final saveBtnDuringUpload = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Simpan'),
        );
        expect(saveBtnDuringUpload.onPressed, isNull);

        // Fail the upload
        uploadCompleter.complete(
          http.Response(jsonEncode({'message': 'Tipe file tidak valid'}), 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tipe file tidak valid'), findsOneWidget);
        expect(find.text('baru.pdf'), findsNothing);

        // Wait for SnackBar to dismiss so Simpan is uncovered, then tap Simpan
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchedBodies, hasLength(1));
        expect(patchedBodies.first['lampiran'], [
          '/uploads/2026/11/16/33333333333333333333333333333333.pdf',
        ]);
      },
    );

    testWidgets(
      'uploads file immediately in TugasForm and sends returned URL on createTugas',
      (tester) async {
        final apiCalls = <({String method, String path, String body})>[];
        final isoNow = DateTime(2026, 11, 16, 9, 0).toIso8601String();
        const uploadedUrl =
            '/uploads/2026/11/16/44444444444444444444444444444444.docx';

        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            final path = request.url.path;
            apiCalls.add((
              method: request.method,
              path: path,
              body: request.body,
            ));

            if (path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 2,
                    'nama': 'Matematika XI',
                    'tingkat': 11,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'MAT202',
                    'pengampu': 1,
                    'guru': true,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas/MAT202/posts' && request.method == 'GET') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/kelas/MAT202/anggota') {
              return http.Response(jsonEncode([]), 200);
            }
            if (path == '/files/postingan' && request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'nama': 'soal_tugas.docx',
                      'path': uploadedUrl,
                      'ukuran': 24,
                    },
                  ],
                }),
                201,
              );
            }
            if (path == '/kelas/MAT202/posts' && request.method == 'POST') {
              final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'id': 88,
                  'judul': reqJson['judul'],
                  'deskripsi': reqJson['deskripsi'] ?? '',
                  'lampiran': reqJson['lampiran'] ?? [],
                  'pengguna_id': 1,
                  'kelas_id': 2,
                  'tipe_id': reqJson['tipe'],
                  'dibuat': isoNow,
                }),
                201,
              );
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        );

        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'soal_tugas.docx',
            size: 24,
            readBytes: () async => Uint8List.fromList(List.filled(24, 65)),
          ),
        ];

        final ctrl = PengajarController(PengajarRepository(client));
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

        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tambah Tugas'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Ketikkan judul tugas'),
          'Tugas 1',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('File'));
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();

        expect(
          apiCalls.where((c) => c.path == '/files/postingan'),
          hasLength(1),
        );
        expect(find.text('soal_tugas.docx'), findsOneWidget);

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(
          apiCalls.where((c) => c.path == '/files/postingan'),
          hasLength(1),
        );
        final createCalls = apiCalls
            .where((c) => c.path == '/kelas/MAT202/posts' && c.method == 'POST')
            .toList();
        expect(createCalls, hasLength(1));
        final sent = jsonDecode(createCalls.first.body) as Map<String, dynamic>;
        expect(sent['judul'], 'Tugas 1');
        expect(sent['tipe'], PostinganModel.tipeTugas);
        expect(sent['lampiran'], [uploadedUrl]);
      },
    );
  });
}
