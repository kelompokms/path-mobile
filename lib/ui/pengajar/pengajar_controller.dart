import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class PengajarController extends ChangeNotifier {
  final PengajarRepository _repo;

  PengajarController(this._repo);

  String get baseUrl => _repo.baseUrl;

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
    _listKelas = (list ?? []).where((k) => k.guru).toList();
    notifyListeners();
  }

  Future<(List<AnggotaKelasModel>?, String?)> getListAnggota(String kodeKelas) {
    return _repo.getListAnggota(kodeKelas);
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

  static String defaultTahunAjaran([DateTime? now]) {
    final current = now ?? DateTime.now();
    return '${current.year}/${current.year + 1}';
  }

  Future<String?> createKelas({
    required String nama,
    String deskripsi = '',
    required String gradeInput,
    String? tahunAjaran,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final tingkat = parseTingkat(gradeInput);
    final normalizedTahunAjaran = (tahunAjaran ?? '').trim();

    final err = await _repo.createKelas(
      CreateKelasRequest(
        nama: nama,
        deskripsi: deskripsi,
        tingkat: tingkat,
        tahunAjaran: normalizedTahunAjaran.isEmpty
            ? defaultTahunAjaran()
            : normalizedTahunAjaran,
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

  Future<(KelasModel?, String?)> editKelas(
    String kodeKelas, {
    required String nama,
    required String deskripsi,
  }) async {
    final (updated, err) = await _repo.updateKelas(
      kodeKelas,
      UpdateKelasRequest(nama: nama, deskripsi: deskripsi),
    );
    if (err != null || updated == null) {
      return (null, err ?? 'Gagal memperbarui kelas');
    }

    final idx = _listKelas.indexWhere((k) => k.kodeKelas == kodeKelas);
    if (idx != -1) {
      _listKelas[idx] = updated;
      notifyListeners();
    }
    return (updated, null);
  }

  Future<String?> promoteToGuru(String kodeKelas, int penggunaId) {
    return _repo.promoteToGuru(kodeKelas, penggunaId);
  }

  List<String> resolveLampiranPaths(List<LampiranItem> items) {
    final result = <String>[];

    for (final item in items) {
      if (item.isLink) {
        final link = normalizeLampiranLink(item.targetUrl ?? item.detail);
        if (link != null) {
          result.add(link);
        }
        continue;
      }

      final url = item.targetUrl;
      if (url != null && url.isNotEmpty) {
        result.add(url);
      }
    }

    return result;
  }

  Future<(List<PostinganModel>?, String?)> getListPostingan(
    String kodeKelas, {
    int? tipe,
  }) {
    return _repo.getListPostingan(kodeKelas, tipe: tipe);
  }

  Future<(List<PostinganModel>?, String?)> getListMateri(String kodeKelas) {
    return _repo.getListPostingan(
      kodeKelas,
      tipe: PostinganModel.tipeMateri,
    );
  }

  Future<(List<PostinganModel>?, String?)> getListTugas(String kodeKelas) {
    return _repo.getListPostingan(
      kodeKelas,
      tipe: PostinganModel.tipeTugas,
    );
  }

  Future<(PostinganModel?, String?)> createMateri(
    String kodeKelas, {
    required String judul,
    required String deskripsi,
    List<LampiranItem> lampiran = const [],
  }) {
    final lampiranPaths = resolveLampiranPaths(lampiran);
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
  }) {
    final lampiranPaths = resolveLampiranPaths(lampiran);
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
  }) {
    final lampiranPaths = lampiran == null
        ? null
        : resolveLampiranPaths(lampiran);
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
