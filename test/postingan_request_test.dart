import 'dart:convert';

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
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Postingan repository requests', () {
    test(
      'getListPostingan sends no mapel parameter and handles optional tipe',
      () async {
        final capturedUris = <Uri>[];
        final isoNow = DateTime(2026, 11, 16, 12, 0).toIso8601String();
        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            capturedUris.add(request.url);
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'judul': 'Materi Aljabar',
                  'deskripsi': 'Catatan',
                  'lampiran': <String>[],
                  'pengguna_id': 99,
                  'kelas_id': 5,
                  'tipe_id': 2,
                  'dibuat': isoNow,
                },
              ]),
              200,
            );
          }),
        );

        final kelasRepo = KelasRepository(client);
        final pengajarRepo = PengajarRepository(client);

        final (materiList, materiErr) = await kelasRepo.getListPostingan(
          'MAT 10',
          tipe: PostinganModel.tipeMateri,
        );
        expect(materiErr, isNull);
        expect(materiList, hasLength(1));
        expect(materiList!.first.judul, 'Materi Aljabar');
        expect(materiList.first.penggunaId, 99);

        final (allList, allErr) = await pengajarRepo.getListPostingan('MAT202');
        expect(allErr, isNull);
        expect(allList, hasLength(1));

        expect(capturedUris, hasLength(2));
        expect(capturedUris[0].path, '/kelas/MAT%2010/posts');
        expect(capturedUris[0].queryParameters, {'tipe': '2'});
        expect(capturedUris[0].queryParameters.containsKey('mapel'), isFalse);

        expect(capturedUris[1].path, '/kelas/MAT202/posts');
        expect(capturedUris[1].queryParameters, isEmpty);
      },
    );
  });

  group('ClassDetailScreen postingan loading', () {
    testWidgets('shows error SnackBar when /posts returns 403', (tester) async {
      final client = HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/posts')) {
            return http.Response(
              jsonEncode({'message': 'Anda bukan anggota kelas ini'}),
              403,
            );
          }
          if (request.url.path.endsWith('/anggota')) {
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
          home: Scaffold(
            body: ClassDetailScreen(
              classData: const ClassItem(
                title: 'Fisika X',
                grade: 'Kelas X',
                code: 'FIS101',
              ),
              breadcrumb: const ['Kelas', 'Fisika X'],
              controller: ctrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anda bukan anggota kelas ini'), findsOneWidget);
    });
  });
}
