import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Kalender models', () {
    test('KalenderAkademikModel parses JSON, omits null dibuat, and formats toJson', () {
      final model = KalenderAkademikModel.fromJson({
        'id': 7,
        'nama_kegiatan': 'UTS Ganjil',
        'tanggal_mulai': '2026-11-20T00:00:00Z',
        'tanggal_selesai': '2026-11-25T00:00:00Z',
        'dibuat': '2026-11-01T08:00:00Z',
      });
      expect(model.id, 7);
      expect(model.namaKegiatan, 'UTS Ganjil');
      expect(model.tanggalMulai.year, 2026);
      expect(model.dibuat, isNotNull);
      expect(model.toJson()['dibuat'], isNotNull);

      final minimal = KalenderAkademikModel.fromJson({'id': 8});
      expect(minimal.namaKegiatan, '');
      expect(minimal.dibuat, isNull);
      expect(minimal.toJson().containsKey('dibuat'), isFalse);
    });
  });

  group('KalenderRepository', () {
    test('getKalenderAkademik parses list and handles error/timeout', () async {
      final okRepo = KalenderRepository(
        HttpClient(
          client: MockClient((request) async {
            expect(request.url.path, '/kalender');
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama_kegiatan': 'Libur Nasional',
                  'tanggal_mulai': '2026-11-17T00:00:00Z',
                  'tanggal_selesai': '2026-11-17T00:00:00Z',
                },
              ]),
              200,
            );
          }),
        ),
      );
      final (list, err) = await okRepo.getKalenderAkademik();
      expect(err, isNull);
      expect(list, hasLength(1));
      expect(list!.first.namaKegiatan, 'Libur Nasional');

      final errRepo = KalenderRepository(
        HttpClient(
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'message': 'Server error'}), 500),
          ),
        ),
      );
      expect((await errRepo.getKalenderAkademik()).$2, 'Server error');

      final timeoutRepo = KalenderRepository(
        HttpClient(client: MockClient((_) => throw TimeoutException('to'))),
      );
      expect(
        (await timeoutRepo.getKalenderAkademik()).$2,
        'Request timed out. Please try again.',
      );
    });

    test('getAgendas combines /kalender and /posts?tipe=1 across classes', () async {
      final capturedPaths = <String>[];
      final repo = KalenderRepository(
        HttpClient(
          client: MockClient((request) async {
            capturedPaths.add(request.url.toString());
            if (request.url.path == '/kalender') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama_kegiatan': 'Upacara',
                    'tanggal_mulai': '2026-11-18T00:00:00Z',
                    'tanggal_selesai': '2026-11-18T00:00:00Z',
                  },
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'Fisika X',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'FIS 10',
                    'dibuat': '2026-11-01T00:00:00Z',
                  },
                  {
                    'id': 2,
                    'nama': 'Kosong',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': '',
                    'dibuat': '2026-11-01T00:00:00Z',
                  },
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas/FIS%2010/posts' &&
                request.url.queryParameters['tipe'] == '1') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 20,
                    'judul': 'PR Kinematika',
                    'deskripsi': '',
                    'lampiran': [],
                    'pengguna_id': 1,
                    'kelas_id': 1,
                    'tipe_id': 1,
                    'dibuat': '2026-11-19T07:05:00',
                  },
                  {
                    'id': 21,
                    'judul': 'PR Dinamika',
                    'deskripsi': '',
                    'lampiran': [],
                    'pengguna_id': 1,
                    'kelas_id': 1,
                    'tipe_id': 1,
                    'dibuat': '2026-11-18T18:30:00Z',
                  },
                  {
                    'id': 22,
                    'judul': 'PR Fluida',
                    'deskripsi': '',
                    'lampiran': [],
                    'pengguna_id': 1,
                    'kelas_id': 1,
                    'tipe_id': 1,
                    'dibuat': '2026-11-19T09:15:00+07:00',
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        ),
      );

      final (agendas, err) = await repo.getAgendas();
      expect(err, isNull);
      expect(agendas, hasLength(4));
      expect(agendas![0].heading, 'Kalender Akademik');
      expect(agendas[0].title, 'Upacara');
      expect(agendas[0].time, 'Seharian');
      expect(agendas[1].heading, 'Tugas Fisika X');
      expect(agendas[1].title, 'PR Kinematika');
      expect(agendas[1].time, '07.05');
      expect(agendas[2].title, 'PR Dinamika');
      expect(agendas[2].date, DateTime(2026, 11, 19, 1, 30));
      expect(agendas[2].time, '01.30');
      expect(agendas[3].title, 'PR Fluida');
      expect(agendas[3].date, DateTime(2026, 11, 19, 9, 15));
      expect(agendas[3].time, '09.15');
      expect(capturedPaths.any((p) => p.contains('FIS%2010/posts?tipe=1')), isTrue);
    });

    test('getAgendas returns error only when both /kalender fails and agendas stay empty', () async {
      final failAllRepo = KalenderRepository(
        HttpClient(
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'message': 'Kalender gagal'}), 500),
          ),
        ),
      );
      final (agendas, err) = await failAllRepo.getAgendas();
      expect(agendas, isNull);
      expect(err, 'Kalender gagal');
    });

    test('uploadKalenderAkademik posts multipart CSV and returns null or error', () async {
      final okRepo = KalenderRepository(
        HttpClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/admin/kalender');
            return http.Response(jsonEncode({'message': 'OK'}), 201);
          }),
        ),
      );
      final csv = http.MultipartFile.fromBytes(
        'file',
        Uint8List.fromList('nama,mulai,selesai'.codeUnits),
        filename: 'kalender.csv',
      );
      expect(await okRepo.uploadKalenderAkademik(csv), isNull);

      final errRepo = KalenderRepository(
        HttpClient(
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'message': 'CSV tidak valid'}), 400),
          ),
        ),
      );
      expect(
        await errRepo.uploadKalenderAkademik(
          http.MultipartFile.fromBytes('file', [1], filename: 'bad.csv'),
        ),
        'CSV tidak valid',
      );
    });
  });

  group('KalenderController', () {
    test('loadAgendas and uploadKalenderAkademik manage loading, error, and refresh', () async {
      var uploadShouldFail = false;
      var kalenderCalls = 0;

      final repo = KalenderRepository(
        HttpClient(
          client: MockClient((request) async {
            if (request.url.path == '/kalender') {
              kalenderCalls++;
              return http.Response(
                jsonEncode([
                  {
                    'id': kalenderCalls,
                    'nama_kegiatan': 'Event $kalenderCalls',
                    'tanggal_mulai': '2026-11-17T00:00:00Z',
                    'tanggal_selesai': '2026-11-17T00:00:00Z',
                  },
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas') {
              return http.Response(jsonEncode([]), 200);
            }
            if (request.url.path == '/admin/kalender') {
              if (uploadShouldFail) {
                return http.Response(
                  jsonEncode({'message': 'Akses ditolak'}),
                  403,
                );
              }
              return http.Response(jsonEncode({'message': 'Uploaded'}), 201);
            }
            return http.Response('{}', 404);
          }),
        ),
      );
      final ctrl = KalenderController(repo);
      addTearDown(ctrl.dispose);

      await ctrl.loadAgendas();
      expect(ctrl.agendas, hasLength(1));
      expect(ctrl.agendas.first.title, 'Event 1');
      expect(ctrl.isLoading, isFalse);
      expect(ctrl.errorMessage, isNull);

      uploadShouldFail = true;
      final failErr = await ctrl.uploadKalenderAkademik(
        http.MultipartFile.fromBytes('file', [1], filename: 'k.csv'),
      );
      expect(failErr, 'Akses ditolak');
      expect(ctrl.errorMessage, 'Akses ditolak');
      expect(kalenderCalls, 1);

      uploadShouldFail = false;
      final okErr = await ctrl.uploadKalenderAkademik(
        http.MultipartFile.fromBytes('file', [1], filename: 'k.csv'),
      );
      expect(okErr, isNull);
      expect(kalenderCalls, 2);
      expect(ctrl.agendas.first.title, 'Event 2');
    });

    test('globalAgendasByDay indexes global ranges, marks API agendas as global, and ignores non-global tugas', () async {
      final repo = KalenderRepository(
        HttpClient(
          client: MockClient((request) async {
            if (request.url.path == '/kalender') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama_kegiatan': 'PTS Ganjil',
                    'keterangan': 'Ruang Ujian',
                    'tanggal_mulai': '2026-11-28',
                    'tanggal_selesai': '2026-12-02',
                  },
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {'id': 1, 'nama': 'Matematika', 'kode_kelas': 'MTK1'},
                ]),
                200,
              );
            }
            if (request.url.path == '/kelas/MTK1/posts') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 9,
                    'judul': 'PR Aljabar',
                    'dibuat': '2026-11-15T10:00:00Z',
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        ),
      );

      final ctrl = KalenderController(repo);
      addTearDown(ctrl.dispose);

      await ctrl.loadAgendas();
      expect(ctrl.agendas.where((a) => a.isGlobal), hasLength(1));
      expect(ctrl.agendas.where((a) => !a.isGlobal), hasLength(1));

      final map = ctrl.globalAgendasByDay;
      expect(map.containsKey(DateTime(2026, 11, 15)), isFalse);
      for (final d in [
        DateTime(2026, 11, 28),
        DateTime(2026, 11, 29),
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 2),
      ]) {
        expect(map[d]?.map((e) => e.title), ['PTS Ganjil']);
      }
      expect(map.containsKey(DateTime(2026, 12, 3)), isFalse);
    });
  });
}
