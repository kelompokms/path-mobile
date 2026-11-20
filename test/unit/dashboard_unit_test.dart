import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/dashboard/dashboard_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Dashboard models', () {
    test('GuruSubmissionSummary.completionRate computes and clamps safely', () {
      const item = ClassItem(title: 'Matematika', grade: 'Kelas X', code: 'MTK');
      final post = PostinganModel(
        id: 1,
        judul: 'Tugas 1',
        deskripsi: '',
        lampiran: const [],
        penggunaId: 1,
        kelasId: 1,
        tipeId: 1,
        dibuat: DateTime(2026, 11, 20),
      );

      final noStudents = GuruSubmissionSummary(
        classItem: item,
        post: post,
        submissionCount: 2,
        totalStudents: 0,
      );
      expect(noStudents.completionRate, isNull);

      final half = GuruSubmissionSummary(
        classItem: item,
        post: post,
        submissionCount: 2,
        totalStudents: 4,
      );
      expect(half.completionRate, 0.5);

      final overflow = GuruSubmissionSummary(
        classItem: item,
        post: post,
        submissionCount: 6,
        totalStudents: 4,
      );
      expect(overflow.completionRate, 1.0);
    });

    test('GuruClassProgress.completionRate handles zero expected and clamps', () {
      const item = ClassItem(title: 'Fisika', grade: 'Kelas XI', code: 'FIS');
      const empty = GuruClassProgress(
        classItem: item,
        studentCount: 0,
        taskCount: 0,
        submissionCount: 0,
        expectedSubmissions: 0,
      );
      expect(empty.completionRate, isNull);

      const partial = GuruClassProgress(
        classItem: item,
        studentCount: 4,
        taskCount: 2,
        submissionCount: 3,
        expectedSubmissions: 4,
      );
      expect(partial.completionRate, 0.75);
    });
  });

  group('DashboardController (Guru mode)', () {
    test('aggregates unique students, 7-day buckets, participation, submissions, and upcoming agendas', () async {
      final fixedNow = DateTime(2026, 11, 20, 10, 0);

      final client = HttpClient(
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/kelas') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama': 'Matematika X',
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'MTK10',
                  'dibuat': '2026-11-01T00:00:00Z',
                  'guru': true,
                },
                {
                  'id': 2,
                  'nama': 'Fisika X',
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'FIS10',
                  'dibuat': '2026-11-01T00:00:00Z',
                  'guru': true,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/MTK10/anggota') {
            return http.Response(
              jsonEncode([
                {'pengguna_id': 1, 'nama': 'Pak Guru', 'guru': true},
                {'pengguna_id': 10, 'nama': 'Ani', 'guru': false},
                {'pengguna_id': 11, 'nama': 'Budi', 'guru': false},
              ]),
              200,
            );
          }
          if (path == '/kelas/FIS10/anggota') {
            return http.Response(
              jsonEncode([
                {'pengguna_id': 1, 'nama': 'Pak Guru', 'guru': true},
                // Shared student ID 10 should not be double-counted in totalGuruStudents
                {'pengguna_id': 10, 'nama': 'Ani', 'guru': false},
                {'pengguna_id': 12, 'nama': 'Citra', 'guru': false},
                {'pengguna_id': 0, 'nama': 'Anonim', 'guru': false},
              ]),
              200,
            );
          }
          if (path == '/kelas/MTK10/posts') {
            return http.Response(
              jsonEncode([
                {
                  'id': 101,
                  'judul': 'Tugas Aljabar',
                  'deskripsi': '',
                  'lampiran': [],
                  'pengguna_id': 1,
                  'kelas_id': 1,
                  'tipe_id': 1,
                  'dibuat': '2026-11-19T08:00:00',
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/FIS10/posts') {
            return http.Response(
              jsonEncode([
                {
                  'id': 201,
                  'judul': 'Tugas Gerak',
                  'deskripsi': '',
                  'lampiran': [],
                  'pengguna_id': 1,
                  'kelas_id': 2,
                  'tipe_id': 1,
                  'dibuat': '2026-11-18T08:00:00',
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/MTK10/postingan/101/pengumpulan') {
            return http.Response(
              jsonEncode([
                {
                  'pengguna_id': 10,
                  'nama': 'Ani',
                  'lampiran': ['jawaban_ani.pdf'],
                  'dibuat': '2026-11-20T09:00:00',
                },
                {
                  'pengguna_id': 11,
                  'nama': 'Budi',
                  'lampiran': [],
                  'dibuat': '2026-11-18T11:00:00',
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/FIS10/postingan/201/pengumpulan') {
            return http.Response(
              jsonEncode([
                {
                  'pengguna_id': 12,
                  'nama': 'Citra',
                  'lampiran': ['fisika.pdf'],
                  // 10 days old -> excluded from 7-day buckets, still counted in totals
                  'dibuat': '2026-11-10T09:00:00',
                },
              ]),
              200,
            );
          }
          if (path == '/kalender') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama_kegiatan': 'Agenda Lampau',
                  'tanggal_mulai': '2026-11-15',
                  'tanggal_selesai': '2026-11-19',
                },
                {
                  'id': 2,
                  'nama_kegiatan': 'UAS Akhir',
                  'tanggal_mulai': '2026-12-01',
                  'tanggal_selesai': '2026-12-05',
                },
                {
                  'id': 3,
                  'nama_kegiatan': 'Lomba Berlangsung',
                  'tanggal_mulai': '2026-11-19',
                  'tanggal_selesai': '2026-11-21',
                },
                {
                  'id': 4,
                  'nama_kegiatan': 'Rapat Guru',
                  'tanggal_mulai': '2026-11-22',
                  'tanggal_selesai': '2026-11-22',
                },
                {
                  'id': 5,
                  'nama_kegiatan': 'Libur Semester',
                  'tanggal_mulai': '2026-12-15',
                  'tanggal_selesai': '2026-12-20',
                },
              ]),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final kelasCtrl = KelasController(KelasRepository(client));
      final pengajarCtrl = PengajarController(PengajarRepository(client));
      final kalenderRepo = KalenderRepository(client);
      final ctrl = DashboardController(
        isGuruRole: true,
        kelasController: kelasCtrl,
        pengajarController: pengajarCtrl,
        kalenderRepository: kalenderRepo,
        nowProvider: () => fixedNow,
      );
      addTearDown(kelasCtrl.dispose);
      addTearDown(pengajarCtrl.dispose);
      addTearDown(ctrl.dispose);

      await ctrl.refreshSummary();

      expect(ctrl.isLoadingSummary, isFalse);
      expect(ctrl.hasKalender, isTrue);
      expect(ctrl.teachingItems, hasLength(2));
      // Unique student IDs {10, 11, 12} + 1 anonymous = 4
      expect(ctrl.totalGuruStudents, 4);
      // MTK10: 2/2, FIS10: 1/3 -> total 3/5, missing 2
      expect(ctrl.totalGuruSubmissions, 3);
      expect(ctrl.totalGuruExpected, 5);
      expect(ctrl.totalGuruMissing, 2);
      expect(ctrl.overallSubmissionRate, closeTo(0.6, 0.0001));
      // Composition: 2 with attachments (Ani, Citra), 1 mark-as-done (Budi)
      expect(ctrl.withAttachmentCount, 2);
      expect(ctrl.markAsDoneCount, 1);
      // 7-day buckets: 1 today (Nov 20), 1 two days ago (Nov 18), Nov 10 excluded
      expect(ctrl.recent7DaysSubmissions, 2);
      expect(ctrl.todaySubmissions, 1);
      expect(ctrl.dailySubmissions, hasLength(7));
      expect(ctrl.dailySubmissions.last.isToday, isTrue);
      expect(ctrl.dailySubmissions.last.count, 1);
      expect(ctrl.dailySubmissions[4].count, 1);

      // Lowest completion rate sorted first: FIS10 (1/3) before MTK10 (2/2)
      expect(ctrl.classProgressList, hasLength(2));
      expect(ctrl.classProgressList.first.classItem.code, 'FIS10');
      expect(ctrl.classProgressList.last.classItem.code, 'MTK10');

      expect(ctrl.guruSubmissions, hasLength(2));
      expect(ctrl.guruSubmissions.first.post.judul, 'Tugas Gerak');
      expect(ctrl.guruSubmissions.first.latestStudentName, 'Citra');
      expect(ctrl.guruSubmissions.last.post.judul, 'Tugas Aljabar');
      expect(ctrl.guruSubmissions.last.latestStudentName, 'Ani');

      // Upcoming agendas: excludes ended, sorted by tanggalMulai, capped at 3
      expect(ctrl.upcomingAgendas.map((a) => a.namaKegiatan).toList(), [
        'Lomba Berlangsung',
        'Rapat Guru',
        'UAS Akhir',
      ]);
    });
  });

  group('DashboardController (Murid mode)', () {
    test('aggregates tasks with nilai, sorts unsubmitted first, and detects assistant role', () async {
      final client = HttpClient(
        client: MockClient((request) async {
          final path = request.url.path;
          final guruQuery = request.url.queryParameters['guru'];
          if (path == '/kelas') {
            if (guruQuery == 'true') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 9,
                    'nama': 'Praktikum Kimia',
                    'tingkat': 11,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'KIM11',
                    'dibuat': '2026-11-01T00:00:00Z',
                    'guru': true,
                  },
                ]),
                200,
              );
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 3,
                  'nama': 'Biologi X',
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'BIO10',
                  'dibuat': '2026-11-01T00:00:00Z',
                  'guru': false,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/BIO10/posts') {
            return http.Response(
              jsonEncode([
                {
                  'id': 301,
                  'judul': 'Tugas Sel',
                  'deskripsi': '',
                  'lampiran': [],
                  'pengguna_id': 1,
                  'kelas_id': 3,
                  'tipe_id': 1,
                  'dibuat': '2026-11-19T08:00:00',
                },
                {
                  'id': 302,
                  'judul': 'Tugas Genetika',
                  'deskripsi': '',
                  'lampiran': [],
                  'pengguna_id': 1,
                  'kelas_id': 3,
                  'tipe_id': 1,
                  'dibuat': '2026-11-18T08:00:00',
                },
              ]),
              200,
            );
          }
          if (path == '/kelas/BIO10/postingan/301/pengumpulan/saya') {
            return http.Response(
              jsonEncode({
                'submitted': true,
                'nilai': 95,
                'lampiran': ['sel.pdf'],
              }),
              200,
            );
          }
          if (path == '/kelas/BIO10/postingan/302/pengumpulan/saya') {
            return http.Response(
              jsonEncode({'submitted': false, 'lampiran': []}),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final kelasCtrl = KelasController(KelasRepository(client));
      final pengajarCtrl = PengajarController(PengajarRepository(client));
      final ctrl = DashboardController(
        isGuruRole: false,
        kelasController: kelasCtrl,
        pengajarController: pengajarCtrl,
      );
      addTearDown(kelasCtrl.dispose);
      addTearDown(pengajarCtrl.dispose);
      addTearDown(ctrl.dispose);

      await ctrl.refreshSummary();

      expect(ctrl.enrolledItems, hasLength(1));
      expect(ctrl.enrolledItems.first.code, 'BIO10');
      expect(ctrl.isAssistant, isTrue);
      expect(ctrl.assistantItems, hasLength(1));
      expect(ctrl.assistantItems.first.code, 'KIM11');
      expect(ctrl.totalMuridTugas, 2);
      expect(ctrl.pendingMuridTugas, 1);
      expect(ctrl.muridTasks, hasLength(2));
      // Unsubmitted sorted before submitted even when older
      expect(ctrl.muridTasks.first.post.judul, 'Tugas Genetika');
      expect(ctrl.muridTasks.first.submitted, isFalse);
      expect(ctrl.muridTasks.first.nilai, isNull);
      expect(ctrl.muridTasks.last.post.judul, 'Tugas Sel');
      expect(ctrl.muridTasks.last.submitted, isTrue);
      expect(ctrl.muridTasks.last.nilai, 95);
    });
  });

  group('DashboardController lifecycle & resilience', () {
    test('ignores stale refresh responses and survives partial API failures', () async {
      var kalenderCall = 0;
      final firstCompleter = Completer<http.Response>();

      final client = HttpClient(
        client: MockClient((request) async {
          if (request.url.path == '/kalender') {
            kalenderCall++;
            if (kalenderCall == 1) {
              return firstCompleter.future;
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 2,
                  'nama_kegiatan': 'Agenda Terbaru',
                  'tanggal_mulai': '2026-11-25',
                  'tanggal_selesai': '2026-11-25',
                },
              ]),
              200,
            );
          }
          return http.Response(jsonEncode({'message': 'Error'}), 500);
        }),
      );

      final ctrl = DashboardController(
        isGuruRole: false,
        kelasController: KelasController(KelasRepository(client)),
        kalenderRepository: KalenderRepository(client),
        nowProvider: () => DateTime(2026, 11, 20),
      );
      addTearDown(ctrl.kelasController!.dispose);
      addTearDown(ctrl.dispose);

      final first = ctrl.refreshSummary();
      final second = ctrl.refreshSummary();
      await second;

      expect(ctrl.upcomingAgendas, hasLength(1));
      expect(ctrl.upcomingAgendas.first.namaKegiatan, 'Agenda Terbaru');

      // Complete first stale request with older data -> must be ignored
      firstCompleter.complete(
        http.Response(
          jsonEncode([
            {
              'id': 1,
              'nama_kegiatan': 'Agenda Basi',
              'tanggal_mulai': '2026-11-21',
              'tanggal_selesai': '2026-11-21',
            },
          ]),
          200,
        ),
      );
      await first;

      expect(ctrl.upcomingAgendas.first.namaKegiatan, 'Agenda Terbaru');
      expect(ctrl.isLoadingSummary, isFalse);
    });

    test('forwards dependency notifications and stops cleanly after dispose', () async {
      final pending = Completer<http.Response>();
      final client = HttpClient(
        client: MockClient((request) async {
          if (request.url.path == '/kalender') {
            return pending.future;
          }
          return http.Response(jsonEncode([]), 200);
        }),
      );

      final kelasCtrl = KelasController(KelasRepository(client));
      final kalenderRepo = KalenderRepository(client);
      final ctrl = DashboardController(
        kelasController: kelasCtrl,
        kalenderRepository: kalenderRepo,
      );
      addTearDown(kelasCtrl.dispose);

      var notifications = 0;
      ctrl.addListener(() => notifications++);

      // Direct call on kelasCtrl should forward notification to DashboardController
      await kelasCtrl.getListKelas();
      expect(notifications, greaterThan(0));

      // Start an in-flight refresh, then dispose before it finishes
      final inFlight = ctrl.refreshSummary();
      final countBeforeDispose = notifications;
      ctrl.dispose();

      pending.complete(
        http.Response(
          jsonEncode([
            {
              'id': 1,
              'nama_kegiatan': 'Setelah Dispose',
              'tanggal_mulai': '2026-11-25',
              'tanggal_selesai': '2026-11-25',
            },
          ]),
          200,
        ),
      );
      await inFlight;
      await kelasCtrl.getListKelas();

      expect(notifications, countBeforeDispose);
    });
  });
}
