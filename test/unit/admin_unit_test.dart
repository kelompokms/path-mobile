import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/data/admin/admin_repository.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/token_storage.dart';

String _makeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'})));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.sig';
}

void main() {
  group('Admin JWT & HttpClient role detection', () {
    test('getJwtRole & isJwtAdmin detect role and legacy admin claim safely', () {
      expect(getJwtRole(_makeJwt({'user_id': 1, 'role': 'admin'})), 'admin');
      expect(getJwtRole(_makeJwt({'user_id': 2, 'role': ' Guru '})), 'guru');
      expect(getJwtRole(_makeJwt({'user_id': 3, 'role': 'MURID'})), 'murid');
      expect(getJwtRole(_makeJwt({'user_id': 4})), isNull);
      expect(getJwtRole('opaque.token'), isNull);

      expect(isJwtAdmin(_makeJwt({'user_id': 1, 'role': 'admin'})), isTrue);
      expect(isJwtAdmin(_makeJwt({'user_id': 1, 'role': ' ADMIN '})), isTrue);
      expect(isJwtAdmin(_makeJwt({'user_id': 2, 'role': 'guru'})), isFalse);
      expect(isJwtAdmin(_makeJwt({'user_id': 3, 'role': 'murid'})), isFalse);
      expect(isJwtAdmin(_makeJwt({'user_id': 1, 'admin': true})), isTrue);
      expect(isJwtAdmin(_makeJwt({'user_id': 2, 'admin': false})), isFalse);
      expect(isJwtAdmin(_makeJwt({'user_id': 3})), isFalse);
      expect(isJwtAdmin('opaque.token'), isFalse);
      expect(isJwtAdmin('not-a-jwt'), isFalse);
    });

    test('HttpClient derives role and isAdmin from JWT and resets override on logout', () async {
      final adminJwt = _makeJwt({
        'user_id': 1,
        'role': 'admin',
        'admin': true,
        'exp': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 2))
                .millisecondsSinceEpoch ~/
            1000,
      });
      final guruJwt = _makeJwt({'user_id': 2, 'role': 'guru'});
      final userJwt = _makeJwt({'user_id': 3, 'admin': false});

      final client = HttpClient(tokenStorage: MemoryTokenStorage(adminJwt));
      expect(client.isAdmin, isFalse);
      expect(client.role, isNull);

      await client.restoreToken();
      expect(client.isAuthenticated, isTrue);
      expect(client.isAdmin, isTrue);
      expect(client.role, 'admin');

      client.setToken(guruJwt);
      expect(client.isAdmin, isFalse);
      expect(client.role, 'guru');

      client.setToken(userJwt);
      expect(client.isAdmin, isFalse);
      expect(client.role, 'murid');

      var notified = 0;
      client.addListener(() => notified++);
      client.setAdmin(true);
      expect(client.isAdmin, isTrue);
      expect(client.role, 'admin');
      expect(notified, 1);

      client.setToken(null);
      expect(client.isAuthenticated, isFalse);
      expect(client.isAdmin, isFalse);
      expect(client.role, isNull);
    });
  });

  group('Admin models', () {
    test('AdminPenggunaModel & AdminGuruMuridData parse cleanly', () {
      final data = AdminGuruMuridData.fromJson({
        'guru': [
          {
            'id': 2,
            'nama': 'Eko Kusnandar',
            'email': 'eko@example.com',
            'phone': '08123',
            'profile_picture': '',
            'role': 'guru',
            'kelas': ['X PPLG 1', ''],
          },
        ],
        'murid': [
          {
            'id': 3,
            'nama': 'Aji Sasongko',
            'email': 'aji@example.com',
            'kelas': ['X PPLG 1'],
          },
        ],
      });

      expect(data.guru, hasLength(1));
      expect(data.guru.first.isGuru, isTrue);
      expect(data.guru.first.kelas, ['X PPLG 1']);
      expect(data.guru.first.toJson()['role'], 'guru');

      expect(data.murid, hasLength(1));
      expect(data.murid.first.isGuru, isFalse);
      expect(data.murid.first.role, 'murid');
    });

    test('AdminKelasModel parses JSON and maps to ClassItem', () {
      final kelas = AdminKelasModel.fromJson({
        'id': 10,
        'nama': 'X PPLG 1',
        'deskripsi': 'Pemrograman',
        'tingkat': 10,
        'tahun_ajaran': '2026/2027',
        'kode_kelas': 'PPLG10',
        'pengampu': 2,
        'nama_pengampu': 'Eko Kusnandar',
      });

      expect(kelas.gradeLabel, 'Kelas X');
      final card = kelas.toClassItem(coverIndex: 1);
      expect(card.title, 'X PPLG 1');
      expect(card.grade, 'Kelas X • 2026/2027');
      expect(card.teacher, 'Pengampu: Eko Kusnandar');
      expect(card.code, 'PPLG10');
      expect(kelas.toJson()['nama_pengampu'], 'Eko Kusnandar');

      expect(
        const AdminKelasModel(
          id: 1,
          nama: 'A',
          tingkat: 11,
          tahunAjaran: '2026/2027',
          kodeKelas: 'A1',
        ).gradeLabel,
        'Kelas XI',
      );
      expect(
        const AdminKelasModel(
          id: 2,
          nama: 'B',
          tingkat: 12,
          tahunAjaran: '2026/2027',
          kodeKelas: 'B2',
        ).gradeLabel,
        'Kelas XII',
      );
      expect(
        const AdminKelasModel(
          id: 3,
          nama: 'X DKV 1',
          tingkat: 10,
          tahunAjaran: '2026/2027',
          kodeKelas: 'DKV10',
        ).toClassItem().teacher,
        'Pengampu: Belum ditentukan',
      );
    });
  });

  group('AdminRepository & AdminController', () {
    test('getGuruDanMurid & getAllKelas support responses, query params, and errors', () async {
      final captured = <Uri>[];
      final repo = AdminRepository(
        HttpClient(
          client: MockClient((request) async {
            captured.add(request.url);
            if (request.url.path == '/admin/pengguna') {
              return http.Response(
                jsonEncode({
                  'guru': [
                    {
                      'id': 2,
                      'nama': 'Eko',
                      'email': 'eko@test.id',
                      'role': 'guru',
                      'kelas': ['Pemrograman Web'],
                    },
                  ],
                  'murid': [
                    {
                      'id': 3,
                      'nama': 'Aji',
                      'email': 'aji@test.id',
                      'role': 'murid',
                      'kelas': ['X PPLG 1'],
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/admin/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'X PPLG 1',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'P10',
                    'nama_pengampu': 'Eko',
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        ),
      );

      final (users, usersErr) = await repo.getGuruDanMurid();
      expect(usersErr, isNull);
      expect(users!.guru.first.nama, 'Eko');
      expect(users.murid.first.nama, 'Aji');

      final (kelas, kelasErr) = await repo.getAllKelas(
        tahunAjaran: '2026/2027',
        tingkat: 10,
        nama: 'PPLG',
      );
      expect(kelasErr, isNull);
      expect(kelas, hasLength(1));
      expect(captured.last.queryParameters['tahun_ajaran'], '2026/2027');
      expect(captured.last.queryParameters['tingkat'], '10');
      expect(captured.last.queryParameters['nama'], 'PPLG');

      final timeoutRepo = AdminRepository(
        HttpClient(client: MockClient((_) => throw TimeoutException('to'))),
      );
      expect(
        (await timeoutRepo.getGuruDanMurid()).$2,
        'Request timed out. Please try again.',
      );
      expect(
        (await timeoutRepo.getAllKelas()).$2,
        'Request timed out. Please try again.',
      );
    });

    test('AdminController filters users and kelas by year, tingkat, and nama', () async {
      final repo = AdminRepository(
        HttpClient(
          client: MockClient((request) async {
            if (request.url.path == '/admin/pengguna') {
              return http.Response(
                jsonEncode({
                  'guru': [
                    {
                      'id': 1,
                      'nama': 'Budi Santoso',
                      'email': 'budi@school.id',
                      'kelas': ['Matematika'],
                    },
                  ],
                  'murid': [
                    {
                      'id': 2,
                      'nama': 'Citra Lestari',
                      'email': 'citra@school.id',
                      'kelas': ['Biologi X'],
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/admin/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'X PPLG 1',
                    'tingkat': 10,
                    'tahun_ajaran': '2025/2026',
                    'kode_kelas': 'K1',
                  },
                  {
                    'id': 2,
                    'nama': 'XI RPL 2',
                    'tingkat': 11,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'K2',
                  },
                  {
                    'id': 3,
                    'nama': 'X PPLG 2',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'K3',
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        ),
      );

      final ctrl = AdminController(repo);
      addTearDown(ctrl.dispose);

      await ctrl.loadUsers();
      expect(ctrl.filteredUsers(ctrl.guruList, 'matematika'), hasLength(1));
      expect(ctrl.filteredUsers(ctrl.muridList, 'budi'), isEmpty);

      await ctrl.loadAllKelas();
      expect(ctrl.tahunAjaranOptions, ['2026/2027', '2025/2026']);
      expect(ctrl.tingkatOptions, [10, 11]);
      expect(ctrl.filteredKelas, hasLength(3));

      ctrl.setTahunAjaranFilter('2026/2027');
      expect(ctrl.filteredKelas.map((e) => e.kodeKelas), ['K2', 'K3']);

      ctrl.setTingkatFilter(10);
      expect(ctrl.filteredKelas.map((e) => e.kodeKelas), ['K3']);

      ctrl.setNamaKelasFilter('pplg');
      expect(ctrl.filteredKelas.map((e) => e.kodeKelas), ['K3']);
      expect(ctrl.hasActiveKelasFilters, isTrue);

      ctrl.resetKelasFilters();
      expect(ctrl.hasActiveKelasFilters, isFalse);
      expect(ctrl.filteredKelas, hasLength(3));
    });

    test('AdminRepository & AdminController support role switching, manual & CSV class creation, and pengampu updates', () async {
      final recordedRequests = <String>[];
      final usersGuru = <Map<String, dynamic>>[
        {
          'id': 2,
          'nama': 'Budi Santoso',
          'email': 'budi@school.id',
          'role': 'guru',
          'kelas': <String>[],
        },
      ];
      final usersMurid = <Map<String, dynamic>>[
        {
          'id': 5,
          'nama': 'Aji Sasongko',
          'email': 'aji@school.id',
          'role': 'murid',
          'kelas': <String>[],
        },
      ];
      final kelasRows = <Map<String, dynamic>>[];

      final repo = AdminRepository(
        HttpClient(
          client: MockClient((request) async {
            recordedRequests.add('${request.method} ${request.url.path}');
            final path = request.url.path;
            if (path == '/admin/pengguna' && request.method == 'GET') {
              return http.Response(
                jsonEncode({'guru': usersGuru, 'murid': usersMurid}),
                200,
              );
            }
            if (path == '/admin/pengguna/5/role' && request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['role'], 'guru');
              final moved = Map<String, dynamic>.from(usersMurid.removeAt(0));
              moved['role'] = 'guru';
              usersGuru.add(moved);
              return http.Response(
                jsonEncode({'message': 'Role diperbarui'}),
                200,
              );
            }
            if (path == '/admin/kelas' && request.method == 'GET') {
              return http.Response(jsonEncode(kelasRows), 200);
            }
            if (path == '/admin/kelas' && request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              kelasRows.add({
                'id': kelasRows.length + 1,
                'nama': body['nama'],
                'deskripsi': body['deskripsi'],
                'tingkat': body['tingkat'],
                'tahun_ajaran': body['tahun_ajaran'],
                'kode_kelas': 'CLS0${kelasRows.length + 1}',
                'pengampu': null,
                'nama_pengampu': '',
              });
              return http.Response(jsonEncode({'message': 'Dibuat'}), 201);
            }
            if (path == '/admin/kelas/csv' && request.method == 'POST') {
              final bodyText = utf8.decode(request.bodyBytes);
              expect(bodyText, contains('name="file_csv"'));
              expect(bodyText, contains('X RPL 2'));
              kelasRows.addAll([
                {
                  'id': kelasRows.length + 1,
                  'nama': 'X RPL 2',
                  'deskripsi': 'Praktikum',
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'RPL02',
                  'pengampu': null,
                  'nama_pengampu': '',
                },
                {
                  'id': kelasRows.length + 2,
                  'nama': 'XI RPL 2',
                  'deskripsi': '',
                  'tingkat': 11,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'RPL12',
                  'pengampu': null,
                  'nama_pengampu': '',
                },
              ]);
              return http.Response(
                jsonEncode({'message': '2 kelas berhasil dibuat dari CSV'}),
                201,
              );
            }
            if (path == '/admin/kelas/CLS01/pengampu' &&
                request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final pid = body['pengampu_id'] as int?;
              final idx = kelasRows.indexWhere(
                (k) => k['kode_kelas'] == 'CLS01',
              );
              kelasRows[idx]['pengampu'] = pid;
              kelasRows[idx]['nama_pengampu'] = pid == 2 ? 'Budi Santoso' : '';
              return http.Response(jsonEncode(kelasRows[idx]), 200);
            }
            return http.Response(jsonEncode({'message': 'Gagal'}), 400);
          }),
        ),
      );

      final ctrl = AdminController(repo);
      addTearDown(ctrl.dispose);

      await ctrl.loadUsers();
      expect(ctrl.guruList, hasLength(1));
      expect(ctrl.muridList, hasLength(1));

      // Create class manually (pengampu defaults null)
      final createErr = await ctrl.createKelas(
        nama: 'XI DKV 1',
        deskripsi: 'Desain Grafis',
        gradeInput: 'Kelas XI',
        tahunAjaran: '2026/2027',
      );
      expect(createErr, isNull);
      expect(ctrl.allKelas, hasLength(1));
      expect(ctrl.allKelas.first.tingkat, 11);
      expect(ctrl.allKelas.first.pengampu, 0);
      expect(ctrl.allKelas.first.namaPengampu, isEmpty);

      // Promote murid to guru globally
      final roleErr = await ctrl.updateUserRole(5, 'guru');
      expect(roleErr, isNull);
      expect(ctrl.guruList.map((u) => u.id), [2, 5]);
      expect(ctrl.muridList, isEmpty);

      // Bulk create classes from CSV
      final csvFile = http.MultipartFile.fromString(
        'file_csv',
        'nama,tingkat,tahun_ajaran,deskripsi\nX RPL 2,10,2026/2027,Praktikum\nXI RPL 2,11,2026/2027,\n',
        filename: 'kelas.csv',
      );
      final (csvMsg, csvErr) = await ctrl.uploadKelasCsv(csvFile);
      expect(csvErr, isNull);
      expect(csvMsg, '2 kelas berhasil dibuat dari CSV');
      expect(ctrl.allKelas, hasLength(3));

      // Assign pengampu from guru list then clear pengampu to null
      final assignErr = await ctrl.updatePengampuKelas('CLS01', 2);
      expect(assignErr, isNull);
      expect(ctrl.allKelas.first.pengampu, 2);
      expect(ctrl.allKelas.first.namaPengampu, 'Budi Santoso');

      final clearErr = await ctrl.updatePengampuKelas('CLS01', null);
      expect(clearErr, isNull);
      expect(ctrl.allKelas.first.namaPengampu, isEmpty);
      expect(
        recordedRequests,
        containsAll([
          'POST /admin/kelas',
          'PATCH /admin/pengguna/5/role',
          'POST /admin/kelas/csv',
          'PATCH /admin/kelas/CLS01/pengampu',
        ]),
      );

      // Verify repository error propagation
      final errRepo = AdminRepository(
        HttpClient(
          client: MockClient(
            (_) async => http.Response(jsonEncode({'message': 'Ditolak'}), 403),
          ),
        ),
      );
      expect(await errRepo.updateUserRole(1, 'guru'), 'Ditolak');
      expect(
        await errRepo.createKelas(nama: 'A', tingkat: 10, tahunAjaran: '2026/2027'),
        'Ditolak',
      );
      expect(
        (await errRepo.uploadKelasCsv(
          http.MultipartFile.fromString('file_csv', 'nama,tingkat,tahun_ajaran\n'),
        )).$2,
        'Ditolak',
      );
      expect(await errRepo.updatePengampuKelas('CLS01', 2), 'Ditolak');
    });
  });

  group('Kalender keterangan & createAgenda', () {
    test('KalenderAkademikModel & CreateAgendaPayload include keterangan', () {
      final model = KalenderAkademikModel.fromJson({
        'id': 1,
        'nama_kegiatan': 'Workshop Kurikulum',
        'keterangan': 'Di aula utama',
        'tanggal_mulai': '2026-11-20',
        'tanggal_selesai': '2026-11-21',
      });
      expect(model.keterangan, 'Di aula utama');
      expect(model.toJson()['keterangan'], 'Di aula utama');

      const payload = CreateAgendaPayload(
        namaKegiatan: 'Rapat Guru',
        keterangan: 'Membahas evaluasi UTS',
        tanggalMulai: '2026-11-22',
      );
      expect(payload.toJson(), {
        'nama_kegiatan': 'Rapat Guru',
        'keterangan': 'Membahas evaluasi UTS',
        'tanggal_mulai': '2026-11-22',
        'tanggal_selesai': '2026-11-22',
      });
    });

    test('KalenderController.createAgenda posts to /admin/kalender/agenda and reloads agendas', () async {
      final stored = <Map<String, dynamic>>[];

      final repo = KalenderRepository(
        HttpClient(
          client: MockClient((request) async {
            if (request.url.path == '/admin/kalender/agenda' &&
                request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final created = {
                'id': 10,
                'nama_kegiatan': body['nama_kegiatan'],
                'keterangan': body['keterangan'] ?? '',
                'tanggal_mulai': body['tanggal_mulai'],
                'tanggal_selesai': body['tanggal_selesai'],
              };
              stored.add(created);
              return http.Response(jsonEncode(created), 201);
            }
            if (request.url.path == '/kalender') {
              return http.Response(jsonEncode(stored), 200);
            }
            if (request.url.path == '/kelas') {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response('{}', 404);
          }),
        ),
      );

      final ctrl = KalenderController(repo);
      addTearDown(ctrl.dispose);

      final err = await ctrl.createAgenda(
        namaEvent: 'Class Meeting',
        keterangan: 'Lomba antar kelas di lapangan',
        tanggalMulai: DateTime(2026, 11, 20),
        tanggalSelesai: DateTime(2026, 11, 22),
      );
      expect(err, isNull);
      expect(ctrl.agendas, hasLength(1));
      expect(ctrl.agendas.first.title, 'Class Meeting');
      expect(ctrl.agendas.first.description, 'Lomba antar kelas di lapangan');
      expect(ctrl.agendas.first.time, '20/11 - 22/11');
    });
  });
}
