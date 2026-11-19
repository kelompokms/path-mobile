import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

void main() {
  tearDown(LampiranHelper.resetTestOverrides);

  group('Edit judul, deskripsi, & lampiran postingan (materi & tugas)', () {
    const uploadedPath =
        '/uploads/2026/11/17/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf';
    HttpClient createEditClient({
      required List<({String method, String path, Map<String, dynamic> body})>
      patchCalls,
      bool failPatch = false,
      bool isGuru = true,
      String uploadedFileName = 'revisi.pdf',
    }) {
      final isoNow = DateTime(2026, 11, 16, 10, 0).toIso8601String();
      var materi = {
        'id': 10,
        'judul': 'Materi Awal',
        'deskripsi': 'Deskripsi materi awal',
        'lampiran': ['https://example.com/materi-awal'],
        'pengguna_id': 1,
        'kelas_id': 2,
        'tipe_id': PostinganModel.tipeMateri,
        'dibuat': isoNow,
      };
      var tugas = {
        'id': 20,
        'judul': 'Tugas Awal',
        'deskripsi': 'Deskripsi tugas awal',
        'lampiran': ['https://example.com/tugas-awal'],
        'pengguna_id': 1,
        'kelas_id': 2,
        'tipe_id': PostinganModel.tipeTugas,
        'dibuat': isoNow,
      };

      return HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/kelas') {
            return http.Response(
              jsonEncode([
                {
                  'id': 2,
                  'nama': 'Matematika XI',
                  'deskripsi': 'Kelas XI',
                  'tingkat': 11,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'MAT202',
                  'pengampu': 1,
                  'guru': isGuru,
                  'dibuat': isoNow,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/MAT202/posts' && request.method == 'GET') {
            final tipe = request.url.queryParameters['tipe'];
            if (tipe == '${PostinganModel.tipeMateri}') {
              return http.Response(jsonEncode([materi]), 200);
            }
            if (tipe == '${PostinganModel.tipeTugas}') {
              return http.Response(jsonEncode([tugas]), 200);
            }
            return http.Response(jsonEncode([materi, tugas]), 200);
          }
          if (path == '/kelas/MAT202/anggota') {
            return http.Response(jsonEncode([]), 200);
          }
          if (path == '/files/postingan' && request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'nama': uploadedFileName,
                    'path': uploadedPath,
                    'ukuran': 12,
                  },
                ],
              }),
              201,
            );
          }
          if (path == '/kelas/MAT202/postingan/10' &&
              request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            patchCalls.add((method: 'PATCH', path: path, body: body));
            if (failPatch) {
              return http.Response(
                jsonEncode({'message': 'Hanya guru yang dapat mengubah postingan'}),
                403,
              );
            }
            materi = {
              ...materi,
              'judul': body['judul'],
              'deskripsi': body['deskripsi'] ?? '',
              'lampiran': body['lampiran'] ?? materi['lampiran'],
              'tipe_id': body['tipe'],
            };
            return http.Response(jsonEncode(materi), 200);
          }
          if (path == '/kelas/MAT202/postingan/20' &&
              request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            patchCalls.add((method: 'PATCH', path: path, body: body));
            if (failPatch) {
              return http.Response(
                jsonEncode({'message': 'Gagal memperbarui postingan'}),
                500,
              );
            }
            tugas = {
              ...tugas,
              'judul': body['judul'],
              'deskripsi': body['deskripsi'] ?? '',
              'lampiran': body['lampiran'] ?? tugas['lampiran'],
              'tipe_id': body['tipe'],
            };
            return http.Response(jsonEncode(tugas), 200);
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
    }

    testWidgets(
      'edits materi judul & deskripsi via menu and detail screen using PATCH endpoint',
      (tester) async {
        final patchCalls =
            <({String method, String path, Map<String, dynamic> body})>[];
        final ctrl = PengajarController(
          PengajarRepository(
            createEditClient(
              patchCalls: patchCalls,
              uploadedFileName: 'modul_revisi.pdf',
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

        // 1. Edit materi via card popup menu
        final materiCard = find.ancestor(
          of: find.text('Materi Awal'),
          matching: find.byType(PostCard),
        );
        await tester.tap(
          find.descendant(
            of: materiCard,
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        // Blank title disables Simpan and shows validation
        await tester.enterText(
          find.widgetWithText(TextField, 'Materi Awal'),
          '   ',
        );
        await tester.pumpAndSettle();
        expect(find.text('Judul wajib diisi'), findsOneWidget);
        expect(
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Simpan')).onPressed,
          isNull,
        );

        await tester.enterText(
          find.widgetWithText(TextField, '   '),
          'Materi Bab 1 Revisi',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Deskripsi materi awal'),
          'Deskripsi materi telah diperbarui',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(1));
        expect(patchCalls.first.path, '/kelas/MAT202/postingan/10');
        expect(patchCalls.first.body, {
          'judul': 'Materi Bab 1 Revisi',
          'deskripsi': 'Deskripsi materi telah diperbarui',
          'lampiran': ['https://example.com/materi-awal'],
          'tipe': PostinganModel.tipeMateri,
        });
        expect(find.text('Materi Bab 1 Revisi'), findsOneWidget);

        // Wait for SnackBar to vanish then open Materi detail and edit again via Edit icon
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Materi Bab 1 Revisi'));
        await tester.pumpAndSettle();

        expect(find.text('Deskripsi materi telah diperbarui'), findsOneWidget);
        await tester.tap(find.byTooltip('Edit materi'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Materi Bab 1 Revisi'),
          'Materi Bab 1 Final',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Deskripsi materi telah diperbarui'),
          'Deskripsi final',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(2));
        expect(patchCalls[1].path, '/kelas/MAT202/postingan/10');
        expect(patchCalls[1].body['judul'], 'Materi Bab 1 Final');
        expect(patchCalls[1].body['deskripsi'], 'Deskripsi final');
        expect(find.text('Materi Bab 1 Final'), findsOneWidget);
        expect(find.text('Deskripsi final'), findsOneWidget);

        // Navigate back to list and confirm updated title is synced
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
        expect(find.text('Materi Bab 1 Final'), findsOneWidget);
      },
    );

    testWidgets(
      'edits tugas judul & deskripsi via menu and detail screen using PATCH endpoint',
      (tester) async {
        final patchCalls =
            <({String method, String path, Map<String, dynamic> body})>[];
        final ctrl = PengajarController(
          PengajarRepository(
            createEditClient(
              patchCalls: patchCalls,
              uploadedFileName: 'modul_revisi.pdf',
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

        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        // 1. Edit tugas via popup menu
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Tugas Awal'),
          'Tugas Bab 1 Revisi',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Deskripsi tugas awal'),
          'Kerjakan soal 1 sampai 5',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(1));
        expect(patchCalls.first.path, '/kelas/MAT202/postingan/20');
        expect(patchCalls.first.body, {
          'judul': 'Tugas Bab 1 Revisi',
          'deskripsi': 'Kerjakan soal 1 sampai 5',
          'lampiran': ['https://example.com/tugas-awal'],
          'tipe': PostinganModel.tipeTugas,
        });
        expect(find.text('Tugas Bab 1 Revisi'), findsOneWidget);

        // 2. Open Tugas detail and edit via Edit tugas button
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tugas Bab 1 Revisi'));
        await tester.pumpAndSettle();

        expect(find.text('Kerjakan soal 1 sampai 5'), findsOneWidget);
        await tester.tap(find.byTooltip('Edit tugas'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Tugas Bab 1 Revisi'),
          'Tugas Bab 1 Final',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Kerjakan soal 1 sampai 5'),
          'Kerjakan semua soal latihan',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(2));
        expect(patchCalls[1].path, '/kelas/MAT202/postingan/20');
        expect(patchCalls[1].body['judul'], 'Tugas Bab 1 Final');
        expect(patchCalls[1].body['deskripsi'], 'Kerjakan semua soal latihan');
        expect(find.text('Tugas Bab 1 Final'), findsOneWidget);
        expect(find.text('Kerjakan semua soal latihan'), findsOneWidget);

        // Navigate back to Tugas list and confirm synced title
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
        expect(find.text('Tugas Bab 1 Final'), findsOneWidget);
      },
    );

    testWidgets(
      'preserves existing post state and shows SnackBar when PATCH edit fails',
      (tester) async {
        final patchCalls =
            <({String method, String path, Map<String, dynamic> body})>[];
        final ctrl = PengajarController(
          PengajarRepository(
            createEditClient(patchCalls: patchCalls, failPatch: true),
          ),
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: PengajarDetailScreen(
                classData: const ClassItem(
                  title: 'Matematika XI',
                  grade: 'Kelas XI',
                  code: 'MAT202',
                  isGuru: true,
                ),
                controller: ctrl,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Failed Materi edit keeps original title
        final materiCard = find.ancestor(
          of: find.text('Materi Awal'),
          matching: find.byType(PostCard),
        );
        await tester.tap(
          find.descendant(
            of: materiCard,
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Materi Awal'),
          'Materi Gagal',
        );
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(
          find.text('Hanya guru yang dapat mengubah postingan'),
          findsOneWidget,
        );
        expect(find.text('Materi Awal'), findsOneWidget);
        expect(find.text('Materi Gagal'), findsNothing);

        // Switch to Tugas tab -> failed Tugas edit stays on form and keeps original item
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Tugas Awal'),
          'Tugas Gagal',
        );
        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(find.text('Gagal memperbarui postingan'), findsOneWidget);
        expect(find.widgetWithText(BackTitleRow, 'Edit Tugas'), findsOneWidget);

        // Cancel out -> list still shows original 'Tugas Awal'
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();
        expect(find.text('Tugas Awal'), findsOneWidget);
        expect(find.text('Tugas Gagal'), findsNothing);
      },
    );

    testWidgets('hides edit post actions on detail screens for non-guru', (
      tester,
    ) async {
      final patchCalls =
          <({String method, String path, Map<String, dynamic> body})>[];
      final ctrl = PengajarController(
        PengajarRepository(
          createEditClient(patchCalls: patchCalls, isGuru: false),
        ),
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PengajarDetailScreen(
              classData: const ClassItem(
                title: 'Matematika XI',
                grade: 'Kelas XI',
                code: 'MAT202',
                isGuru: false,
              ),
              controller: ctrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materi Awal'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit materi'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tugas Awal'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit tugas'), findsNothing);
      expect(patchCalls, isEmpty);
    });

    testWidgets(
      'edits and clears lampiran on materi via dialog and syncs detail view',
      (tester) async {
        final patchCalls =
            <({String method, String path, Map<String, dynamic> body})>[];
        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'modul_revisi.pdf',
            size: 12,
            readBytes: () async =>
                Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
          ),
        ];

        final ctrl = PengajarController(
          PengajarRepository(
            createEditClient(
              patchCalls: patchCalls,
              uploadedFileName: 'modul_revisi.pdf',
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

        // Open Edit dialog via card menu
        final materiCard = find.ancestor(
          of: find.text('Materi Awal'),
          matching: find.byType(PostCard),
        );
        await tester.tap(
          find.descendant(
            of: materiCard,
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        // Remove existing attachment, upload file, add link
        expect(find.text('https://example.com/materi-awal'), findsOneWidget);
        await tester.tap(find.byTooltip('Hapus lampiran').first);
        await tester.pumpAndSettle();
        expect(find.text('https://example.com/materi-awal'), findsNothing);

        await tester.ensureVisible(find.text('File'));
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();
        expect(find.text('modul_revisi.pdf'), findsOneWidget);

        await tester.ensureVisible(find.text('Link'));
        await tester.tap(find.text('Link'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'example.org/materi-baru',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tambah link'));
        await tester.pumpAndSettle();
        expect(find.text('https://example.org/materi-baru'), findsOneWidget);

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(1));
        expect(patchCalls.first.path, '/kelas/MAT202/postingan/10');
        expect(patchCalls.first.body['lampiran'], [
          uploadedPath,
          'https://example.org/materi-baru',
        ]);

        // Open Materi detail -> shows updated attachments and not the removed one
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Materi Awal'));
        await tester.pumpAndSettle();

        expect(find.text('https://example.com/materi-awal'), findsNothing);
        expect(find.text('modul_revisi.pdf'), findsOneWidget);
        expect(find.text('https://example.org/materi-baru'), findsOneWidget);

        // Edit from detail screen to clear ALL attachments -> sends empty array []
        await tester.tap(find.byTooltip('Edit materi'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Hapus lampiran').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Hapus lampiran').first);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(2));
        expect(patchCalls[1].body['lampiran'], <String>[]);
        expect(find.text('modul_revisi.pdf'), findsNothing);
        expect(find.text('https://example.org/materi-baru'), findsNothing);
      },
    );

    testWidgets(
      'edits and clears lampiran on tugas via form and syncs detail view',
      (tester) async {
        final patchCalls =
            <({String method, String path, Map<String, dynamic> body})>[];
        LampiranHelper.filePickerOverride = () async => [
          PickedLampiranFile(
            name: 'soal_revisi.pdf',
            size: 12,
            readBytes: () async =>
                Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
          ),
        ];

        final ctrl = PengajarController(
          PengajarRepository(
            createEditClient(
              patchCalls: patchCalls,
              uploadedFileName: 'soal_revisi.pdf',
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
        await tester.tap(find.text('Tugas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tugas Awal'));
        await tester.pumpAndSettle();
        expect(find.text('https://example.com/tugas-awal'), findsOneWidget);

        // Edit tugas via detail icon -> replace attachment with uploaded file + new link
        await tester.tap(find.byTooltip('Edit tugas'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byTooltip('Hapus lampiran').first);
        await tester.tap(find.byTooltip('Hapus lampiran').first);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('File'));
        await tester.tap(find.text('File'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Link'));
        await tester.tap(find.text('Link'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'example.org/tugas-baru',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tambah link'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(1));
        expect(patchCalls.first.path, '/kelas/MAT202/postingan/20');
        expect(patchCalls.first.body['lampiran'], [
          uploadedPath,
          'https://example.org/tugas-baru',
        ]);
        expect(find.text('https://example.com/tugas-awal'), findsNothing);
        expect(find.text('soal_revisi.pdf'), findsOneWidget);
        expect(find.text('https://example.org/tugas-baru'), findsOneWidget);

        // Edit again and clear all attachments -> sends []
        await tester.tap(find.byTooltip('Edit tugas'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byTooltip('Hapus lampiran').first);
        await tester.tap(find.byTooltip('Hapus lampiran').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Hapus lampiran').first);
        await tester.tap(find.byTooltip('Hapus lampiran').first);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan'));
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();

        expect(patchCalls, hasLength(2));
        expect(patchCalls[1].body['lampiran'], <String>[]);
        expect(find.text('soal_revisi.pdf'), findsNothing);
        expect(find.text('https://example.org/tugas-baru'), findsNothing);
      },
    );

    testWidgets(
      'submits Buat Materi form on Enter key action from title or description field',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'pengajar-detail'),
              builder: (_) => const Scaffold(
                body: PengajarDetailScreen(
                  classData: ClassItem(
                    title: 'Matematika XI',
                    grade: 'Kelas XI',
                    code: 'MAT202',
                    isGuru: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buat Materi'));
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Materi Enter Submit');
        await tester.enterText(fields.at(1), 'Deskripsi enter submit');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Materi Enter Submit'), findsOneWidget);
      },
    );
  });
}
