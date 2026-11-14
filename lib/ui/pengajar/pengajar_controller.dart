import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/ui/core/post_card.dart';

class PengajarController extends ChangeNotifier {
  final PengajarRepository _repo;

  PengajarController(this._repo);

  List<KelasModel> _listKelas = [];
  List<KelasModel> get listKelas => _listKelas;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  static int parseTingkat(String gradeInput) {
    final cleaned = gradeInput
        .trim()
        .toUpperCase()
        .replaceAll('KELAS', '')
        .trim();
    if (cleaned == 'XII' || cleaned == '12') return 12;
    if (cleaned == 'XI' || cleaned == '11') return 11;
    if (cleaned == 'X' || cleaned == '10') return 10;
    return int.tryParse(cleaned) ?? 10;
  }

  Future<void> getListKelas() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final (list, err) = await _repo.getListKelas();
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return;
    }
    _listKelas = list ?? [];
    notifyListeners();
  }

  Future<KelasModel?> getKelas(String kodeKelas) async {
    final (kelas, err) = await _repo.getKelas(kodeKelas);
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return null;
    }
    return kelas;
  }

  Future<String?> createKelas({
    required String nama,
    required String gradeInput,
    String? tahunAjaran,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final tingkat = parseTingkat(gradeInput);
    final now = DateTime.now();
    final defaultTahunAjaran = '${now.year}/${now.year + 1}';

    final err = await _repo.createKelas(
      CreateKelasRequest(
        nama: nama,
        tingkat: tingkat,
        tahunAjaran: tahunAjaran ?? defaultTahunAjaran,
      ),
    );

    if (err != null) {
      _isLoading = false;
      _errorMessage = err;
      notifyListeners();
      return err;
    }

    await getListKelas();
    return null;
  }

  Future<List<String>> resolveLampiranPaths(List<LampiranItem> items) async {
    final result = <String>[];
    final filesToUpload = <http.MultipartFile>[];

    for (final item in items) {
      if (item.isLink) {
        final raw = item.detail.trim();
        if (raw.isEmpty) continue;
        final link =
            (raw.startsWith('http://') || raw.startsWith('https://'))
            ? raw
            : 'https://$raw';
        result.add(link);
      } else if (item.name.startsWith('/uploads/') ||
          item.name.startsWith('uploads/') ||
          item.name.startsWith('http://') ||
          item.name.startsWith('https://')) {
        result.add(item.name);
      } else if (item.detail.startsWith('/uploads/') ||
          item.detail.startsWith('uploads/')) {
        result.add(item.detail);
      } else {
        final fileName = item.name.contains('.')
            ? item.name
            : '${item.name}.pdf';
        final isPdf = fileName.toLowerCase().endsWith('.pdf');
        final bytes = isPdf
            ? utf8.encode('%PDF-1.4\n%Lampiran $fileName\n%%EOF\n')
            : utf8.encode('Lampiran $fileName\n');
        filesToUpload.add(
          http.MultipartFile.fromBytes(
            'files',
            bytes,
            filename: fileName,
          ),
        );
      }
    }

    if (filesToUpload.isNotEmpty) {
      final (uploaded, _) = await _repo.uploadPostinganFiles(filesToUpload);
      if (uploaded != null) {
        for (final f in uploaded) {
          result.add(f.path);
        }
      }
    }

    return result;
  }

  Future<(List<PostinganModel>?, String?)> getListMateri(
    String kodeKelas, {
    String? mapel,
  }) {
    return _repo.getListPostingan(
      kodeKelas,
      tipe: PostinganModel.tipeMateri,
      mapel: mapel,
    );
  }

  Future<(List<PostinganModel>?, String?)> getListTugas(
    String kodeKelas, {
    String? mapel,
  }) {
    return _repo.getListPostingan(
      kodeKelas,
      tipe: PostinganModel.tipeTugas,
      mapel: mapel,
    );
  }

  Future<(PostinganModel?, String?)> createMateri(
    String kodeKelas, {
    required String judul,
    required String deskripsi,
    List<LampiranItem> lampiran = const [],
  }) async {
    final lampiranPaths = await resolveLampiranPaths(lampiran);
    return _repo.createPostingan(
      kodeKelas,
      CreatePostinganPayload(
        judul: judul,
        deskripsi: deskripsi,
        lampiran: lampiranPaths,
        tipe: PostinganModel.tipeMateri,
      ),
    );
  }

  Future<(PostinganModel?, String?)> createTugas(
    String kodeKelas, {
    required String judul,
    required String deskripsi,
    List<LampiranItem> lampiran = const [],
  }) async {
    final lampiranPaths = await resolveLampiranPaths(lampiran);
    return _repo.createPostingan(
      kodeKelas,
      CreatePostinganPayload(
        judul: judul,
        deskripsi: deskripsi,
        lampiran: lampiranPaths,
        tipe: PostinganModel.tipeTugas,
      ),
    );
  }

  Future<(PostinganModel?, String?)> editPostingan(
    String kodeKelas,
    int postinganId, {
    required String judul,
    required String deskripsi,
    List<LampiranItem>? lampiran,
    required int tipe,
  }) async {
    List<String>? lampiranPaths;
    if (lampiran != null) {
      lampiranPaths = await resolveLampiranPaths(lampiran);
    }
    return _repo.editPostingan(
      kodeKelas,
      postinganId,
      EditPostinganPayload(
        judul: judul,
        deskripsi: deskripsi,
        lampiran: lampiranPaths,
        tipe: tipe,
      ),
    );
  }

  Future<(List<TipePostinganModel>?, String?)> getListTipePostingan() {
    return _repo.getListTipePostingan();
  }

  Future<(List<UploadedPostinganFile>?, String?)> uploadPostinganFiles(
    List<http.MultipartFile> files,
  ) {
    return _repo.uploadPostinganFiles(files);
  }

  Future<String?> updateRoleGuru(String kodeKelas, bool roleGuru) {
    return _repo.updateRoleGuru(kodeKelas, roleGuru);
  }

  Future<(List<GuruModel>?, String?)> getListGuru() {
    return _repo.getListGuru();
  }

  Future<(List<AdminModel>?, String?)> getListAdmin() {
    return _repo.getListAdmin();
  }
}
