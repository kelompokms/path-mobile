import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_repository.dart'
    show ExplainMateriAiResult;
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/data/pengajar/pengajar_repository.dart';

export 'package:path_mobile/data/kelas/kelas_repository.dart'
    show ExplainMateriAiResult;
export 'package:path_mobile/data/pengajar/pengajar_repository.dart'
    show AssessmentCheckAiResult, GeneratedMateriAiResult, KoreksiAiResult;
import 'package:path_mobile/utils/lampiran_helper.dart';

class PengajarController extends ChangeNotifier {
  final PengajarRepository _repo;

  PengajarController(this._repo);

  String get baseUrl => _repo.baseUrl;

  int? get currentUserId => _repo.currentUserId;

  bool get isAdmin => _repo.isAdmin;

  bool _disposed = false;
  int _loadSeq = 0;

  List<KelasModel> _listKelas = [];
  List<KelasModel> get listKelas => _listKelas;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

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
    if (_disposed) return;
    final seq = ++_loadSeq;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final (list, err) = await _repo.getListKelas();
    if (_disposed || seq != _loadSeq) return;
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      _safeNotify();
      return;
    }
    _listKelas = (list ?? []).where((k) => k.guru).toList();
    _safeNotify();
  }

  Future<(List<AnggotaKelasModel>?, String?)> getListAnggota(String kodeKelas) {
    return _repo.getListAnggota(kodeKelas);
  }

  Future<KelasModel?> getKelas(String kodeKelas) async {
    final (kelas, err) = await _repo.getKelas(kodeKelas);
    if (_disposed) return err != null ? null : kelas;
    if (err != null) {
      _errorMessage = err;
      _safeNotify();
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
    if (_disposed) return null;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

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
    if (_disposed) return err;

    if (err != null) {
      _isLoading = false;
      _errorMessage = err;
      _safeNotify();
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
    if (_disposed) return (updated, null);

    final idx = _listKelas.indexWhere((k) => k.kodeKelas == kodeKelas);
    if (idx != -1) {
      _listKelas[idx] = updated;
      _safeNotify();
    }
    return (updated, null);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<String?> promoteToGuru(String kodeKelas, int penggunaId) {
    return _repo.promoteToGuru(kodeKelas, penggunaId);
  }

  Future<String?> demoteToMurid(String kodeKelas, int penggunaId) {
    return _repo.demoteToMurid(kodeKelas, penggunaId);
  }

  List<String> resolveLampiranPaths(List<LampiranItem> items) {
    return resolveLampiranItemPaths(items);
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
    DateTime? tenggatWaktu,
  }) {
    final lampiranPaths = resolveLampiranPaths(lampiran);
    return _repo.createPostingan(
      kodeKelas,
      CreatePostinganPayload(
        judul: judul,
        deskripsi: deskripsi,
        lampiran: lampiranPaths,
        tipe: PostinganModel.tipeTugas,
        tenggatWaktu: tenggatWaktu,
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
    bool? menerimaKiriman,
    DateTime? tenggatWaktu,
    bool hapusTenggat = false,
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
        menerimaKiriman: menerimaKiriman,
        tenggatWaktu: tenggatWaktu,
        hapusTenggat: hapusTenggat,
      ),
    );
  }

  Future<String?> deletePostingan(String kodeKelas, int postinganId) {
    return _repo.deletePostingan(kodeKelas, postinganId);
  }

  Future<(List<TipePostinganModel>?, String?)> getListTipePostingan() {
    return _repo.getListTipePostingan();
  }

  Future<(List<UploadedPostinganFile>?, String?)> uploadPostinganFiles(
    List<http.MultipartFile> files,
  ) {
    return _repo.uploadPostinganFiles(files);
  }

  Future<(List<PengumpulanMuridModel>?, String?)> listPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) {
    return _repo.listPengumpulanTugas(kodeKelas, postinganId);
  }

  Future<(List<PengumpulanMuridModel>?, String?)> simpanNilaiPengumpulan(
    String kodeKelas,
    int postinganId,
    Map<int, int?> nilaiByPenggunaId,
  ) {
    return _repo.simpanNilaiPengumpulan(
      kodeKelas,
      postinganId,
      nilaiByPenggunaId,
    );
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

  Future<(GeneratedMateriAiResult?, String?)> generateMateriAi({
    required String judul,
    required String deskripsiMateri,
    List<String> lampiranPaths = const [],
    String jenjang = '',
    bool tabel = false,
    bool diagram = false,
    bool ilustrasi = false,
    bool kombinasi = false,
    String formatKeluaran = 'pdf',
    bool gunakanModelGratis = false,
  }) {
    return _repo.generateMateriAi(
      judul: judul,
      deskripsiMateri: deskripsiMateri,
      lampiranPaths: lampiranPaths,
      jenjang: jenjang,
      tabel: tabel,
      diagram: diagram,
      ilustrasi: ilustrasi,
      kombinasi: kombinasi,
      formatKeluaran: formatKeluaran,
      gunakanModelGratis: gunakanModelGratis,
    );
  }

  Future<(KoreksiAiResult?, String?)> koreksiTugasAi({
    required String kodeKelas,
    required int postinganId,
    required List<int> penggunaIds,
    String deskripsiKunci = '',
    String? keyFileName,
    Uint8List? keyFileBytes,
  }) {
    return _repo.koreksiTugasAi(
      kodeKelas: kodeKelas,
      postinganId: postinganId,
      penggunaIds: penggunaIds,
      deskripsiKunci: deskripsiKunci,
      keyFileName: keyFileName,
      keyFileBytes: keyFileBytes,
    );
  }

  Future<(AssessmentCheckAiResult?, String?)> cekKemiripanAi({
    required String kodeKelas,
    required int postinganId,
    List<int> penggunaIds = const [],
    bool gunakanModelGratis = false,
  }) {
    return _repo.cekKemiripanAi(
      kodeKelas: kodeKelas,
      postinganId: postinganId,
      penggunaIds: penggunaIds,
      gunakanModelGratis: gunakanModelGratis,
    );
  }

  Future<(AssessmentCheckAiResult?, String?)> cekIndikasiAi({
    required String kodeKelas,
    required int postinganId,
    List<int> penggunaIds = const [],
    String jenjang = '',
    bool gunakanModelGratis = false,
  }) {
    return _repo.cekIndikasiAi(
      kodeKelas: kodeKelas,
      postinganId: postinganId,
      penggunaIds: penggunaIds,
      jenjang: jenjang,
      gunakanModelGratis: gunakanModelGratis,
    );
  }

  Future<(String?, String?)> chatAi({
    required String pesan,
    String isiMateri = '',
    List<String> lampiranPaths = const [],
    String jenjang = '',
    List<String> modes = const [],
    List<Map<String, String>> riwayat = const [],
    bool gunakanModelGratis = false,
  }) {
    return _repo.chatAi(
      pesan: pesan,
      isiMateri: isiMateri,
      lampiranPaths: lampiranPaths,
      jenjang: jenjang,
      modes: modes,
      riwayat: riwayat,
      gunakanModelGratis: gunakanModelGratis,
    );
  }

  Future<(ExplainMateriAiResult?, String?)> explainMateriAi({
    required String pertanyaan,
    String deskripsiMateri = '',
    String isiMateri = '',
    List<String> lampiranPaths = const [],
    String jenjang = '',
    bool tabel = false,
    bool diagram = false,
    bool ilustrasi = false,
    bool kombinasi = false,
    bool gunakanModelGratis = false,
  }) {
    return _repo.explainMateriAi(
      pertanyaan: pertanyaan,
      deskripsiMateri: deskripsiMateri,
      isiMateri: isiMateri,
      lampiranPaths: lampiranPaths,
      jenjang: jenjang,
      tabel: tabel,
      diagram: diagram,
      ilustrasi: ilustrasi,
      kombinasi: kombinasi,
      gunakanModelGratis: gunakanModelGratis,
    );
  }

  Future<(ExplainMateriAiResult?, String?)> ringkasDokumenAi({
    required List<String> lampiranPaths,
    String judul = '',
    String deskripsiMateri = '',
    String fokus = '',
    String jenjang = '',
    bool diagram = false,
    bool gunakanModelGratis = false,
  }) {
    return _repo.ringkasDokumenAi(
      lampiranPaths: lampiranPaths,
      judul: judul,
      deskripsiMateri: deskripsiMateri,
      fokus: fokus,
      jenjang: jenjang,
      diagram: diagram,
      gunakanModelGratis: gunakanModelGratis,
    );
  }
}
