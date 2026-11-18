import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';
import 'package:path_mobile/utils/token_storage.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  tearDown(LampiranHelper.resetTestOverrides);

  group('HttpClient HTTP & 401 handling', () {
    test(
      'defaultBaseUrl uses localhost in debug mode and production URL in release mode',
      () {
        const hasOverride = bool.hasEnvironment('API_BASE_URL');
        if (hasOverride) {
          expect(
            HttpClient.defaultBaseUrl,
            const String.fromEnvironment('API_BASE_URL'),
          );
        } else if (kDebugMode) {
          expect(HttpClient.defaultBaseUrl, 'http://localhost:3000');
        } else {
          expect(HttpClient.defaultBaseUrl, 'https://api.pathclass.app');
        }

        final client = HttpClient(
          client: MockClient((_) async => http.Response('{}', 200)),
        );
        addTearDown(client.dispose);
        expect(client.baseUrl, HttpClient.defaultBaseUrl);
      },
    );

    test('builds uri against custom baseUrl and attaches Bearer token', () async {
      String? seenAuthHeader;
      Uri? seenUri;
      final storage = MemoryTokenStorage();
      final client = HttpClient(
        baseUrl: 'https://staging.example.com',
        token: 'my.jwt.token',
        tokenStorage: storage,
        client: MockClient((request) async {
          seenAuthHeader = request.headers['Authorization'];
          seenUri = request.url;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.dispose);

      expect(client.uri('/kelas').toString(), 'https://staging.example.com/kelas');
      await client.get(client.uri('/kelas'));

      expect(seenUri.toString(), 'https://staging.example.com/kelas');
      expect(seenAuthHeader, 'Bearer my.jwt.token');
    });

    test('clears token on 401 only when a Bearer token was sent', () async {
      final storage = MemoryTokenStorage('persisted.jwt');
      final authedClient = HttpClient(
        token: 'persisted.jwt',
        tokenStorage: storage,
        client: MockClient((_) async => http.Response('Unauthorized', 401)),
      );
      addTearDown(authedClient.dispose);

      await authedClient.get(authedClient.uri('/pengguna'));
      await authedClient.pendingPersistence;
      expect(authedClient.isAuthenticated, isFalse);
      expect(await storage.readToken(), isNull);

      final anonStorage = MemoryTokenStorage('should-stay');
      final anonClient = HttpClient(
        tokenStorage: anonStorage,
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('Unauthorized', 401);
        }),
      );
      addTearDown(anonClient.dispose);

      await anonClient.get(anonClient.uri('/login'));
      await anonClient.pendingPersistence;
      expect(await anonStorage.readToken(), 'should-stay');
    });
  });

  group('LampiranHelper & DTO utilities', () {
    test('extractLampiranExtension and isLampiranUploadPath handle edge cases', () {
      expect(extractLampiranExtension('/a/b/Modul.PDF'), 'pdf');
      expect(extractLampiranExtension('.gitignore'), '');
      expect(extractLampiranExtension('noext'), '');
      expect(extractLampiranExtension('trailing.'), '');

      expect(isLampiranUploadPath('/uploads/2026/11/a.pdf'), isTrue);
      expect(isLampiranUploadPath('uploads/2026/11/a.pdf'), isTrue);
      expect(
        isLampiranUploadPath('https://api.example.com/uploads/2026/11/a.pdf'),
        isTrue,
      );
      expect(
        isLampiranUploadPath('https://example.com/blog/uploads/note'),
        isFalse,
      );
    });

    test('LampiranItem, UploadedPostinganFile, parse, resolve, and merge helpers', () {
      const linkItem = LampiranItem(name: 'Link', detail: ' example.com ', isLink: true);
      expect(linkItem.targetUrl, 'example.com');
      expect(const LampiranItem(name: 'Stub', detail: 'PDF').targetUrl, isNull);

      final uploaded = UploadedPostinganFile.fromJson({
        'nama': 'tugas.pdf',
        'url': '/uploads/2026/11/17/abc.pdf',
        'ukuran': 512,
      });
      expect(uploaded.toJson(), {
        'nama': 'tugas.pdf',
        'path': '/uploads/2026/11/17/abc.pdf',
        'ukuran': 512,
      });

      final parsedResp = UploadPostinganFilesResponse.fromJson({
        'files': [uploaded.toJson()],
      });
      expect(parsedResp.files, hasLength(1));

      final items = parseLampiranItems([
        'https://example.com/docs',
        '/uploads/2026/11/17/abc.pdf',
      ]);
      expect(items[0].isLink, isTrue);
      expect(items[1].isLink, isFalse);
      expect(items[1].name, 'abc.pdf');

      expect(
        resolveLampiranItemPaths([
          const LampiranItem(name: 'Link', detail: 'example.com/a', isLink: true),
          const LampiranItem(
            name: 'tugas.pdf',
            detail: 'PDF',
            url: '/uploads/2026/11/17/abc.pdf',
          ),
          const LampiranItem(name: 'NoUrl', detail: 'PDF'),
        ]),
        ['https://example.com/a', '/uploads/2026/11/17/abc.pdf'],
      );

      final merged = mergeLampiranWithLocal(
        items,
        const [
          LampiranItem(
            name: 'modul_asli.pdf',
            detail: 'PDF',
            url: '/uploads/2026/11/17/abc.pdf',
          ),
        ],
      );
      expect(merged[0].targetUrl, 'https://example.com/docs');
      expect(merged[1].name, 'modul_asli.pdf');
    });

    test('openLampiranItem handles invalid URL, fallback launch mode, and failures', () async {
      expect(
        await openLampiranItem(const LampiranItem(name: 'Stub', detail: 'PDF')),
        'Link lampiran tidak valid',
      );

      final modes = <LaunchMode>[];
      LampiranHelper.urlLauncherOverride = (uri, {mode = LaunchMode.platformDefault}) async {
        modes.add(mode);
        if (mode == LaunchMode.externalApplication) {
          throw StateError('no external browser');
        }
        return true;
      };
      expect(
        await openLampiranItem(
          const LampiranItem(
            name: 'Link',
            detail: 'https://example.com',
            isLink: true,
          ),
        ),
        isNull,
      );
      expect(modes, [
        LaunchMode.externalApplication,
        LaunchMode.platformDefault,
      ]);

      LampiranHelper.urlLauncherOverride = (uri, {mode = LaunchMode.platformDefault}) async {
        return false;
      };
      expect(
        await openLampiranItem(
          const LampiranItem(
            name: 'Link',
            detail: 'https://example.com',
            isLink: true,
          ),
        ),
        'Tidak dapat membuka lampiran',
      );
    });
  });

  group('Formatting, Responsive, & ClassItem helpers', () {
    test('formatTanggal, formatJam, and formatBulanTahun format Indonesian dates', () {
      final dt = DateTime(2026, 2, 5, 7, 4);
      expect(formatTanggal(dt), '5 Februari 2026');
      expect(formatJam(dt), '07.04');
      expect(formatBulanTahun(dt), 'Februari 2026');

      final dec = DateTime(2026, 12, 31, 23, 59);
      expect(formatTanggal(dec), '31 Desember 2026');
      expect(formatJam(dec), '23.59');
      expect(formatBulanTahun(dec), 'Desember 2026');
    });

    test('responsive padding and grid helpers adapt across breakpoints', () {
      expect(responsiveHorizontalPadding(320), 12);
      expect(responsiveHorizontalPadding(400), 16);
      expect(responsiveHorizontalPadding(700), 24);
      expect(responsiveHorizontalPadding(1024), 32);

      expect(responsiveHorizontalInset(1200, maxWidth: 960), 120);
      expect(responsiveHorizontalInset(400, maxWidth: 960), 16);

      expect(
        responsiveListPadding(1200, maxWidth: 960, top: 8, bottom: 16),
        const EdgeInsets.fromLTRB(120, 8, 120, 16),
      );
      expect(alignedBackTitlePadding(12), EdgeInsets.zero);
      expect(
        alignedBackTitlePadding(40),
        const EdgeInsets.symmetric(horizontal: 24),
      );

      expect(classGridColumns(280), 1);
      expect(classGridColumns(350, textScale: 1.5), 1);
      expect(classGridColumns(400), 2);
      expect(classGridColumns(700), 3);
      expect(classGridColumns(900), 4);
      expect(classGridColumns(1200), 5);
    });

    test('ClassItem copyWith and inviteLink', () {
      const original = ClassItem(
        title: 'Biologi',
        description: 'Genetika',
        grade: 'Kelas X',
        code: 'BIO10',
        isGuru: false,
      );
      expect(original.inviteLink, 'https://path.app/join/BIO10');

      final updated = original.copyWith(title: 'Biologi XI', isGuru: true);
      expect(updated.title, 'Biologi XI');
      expect(updated.description, 'Genetika');
      expect(updated.code, 'BIO10');
      expect(updated.isGuru, isTrue);
    });
  });
}
