import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/ui/kalender/kalender_screen.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('KalenderScreen swipeable month calendar', () {
    HttpClient createKalenderClient(DateTime now) {
      final thisMonth = DateTime(now.year, now.month, 10, 9, 0);
      final nextMonth = DateTime(now.year, now.month + 1, 15, 9, 0);
      final prevMonth = DateTime(now.year, now.month - 1, 5, 9, 0);

      final kalenderJson = [
        {
          'id': 1,
          'nama_kegiatan': 'Agenda Bulan Ini',
          'tanggal_mulai': thisMonth.toIso8601String(),
          'tanggal_selesai': thisMonth.toIso8601String(),
        },
        {
          'id': 2,
          'nama_kegiatan': 'Agenda Bulan Depan',
          'tanggal_mulai': nextMonth.toIso8601String(),
          'tanggal_selesai': nextMonth.toIso8601String(),
        },
        {
          'id': 3,
          'nama_kegiatan': 'Agenda Bulan Lalu',
          'tanggal_mulai': prevMonth.toIso8601String(),
          'tanggal_selesai': prevMonth.toIso8601String(),
        },
      ];

      return HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          if (request.url.path == '/kalender') {
            return http.Response(jsonEncode(kalenderJson), 200);
          }
          if (request.url.path == '/kelas') {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
    }

    Future<void> swipeCalendar(
      WidgetTester tester, {
      required Offset offset,
    }) async {
      await tester.drag(find.byType(PageView), offset);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'swipes left and right across months on 1-pane mobile and stays synced with arrows',
      (tester) async {
        final now = DateTime.now();
        final currentMonth = DateTime(now.year, now.month);
        final nextMonth = DateTime(now.year, now.month + 1);
        final prevMonth = DateTime(now.year, now.month - 1);

        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final ctrl = KalenderController(
          KalenderRepository(createKalenderClient(now)),
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: KalenderScreen(controller: ctrl)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(formatBulanTahun(currentMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Ini'), findsOneWidget);
        expect(find.text('Agenda Bulan Depan'), findsNothing);

        // Swipe left -> next month
        await swipeCalendar(tester, offset: const Offset(-350, 0));
        expect(find.text(formatBulanTahun(nextMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Depan'), findsOneWidget);
        expect(find.text('Agenda Bulan Ini'), findsNothing);

        // Swipe right -> back to current month, then previous month
        await swipeCalendar(tester, offset: const Offset(350, 0));
        expect(find.text(formatBulanTahun(currentMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Ini'), findsOneWidget);

        await swipeCalendar(tester, offset: const Offset(350, 0));
        expect(find.text(formatBulanTahun(prevMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Lalu'), findsOneWidget);

        // Arrow button also stays in sync with PageView
        await tester.tap(find.byTooltip('Bulan berikutnya'));
        await tester.pumpAndSettle();
        expect(find.text(formatBulanTahun(currentMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Ini'), findsOneWidget);
      },
    );

    testWidgets(
      'swipes across months on 2-pane layout and preserves month when resizing',
      (tester) async {
        final now = DateTime.now();
        final nextMonth = DateTime(now.year, now.month + 1);

        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final ctrl = KalenderController(
          KalenderRepository(createKalenderClient(now)),
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: KalenderScreen(controller: ctrl)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsOneWidget);

        await swipeCalendar(tester, offset: const Offset(-350, 0));
        expect(find.text(formatBulanTahun(nextMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Depan'), findsOneWidget);

        // Resize below 720 -> preserves viewed nextMonth
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.text(formatBulanTahun(nextMonth)), findsOneWidget);
        expect(find.text('Agenda Bulan Depan'), findsOneWidget);
      },
    );
  });
}
