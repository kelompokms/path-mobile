import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Kelas & Pengajar models', () {
    test('KelasModel parses pengampu/pembuat fallback, gradeLabel, and toClassItem', () {
      final x = KelasModel.fromJson({
        'id': 1,
        'nama': 'Biologi X',
        'deskripsi': 'Dasar sel',
        'tingkat': 10,
        'tahun_ajaran': '2026/2027',
        'kode_kelas': 'BIO10',
        'pembuat': 7,
        'dibuat': '2026-11-01T00:00:00Z',
        'guru': false,
      });
      expect(x.pengampu, 7);
      expect(x.pembuat, 7);
      expect(x.gradeLabel, 'Kelas X');
      final item = x.toClassItem(teacher: 'Pak Budi', coverIndex: 3);
      expect(item.title, 'Biologi X');
      expect(item.grade, 'Kelas X');
      expect(item.teacher, 'Pak Budi');
      expect(item.coverIndex, 3);
      expect(item.code, 'BIO10');
      expect(item.isGuru, isFalse);
      expect(x.toJson()['kode_kelas'], 'BIO10');

      final xi = KelasModel.fromJson({'tingkat': 11});
      final xii = KelasModel.fromJson({'tingkat': 12});
      final custom = KelasModel.fromJson({'tingkat': 9});
      expect(xi.gradeLabel, 'Kelas XI');
      expect(xii.gradeLabel, 'Kelas XII');
      expect(custom.gradeLabel, 'Kelas 9');
    });

    test('AnggotaKelasModel handles guru/role fallback and serialization', () {
      final byRole = AnggotaKelasModel.fromJson({
        'id': 5,
        'nama': 'Bu Ani',
        'email': 'ani@example.com',
        'role': 'guru',
        'dibuat': '2026-11-01T00:00:00Z',
      });
      expect(byRole.penggunaId, 5);
      expect(byRole.isGuru, isTrue);
      expect(byRole.dibuat, isNotNull);
      expect(byRole.toJson()['role'], 'guru');

      final student = AnggotaKelasModel.fromJson({
        'pengguna_id': 9,
        'nama': 'Murid',
        'guru': false,
      });
      expect(student.isGuru, isFalse);
      expect(student.role, 'murid');
    });

    test('Request payloads, TipePostinganModel, AdminModel, GuruModel, and UpdateGuruPayload', () {
      expect(
        const CreateKelasRequest(
          nama: 'Fisika',
          tingkat: 10,
          tahunAjaran: '2026/2027',
        ).toJson().containsKey('deskripsi'),
        isFalse,
      );
      expect(
        const CreateKelasRequest(
          nama: 'Fisika',
          deskripsi: 'Kelas pagi',
          tingkat: 10,
          tahunAjaran: '2026/2027',
        ).toJson()['deskripsi'],
        'Kelas pagi',
      );
      expect(
        const UpdateKelasRequest(nama: 'Baru', deskripsi: '').toJson(),
        {'nama': 'Baru', 'deskripsi': ''},
      );
      expect(
        const CreatePostinganPayload(
          judul: 'Bab 1',
          tipe: PostinganModel.tipeMateri,
        ).toJson().containsKey('lampiran'),
        isFalse,
      );
      expect(
        const EditPostinganPayload(
          judul: 'Bab 1',
          lampiran: [],
          tipe: PostinganModel.tipeTugas,
        ).toJson(),
        {
          'judul': 'Bab 1',
          'deskripsi': '',
          'lampiran': <String>[],
          'tipe': PostinganModel.tipeTugas,
        },
      );

      final tipe = TipePostinganModel.fromJson({'id': 1, 'nama': 'Tugas'});
      expect(tipe.toJson(), {'id': 1, 'nama': 'Tugas'});

      final admin = AdminModel.fromJson({
        'id': 1,
        'nama': 'Admin',
        'email': 'admin@example.com',
        'admin': true,
      });
      expect(admin.admin, isTrue);
      expect(admin.toJson()['email'], 'admin@example.com');

      final guru = GuruModel.fromJson({
        'kelas_id': 2,
        'nama_kelas': 'Kimia',
        'pengguna_id': 8,
        'nama_pengguna': 'Pak Hasan',
      });
      expect(guru.namaKelas, 'Kimia');
      expect(guru.toJson()['pengguna_id'], 8);

      expect(const UpdateGuruPayload(roleGuru: true).toJson(), {
        'role_guru': true,
      });
    });
  });

  group('KelasRepository', () {
    test('covers getListKelas, getKelas, createKelas, updateKelas, join, leave, promote, posts, tipe, and upload', () async {
      final calls = <({String method, String url, String body})>[];
      final isoNow = '2026-11-16T08:00:00Z';

      final client = HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          calls.add((
            method: request.method,
            url: '${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}',
            body: request.method == 'POST' && request.url.path == '/files/postingan'
                ? '<multipart>'
                : request.body,
          ));
          final path = request.url.path;
          if (path == '/kelas' && request.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'nama': 'Matematika',
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'MAT 10',
                  'guru': false,
                  'dibuat': isoNow,
                },
                {
                  'id': 2,
                  'nama': 'Fisika',
                  'tingkat': 11,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'FIS11',
                  'guru': true,
                  'dibuat': isoNow,
                },
              ]),
              200,
            );
          }
          if (path == '/kelas' && request.method == 'POST') {
            return http.Response(jsonEncode({'message': 'Created'}), 201);
          }
          if (path == '/kelas/MAT%2010' && request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'nama': 'Matematika',
                'tingkat': 10,
                'tahun_ajaran': '2026/2027',
                'kode_kelas': 'MAT 10',
                'guru': false,
                'dibuat': isoNow,
              }),
              200,
            );
          }
          if (path == '/kelas/MAT%2010' && request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'nama': 'Matematika Lanjutan',
                'deskripsi': 'Deskripsi baru',
                'tingkat': 10,
                'tahun_ajaran': '2026/2027',
                'kode_kelas': 'MAT 10',
                'guru': true,
                'dibuat': isoNow,
              }),
              200,
            );
          }
          if (path == '/kelas/MAT%2010/anggota') {
            return http.Response(
              jsonEncode([
                {'pengguna_id': 2, 'nama': 'Budi', 'guru': false},
              ]),
              200,
            );
          }
          if (path == '/kelas/MAT%2010/anggota/2/guru' &&
              request.method == 'PATCH') {
            return http.Response(jsonEncode({'message': 'Promoted'}), 200);
          }
          if (path == '/kelas/MAT%2010/gabung' && request.method == 'POST') {
            return http.Response(jsonEncode({'message': 'Joined'}), 200);
          }
          if (path == '/kelas/MAT%2010/keluar' && request.method == 'POST') {
            return http.Response(jsonEncode({'message': 'Left'}), 200);
          }
          if (path == '/kelas/MAT%2010/posts' && request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'id': 10,
                'judul': 'Materi 1',
                'deskripsi': 'Desc',
                'lampiran': <String>[],
                'pengguna_id': 1,
                'kelas_id': 1,
                'tipe_id': 2,
                'dibuat': isoNow,
              }),
              201,
            );
          }
          if (path == '/kelas/MAT%2010/postingan/10' &&
              request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'id': 10,
                'judul': 'Materi 1 Revisi',
                'deskripsi': 'Desc baru',
                'lampiran': ['https://example.com/a'],
                'pengguna_id': 1,
                'kelas_id': 1,
                'tipe_id': 2,
                'dibuat': isoNow,
              }),
              200,
            );
          }
          if (path == '/posts/tipe') {
            return http.Response(
              jsonEncode([
                {'id': 1, 'nama': 'Tugas'},
                {'id': 2, 'nama': 'Materi'},
              ]),
              200,
            );
          }
          if (path == '/files/postingan' && request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'nama': 'doc.pdf',
                    'path': '/uploads/2026/11/16/abc.pdf',
                    'ukuran': 4,
                  },
                ],
              }),
              201,
            );
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
      final repo = KelasRepository(client);

      final (enrolled, listErr) = await repo.getListKelas(guru: false);
      expect(listErr, isNull);
      expect(enrolled!.map((k) => k.kodeKelas), ['MAT 10']);

      final (kelas, getErr) = await repo.getKelas('MAT 10');
      expect(getErr, isNull);
      expect(kelas!.nama, 'Matematika');

      expect(
        await repo.createKelas(
          const CreateKelasRequest(
            nama: 'Kimia',
            tingkat: 12,
            tahunAjaran: '2026/2027',
          ),
        ),
        isNull,
      );

      final (updated, updErr) = await repo.updateKelas(
        'MAT 10',
        const UpdateKelasRequest(
          nama: 'Matematika Lanjutan',
          deskripsi: 'Deskripsi baru',
        ),
      );
      expect(updErr, isNull);
      expect(updated!.nama, 'Matematika Lanjutan');

      final (members, memErr) = await repo.getListAnggota('MAT 10');
      expect(memErr, isNull);
      expect(members!.single.nama, 'Budi');

      expect(await repo.promoteToGuru('MAT 10', 2), isNull);
      expect(await repo.joinKelas('MAT 10'), isNull);
      expect(await repo.leaveKelas('MAT 10'), isNull);

      final (createdPost, createPostErr) = await repo.createPostingan(
        'MAT 10',
        const CreatePostinganPayload(judul: 'Materi 1', tipe: 2),
      );
      expect(createPostErr, isNull);
      expect(createdPost!.judul, 'Materi 1');

      final (editedPost, editPostErr) = await repo.editPostingan(
        'MAT 10',
        10,
        const EditPostinganPayload(
          judul: 'Materi 1 Revisi',
          deskripsi: 'Desc baru',
          lampiran: ['https://example.com/a'],
          tipe: 2,
        ),
      );
      expect(editPostErr, isNull);
      expect(editedPost!.judul, 'Materi 1 Revisi');

      final (tipes, tipeErr) = await repo.getListTipePostingan();
      expect(tipeErr, isNull);
      expect(tipes, hasLength(2));

      final (uploaded, uploadErr) = await repo.uploadPostinganFiles([
        http.MultipartFile.fromBytes(
          'files',
          Uint8List.fromList([1, 2, 3, 4]),
          filename: 'doc.pdf',
        ),
      ]);
      expect(uploadErr, isNull);
      expect(uploaded!.single.nama, 'doc.pdf');

      expect(calls.first.url, '/kelas?guru=false');
    });

    test('handles error responses and TimeoutException cleanly', () async {
      final errRepo = KelasRepository(
        HttpClient(
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'message': 'Gagal proses'}), 400),
          ),
        ),
      );
      expect((await errRepo.getListKelas()).$2, 'Gagal proses');
      expect((await errRepo.getKelas('X')).$2, 'Gagal proses');
      expect((await errRepo.getListAnggota('X')).$2, 'Gagal proses');
      expect(
        await errRepo.createKelas(
          const CreateKelasRequest(nama: 'A', tingkat: 10, tahunAjaran: '2026'),
        ),
        'Gagal proses',
      );
      expect(
        (await errRepo.updateKelas(
          'X',
          const UpdateKelasRequest(nama: 'A', deskripsi: ''),
        )).$2,
        'Gagal proses',
      );
      expect(await errRepo.promoteToGuru('X', 1), 'Gagal proses');
      expect(await errRepo.joinKelas('X'), 'Gagal proses');
      expect(await errRepo.leaveKelas('X'), 'Gagal proses');
      expect((await errRepo.getListPostingan('X')).$2, 'Gagal proses');
      expect(
        (await errRepo.createPostingan(
          'X',
          const CreatePostinganPayload(judul: 'J', tipe: 1),
        )).$2,
        'Gagal proses',
      );
      expect(
        (await errRepo.editPostingan(
          'X',
          1,
          const EditPostinganPayload(judul: 'J', tipe: 1),
        )).$2,
        'Gagal proses',
      );
      expect((await errRepo.getListTipePostingan()).$2, 'Gagal proses');

      final timeoutRepo = KelasRepository(
        HttpClient(client: MockClient((_) => throw TimeoutException('to'))),
      );
      expect(
        await timeoutRepo.joinKelas('X'),
        'Request timed out. Please try again.',
      );
      expect(
        await timeoutRepo.leaveKelas('X'),
        'Request timed out. Please try again.',
      );
    });
  });

  group('KelasController', () {
    test('manages getListKelas, joinKelas, leaveKelas, getKelas, and postingan helpers', () async {
      var joined = false;
      var failLeave = false;
      const isoNow = '2026-11-16T08:00:00Z';

      final repo = KelasRepository(
        HttpClient(
          client: MockClient((request) async {
            final path = request.url.path;
            if (path == '/kelas') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'Biologi',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'BIO10',
                    'guru': false,
                    'dibuat': isoNow,
                  },
                  if (joined)
                    {
                      'id': 2,
                      'nama': 'Kimia',
                      'tingkat': 11,
                      'tahun_ajaran': '2026/2027',
                      'kode_kelas': 'KIM11',
                      'guru': false,
                      'dibuat': isoNow,
                    },
                  {
                    'id': 3,
                    'nama': 'Mengajar',
                    'tingkat': 12,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'GURU',
                    'guru': true,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas/KIM11/gabung') {
              joined = true;
              return http.Response(jsonEncode({'message': 'OK'}), 200);
            }
            if (path == '/kelas/KIM11/keluar') {
              if (failLeave) {
                return http.Response(
                  jsonEncode({'message': 'Gagal keluar'}),
                  500,
                );
              }
              return http.Response(jsonEncode({'message': 'OK'}), 200);
            }
            if (path == '/kelas/BIO10') {
              return http.Response(
                jsonEncode({
                  'id': 1,
                  'nama': 'Biologi',
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'BIO10',
                  'guru': false,
                  'dibuat': isoNow,
                }),
                200,
              );
            }
            if (path == '/kelas/BIO10/posts') {
              final tipe = int.tryParse(request.url.queryParameters['tipe'] ?? '') ?? 1;
              return http.Response(
                jsonEncode([
                  {
                    'id': tipe,
                    'judul': 'Post $tipe',
                    'deskripsi': '',
                    'lampiran': <String>[],
                    'pengguna_id': 1,
                    'kelas_id': 1,
                    'tipe_id': tipe,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        ),
      );

      final ctrl = KelasController(repo);
      addTearDown(ctrl.dispose);

      await ctrl.getListKelas();
      expect(ctrl.listKelas.map((k) => k.kodeKelas), ['BIO10']);

      expect(await ctrl.joinKelas('KIM11'), isNull);
      expect(ctrl.listKelas.map((k) => k.kodeKelas), ['BIO10', 'KIM11']);

      failLeave = true;
      expect(await ctrl.leaveKelas('KIM11'), 'Gagal keluar');
      expect(ctrl.listKelas.map((k) => k.kodeKelas), ['BIO10', 'KIM11']);

      failLeave = false;
      expect(await ctrl.leaveKelas('KIM11'), isNull);
      expect(ctrl.listKelas.map((k) => k.kodeKelas), ['BIO10']);

      final detail = await ctrl.getKelas('BIO10');
      expect(detail!.nama, 'Biologi');

      final (materi, _) = await ctrl.getListMateri('BIO10');
      expect(materi!.single.tipeId, PostinganModel.tipeMateri);

      final (tugas, _) = await ctrl.getListTugas('BIO10');
      expect(tugas!.single.tipeId, PostinganModel.tipeTugas);
    });
  });

  group('PengajarRepository & PengajarController', () {
    test('PengajarController static helpers parse grades and tahun ajaran', () {
      expect(PengajarController.parseTingkat('Kelas X'), 10);
      expect(PengajarController.parseTingkat('xi'), 11);
      expect(PengajarController.parseTingkat('XII'), 12);
      expect(PengajarController.parseTingkat('8'), 8);
      expect(PengajarController.parseTingkat('invalid'), 10);
      expect(
        PengajarController.defaultTahunAjaran(DateTime(2026, 7, 1)),
        '2026/2027',
      );
    });

    test('covers PengajarRepository endpoints and PengajarController state flows', () async {
      var created = false;
      const isoNow = '2026-11-16T08:00:00Z';

      final repo = PengajarRepository(
        HttpClient(
          client: MockClient((request) async {
            final path = request.url.path;
            if (path == '/kelas' && request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'Matematika X',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'MAT10',
                    'guru': true,
                    'dibuat': isoNow,
                  },
                  if (created)
                    {
                      'id': 2,
                      'nama': 'Fisika XII',
                      'tingkat': 12,
                      'tahun_ajaran': '2026/2027',
                      'kode_kelas': 'FIS12',
                      'guru': true,
                      'dibuat': isoNow,
                    },
                  {
                    'id': 3,
                    'nama': 'Murid Only',
                    'tingkat': 10,
                    'tahun_ajaran': '2026/2027',
                    'kode_kelas': 'STU10',
                    'guru': false,
                    'dibuat': isoNow,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas' && request.method == 'POST') {
              created = true;
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['tingkat'], 12);
              expect(body['tahun_ajaran'], isNotEmpty);
              return http.Response(jsonEncode({'message': 'OK'}), 201);
            }
            if (path == '/kelas/MAT10' && request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'id': 1,
                  'nama': body['nama'],
                  'deskripsi': body['deskripsi'],
                  'tingkat': 10,
                  'tahun_ajaran': '2026/2027',
                  'kode_kelas': 'MAT10',
                  'guru': true,
                  'dibuat': isoNow,
                }),
                200,
              );
            }
            if (path == '/MAT10/guru' && request.method == 'PATCH') {
              expect(jsonDecode(request.body), {'role_guru': true});
              return http.Response(jsonEncode({'message': 'OK'}), 200);
            }
            if (path == '/guru') {
              return http.Response(
                jsonEncode([
                  {
                    'kelas_id': 1,
                    'nama_kelas': 'Matematika X',
                    'pengguna_id': 1,
                    'nama_pengguna': 'Pak Budi',
                  },
                ]),
                200,
              );
            }
            if (path == '/admin') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'nama': 'Admin',
                    'email': 'admin@example.com',
                    'admin': true,
                  },
                ]),
                200,
              );
            }
            if (path == '/kelas/MAT10/posts' && request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'id': body['tipe'] == 2 ? 10 : 20,
                  'judul': body['judul'],
                  'deskripsi': body['deskripsi'] ?? '',
                  'lampiran': body['lampiran'] ?? <String>[],
                  'pengguna_id': 1,
                  'kelas_id': 1,
                  'tipe_id': body['tipe'],
                  'dibuat': isoNow,
                }),
                201,
              );
            }
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }),
        ),
      );
      final ctrl = PengajarController(repo);
      addTearDown(ctrl.dispose);

      await ctrl.getListKelas();
      expect(ctrl.listKelas.map((k) => k.kodeKelas), ['MAT10']);

      expect(
        await ctrl.createKelas(nama: 'Fisika XII', gradeInput: 'Kelas XII'),
        isNull,
      );
      expect(ctrl.listKelas.map((k) => k.kodeKelas), ['MAT10', 'FIS12']);

      final (editedKelas, editErr) = await ctrl.editKelas(
        'MAT10',
        nama: 'Matematika X Revisi',
        deskripsi: 'Baru',
      );
      expect(editErr, isNull);
      expect(editedKelas!.nama, 'Matematika X Revisi');
      expect(ctrl.listKelas.first.nama, 'Matematika X Revisi');

      expect(await ctrl.updateRoleGuru('MAT10', true), isNull);

      final (gurus, gurusErr) = await ctrl.getListGuru();
      expect(gurusErr, isNull);
      expect(gurus!.single.namaPengguna, 'Pak Budi');

      final (admins, adminsErr) = await ctrl.getListAdmin();
      expect(adminsErr, isNull);
      expect(admins!.single.nama, 'Admin');

      final (materi, mErr) = await ctrl.createMateri(
        'MAT10',
        judul: 'Aljabar',
        deskripsi: 'Bab 1',
        lampiran: const [
          LampiranItem(name: 'Link', detail: 'example.com/a', isLink: true),
        ],
      );
      expect(mErr, isNull);
      expect(materi!.tipeId, PostinganModel.tipeMateri);
      expect(materi.lampiran, ['https://example.com/a']);

      final (tugas, tErr) = await ctrl.createTugas(
        'MAT10',
        judul: 'Soal',
        deskripsi: 'Latihan',
      );
      expect(tErr, isNull);
      expect(tugas!.tipeId, PostinganModel.tipeTugas);
    });

    test('PostinganModel and Pengumpulan models convert UTC and +07:00 timestamps to GMT+7', () {
      final postFromUtc = PostinganModel.fromJson({
        'id': 1,
        'judul': 'Post UTC',
        'deskripsi': '',
        'lampiran': <String>[],
        'pengguna_id': 1,
        'kelas_id': 1,
        'tipe_id': 2,
        'dibuat': '2026-11-18T18:30:00Z',
      });
      expect(postFromUtc.dibuat, DateTime(2026, 11, 19, 1, 30));

      final postFromGmt7 = PostinganModel.fromJson({
        'id': 2,
        'judul': 'Post WIB',
        'deskripsi': '',
        'lampiran': <String>[],
        'pengguna_id': 1,
        'kelas_id': 1,
        'tipe_id': 2,
        'dibuat': '2026-11-19T01:30:00+07:00',
      });
      expect(postFromGmt7.dibuat, DateTime(2026, 11, 19, 1, 30));

      final roundTripped = PostinganModel.fromJson(postFromGmt7.toJson());
      expect(roundTripped.dibuat, DateTime(2026, 11, 19, 1, 30));

      final subMine = PengumpulanTugasModel.fromJson({
        'id': 5,
        'postingan_id': 1,
        'pengguna_id': 2,
        'submitted': true,
        'dibuat': '2026-11-18T02:16:00Z',
      });
      expect(subMine.dibuat, DateTime(2026, 11, 18, 9, 16));

      final subMurid = PengumpulanMuridModel.fromJson({
        'id': 6,
        'postingan_id': 1,
        'pengguna_id': 2,
        'nama': 'Budi',
        'email': 'budi@example.com',
        'dibuat': '2026-11-18T09:16:00+07:00',
      });
      expect(subMurid.dibuat, DateTime(2026, 11, 18, 9, 16));
    });
  });
}
