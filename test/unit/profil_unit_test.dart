import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_mobile/data/profil/profil_model.dart';
import 'package:path_mobile/data/profil/profil_repository.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';
import 'package:path_mobile/utils/http_client.dart';

void main() {
  group('Profil models & request DTOs', () {
    test('ProfilModel supports username/nama fallback, toJson, and copyWith', () {
      final fromUsername = ProfilModel.fromJson({
        'id': 3,
        'username': 'Budi Santoso',
        'email': 'budi@example.com',
        'phone': '081234',
        'profile_picture': '/uploads/pfp/budi.jpg',
      });
      expect(fromUsername.id, 3);
      expect(fromUsername.username, 'Budi Santoso');
      expect(fromUsername.nama, 'Budi Santoso');
      expect(fromUsername.toJson(), {
        'id': 3,
        'username': 'Budi Santoso',
        'nama': 'Budi Santoso',
        'email': 'budi@example.com',
        'phone': '081234',
        'profile_picture': '/uploads/pfp/budi.jpg',
      });

      final fromNama = ProfilModel.fromJson({'id': 4, 'nama': 'Siti'});
      expect(fromNama.username, 'Siti');
      expect(fromNama.copyWith(email: 'siti@example.com').email, 'siti@example.com');

      expect(ProfilModel.fromJson({}).username, 'Pengguna PATH');
    });

    test('UpdatePenggunaResponse and request payloads serialize properly', () {
      final parsed = UpdatePenggunaResponse.fromJson({
        'message': 'Berhasil',
        'data': {
          'id': 1,
          'nama': 'Ani',
          'email': 'ani@example.com',
        },
      });
      expect(parsed.message, 'Berhasil');
      expect(parsed.data.username, 'Ani');

      final empty = UpdatePenggunaResponse.fromJson({'message': 'Kosong'});
      expect(empty.data.id, 0);
      expect(empty.data.username, '');

      expect(
        const UpdateEmailRequest(email: 'baru@example.com').toJson(),
        {'email': 'baru@example.com'},
      );
      expect(
        const UpdatePhoneRequest(phone: '+628123').toJson(),
        {'phone': '+628123'},
      );
      expect(
        const ResetPasswordRequest(
          oldPassword: 'old',
          newPassword: 'new',
        ).toJson(),
        {'old_password': 'old', 'new_password': 'new'},
      );
    });
  });

  group('ProfilRepository', () {
    test('getProfil, updateEmail, updatePhone, updateProfilePicture, resetPassword, and logout', () async {
      final calls = <({String method, String path, String body})>[];
      final client = HttpClient(
        token: 'jwt.token',
        client: MockClient((request) async {
          calls.add((
            method: request.method,
            path: request.url.path,
            body: request.method == 'PATCH' && request.url.path.endsWith('/profile-picture')
                ? '<multipart>'
                : request.body,
          ));
          if (request.url.path == '/pengguna' && request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'nama': 'Rin',
                'email': 'rin@example.com',
                'phone': '0811',
                'profile_picture': '',
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/email' &&
              request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'message': 'Email berhasil diperbarui',
                'data': {
                  'id': 1,
                  'nama': 'Rin',
                  'email': 'baru@example.com',
                  'phone': '0811',
                  'profile_picture': '',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/phone' &&
              request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'message': 'Nomor HP berhasil diperbarui',
                'data': {
                  'id': 1,
                  'nama': 'Rin',
                  'email': 'baru@example.com',
                  'phone': '0899',
                  'profile_picture': '',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/profile-picture' &&
              request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'message': 'Foto diperbarui',
                'data': {
                  'id': 1,
                  'nama': 'Rin',
                  'email': 'baru@example.com',
                  'phone': '0899',
                  'profile_picture': '/uploads/pfp/rin.png',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/reset-password' &&
              request.method == 'POST') {
            return http.Response(
              jsonEncode({'message': 'Password berhasil diubah'}),
              200,
            );
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      );
      final repo = ProfilRepository(client);

      final (profil, getErr) = await repo.getProfil();
      expect(getErr, isNull);
      expect(profil!.email, 'rin@example.com');

      final (emailUpdated, emailErr) = await repo.updateEmail('baru@example.com');
      expect(emailErr, isNull);
      expect(emailUpdated!.email, 'baru@example.com');

      final (phoneUpdated, phoneErr) = await repo.updatePhone('0899');
      expect(phoneErr, isNull);
      expect(phoneUpdated!.phone, '0899');

      final file = http.MultipartFile.fromBytes(
        'file',
        Uint8List.fromList([1, 2, 3]),
        filename: 'avatar.png',
      );
      final (pfpUpdated, pfpErr) = await repo.updateProfilePicture(file);
      expect(pfpErr, isNull);
      expect(pfpUpdated!.profilePicture, '/uploads/pfp/rin.png');

      final resetErr = await repo.resetPassword('oldpw', 'newpw');
      expect(resetErr, isNull);

      repo.logout();
      expect(client.token, isNull);

      expect(calls.map((c) => '${c.method} ${c.path}').toList(), [
        'GET /pengguna',
        'PATCH /pengguna/email',
        'PATCH /pengguna/phone',
        'PATCH /pengguna/profile-picture',
        'POST /pengguna/reset-password',
      ]);
      expect(jsonDecode(calls[4].body), {
        'old_password': 'oldpw',
        'new_password': 'newpw',
      });
    });

    test('handles error responses, timeouts, and network errors cleanly', () async {
      final errRepo = ProfilRepository(
        HttpClient(
          token: 'jwt',
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'message': 'Data tidak valid'}), 400),
          ),
        ),
      );
      expect((await errRepo.getProfil()).$2, 'Data tidak valid');
      expect((await errRepo.updateEmail('x')).$2, 'Data tidak valid');
      expect((await errRepo.updatePhone('x')).$2, 'Data tidak valid');
      expect(
        (await errRepo.updateProfilePicture(
          http.MultipartFile.fromBytes('file', [1], filename: 'a.png'),
        )).$2,
        'Data tidak valid',
      );
      expect(await errRepo.resetPassword('a', 'b'), 'Data tidak valid');

      final timeoutRepo = ProfilRepository(
        HttpClient(client: MockClient((_) => throw TimeoutException('to'))),
      );
      expect(
        (await timeoutRepo.getProfil()).$2,
        'Request timed out. Please try again.',
      );
      expect(
        await timeoutRepo.resetPassword('a', 'b'),
        'Request timed out. Please try again.',
      );
    });
  });

  group('ProfilController', () {
    test('loadProfil, selective updateProfil, resetPassword, and logout', () async {
      final calledPaths = <String>[];
      var failEmail = false;

      final client = HttpClient(
        token: 'jwt',
        client: MockClient((request) async {
          calledPaths.add('${request.method} ${request.url.path}');
          if (request.url.path == '/pengguna') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'nama': 'Rin',
                'email': 'rin@example.com',
                'phone': '0811',
                'profile_picture': '',
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/email') {
            if (failEmail) {
              return http.Response(
                jsonEncode({'message': 'Email sudah dipakai'}),
                400,
              );
            }
            return http.Response(
              jsonEncode({
                'message': 'OK',
                'data': {
                  'id': 1,
                  'nama': 'Rin',
                  'email': 'baru@example.com',
                  'phone': '0811',
                  'profile_picture': '',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/phone') {
            return http.Response(
              jsonEncode({
                'message': 'OK',
                'data': {
                  'id': 1,
                  'nama': 'Rin',
                  'email': 'baru@example.com',
                  'phone': '0822',
                  'profile_picture': '',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/pengguna/reset-password') {
            return http.Response(jsonEncode({'message': 'OK'}), 200);
          }
          return http.Response('{}', 404);
        }),
      );
      final ctrl = ProfilController(ProfilRepository(client));
      addTearDown(ctrl.dispose);

      await ctrl.loadProfil();
      expect(ctrl.profil!.email, 'rin@example.com');

      // Unchanged email/phone skips API calls
      expect(
        await ctrl.updateProfil(email: 'rin@example.com', phone: '0811'),
        isNull,
      );
      expect(calledPaths, ['GET /pengguna']);

      // Failed email stops before phone call
      failEmail = true;
      expect(
        await ctrl.updateProfil(email: 'baru@example.com', phone: '0822'),
        'Email sudah dipakai',
      );
      expect(calledPaths, ['GET /pengguna', 'PATCH /pengguna/email']);

      // Successful email + phone update updates controller profil
      failEmail = false;
      expect(
        await ctrl.updateProfil(email: 'baru@example.com', phone: '0822'),
        isNull,
      );
      expect(ctrl.profil!.email, 'baru@example.com');
      expect(ctrl.profil!.phone, '0822');

      expect(await ctrl.resetPassword('old', 'new'), isNull);

      ctrl.logout();
      expect(ctrl.profil, isNull);
      expect(client.token, isNull);
    });
  });
}
