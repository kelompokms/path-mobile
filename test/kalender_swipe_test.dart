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
    String dayKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    testWidgets(
      'highlights single-day & multi-day global agendas on the calendar, ignores non-global tugas, and opens detail on tap',
      (tester) async {
        final now = DateTime.now();
        final today = DateUtils.dateOnly(now);
        final singleDay = DateTime(
          now.year,
          now.month,
          today.day == 10 ? 11 : 10,
        );
        final rangeStart = DateTime(now.year, now.month, 18);
        final rangeMid = DateTime(now.year, now.month, 19);
        final rangeEnd = DateTime(now.year, now.month, 20);
        final tugasDay = DateTime(now.year, now.month, today.day == 24 ? 25 : 24);
        final nextMonthStart = DateTime(now.year, now.month + 1, 5);
        final nextMonthEnd = DateTime(now.year, now.month + 1, 6);

        final client = HttpClient(
          token: 'jwt.token',
          client: MockClient((request) async {
            if (request.url.path == '/kalender') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama_kegiatan': 'Rapat Orang Tua',
                    'keterangan': 'Hadir di aula pukul 09.00',
                    'tanggal_mulai': singleDay.toIso8601String(),
                    'tanggal_selesai': singleDay.toIso8601String(),
                  },
                  {
                    'id': 2,
                    'nama_kegiatan': 'Class Meeting',
                    'keterangan': 'Lomba antar kelas',
                    'tanggal_mulai': rangeStart.toIso8601String(),
                    'tanggal_selesai': rangeEnd.toIso8601String(),
                  },
                  {
                    'id': 3,
                    'nama_kegiatan': 'Ujian Praktik',
                    'keterangan': 'Lab Komputer',
                    'tanggal_mulai': nextMonthStart.toIso8601String(),
                    'tanggal_selesai': nextMonthEnd.toIso8601String(),
                  },
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {'id': 1, 'nama': 'Fisika X', 'kode_kelas': 'FIS10'},
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas/FIS10/posts') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 9,
                    'judul': 'Tugas Kinematika',
                    'dibuat': tugasDay.toIso8601String(),
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        );

        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final ctrl = KalenderController(KalenderRepository(client));
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: Scaffold(body: KalenderScreen(controller: ctrl)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Legend visible
        expect(find.text('Agenda global'), findsOneWidget);

        // Single-day and multi-day global agendas are highlighted on calendar
        expect(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(singleDay)}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(rangeStart)}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(rangeMid)}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(rangeEnd)}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('calendar_global_agenda_dot_${dayKey(rangeMid)}')),
          findsOneWidget,
        );

        // Regular assignment day is NOT highlighted as global agenda
        expect(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(tugasDay)}')),
          findsNothing,
        );

        // Visual decoration on highlighted day has amber highlight styling
        final highlightedBox = tester.widget<DecoratedBox>(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(singleDay)}')),
        );
        final dec = highlightedBox.decoration as BoxDecoration;
        expect(dec.color, isNotNull);
        expect(dec.shape, BoxShape.circle);

        // Non-admin user can tap highlighted day to view its agenda details
        await tester.tap(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(singleDay)}')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Hadir di aula pukul 09.00'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        // Swiping to next month highlights nextMonth global agenda dates
        await swipeCalendar(tester, offset: const Offset(-300, 0));
        expect(
          find.byKey(
            ValueKey('calendar_global_agenda_${dayKey(nextMonthStart)}'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey('calendar_global_agenda_${dayKey(nextMonthEnd)}'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('calendar_global_agenda_${dayKey(singleDay)}')),
          findsNothing,
        );
      },
    );
  });
}
