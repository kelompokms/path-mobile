import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/utils/http_client.dart';

class KalenderRepository {
  final HttpClient _client;

  KalenderRepository(this._client);

  String? _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message'] as String? ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  Future<(List<KalenderAkademikModel>?, String?)> getKalenderAkademik() async {
    try {
      final response = await _client
          .get(_client.uri('/kalender'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          null,
          _extractMessage(response.body, 'Gagal memuat kalender akademik'),
        );
      }

      final decoded = jsonDecode(response.body);
      final data = (decoded as List<dynamic>?) ?? <dynamic>[];
      final list = data
          .map((x) => KalenderAkademikModel.fromJson(x as Map<String, dynamic>))
          .toList();

      return (list, null);
    } on TimeoutException {
      return (null, 'Request timed out. Please try again.');
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  Future<(List<AgendaItemModel>?, String?)> getAgendas() async {
    final agendas = <AgendaItemModel>[];
    String? lastError;

    // 1. Fetch academic calendar events (/kalender)
    final (kalenderList, kalErr) = await getKalenderAkademik();
    if (kalenderList != null) {
      for (final item in kalenderList) {
        agendas.add(
          AgendaItemModel(
            date: item.tanggalMulai,
            heading: 'Kalender Akademik',
            title: item.namaKegiatan,
            time: 'Seharian',
          ),
        );
      }
    } else {
      lastError = kalErr;
    }

    // 2. Fetch user's classes (/kelas) and their tugas (/kelas/{kode_kelas}/posts?tipe=1)
    try {
      final response = await _client
          .get(_client.uri('/kelas'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final kelasData = (decoded as List<dynamic>?) ?? <dynamic>[];
        final kelasList = kelasData
            .map((x) => KelasModel.fromJson(x as Map<String, dynamic>))
            .toList();

        for (final k in kelasList) {
          if (k.kodeKelas.isEmpty) continue;
          final uri = _client
              .uri('/kelas/${k.kodeKelas}/posts')
              .replace(
                queryParameters: {'tipe': PostinganModel.tipeTugas.toString()},
              );
          final postsRes = await _client
              .get(uri)
              .timeout(const Duration(seconds: 10));
          if (postsRes.statusCode == 200) {
            final postsDecoded = jsonDecode(postsRes.body);
            final postsData = (postsDecoded as List<dynamic>?) ?? <dynamic>[];
            for (final pRaw in postsData) {
              final post = PostinganModel.fromJson(
                pRaw as Map<String, dynamic>,
              );
              final h = post.dibuat.hour.toString().padLeft(2, '0');
              final m = post.dibuat.minute.toString().padLeft(2, '0');
              agendas.add(
                AgendaItemModel(
                  date: post.dibuat,
                  heading: 'Tugas ${k.nama}',
                  title: post.judul,
                  time: '$h.$m',
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    if (agendas.isEmpty && lastError != null) {
      return (null, lastError);
    }

    return (agendas, null);
  }

  Future<String?> uploadKalenderAkademik(http.MultipartFile fileCsv) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _client.uri('/admin/kalender'),
      );
      request.files.add(fileCsv);

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200 && response.statusCode != 201) {
        return _extractMessage(
          response.body,
          'Gagal mengunggah kalender akademik',
        );
      }

      return null;
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (e) {
      return 'Network error: $e';
    }
  }
}
