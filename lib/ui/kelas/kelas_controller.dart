import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';

export 'package:path_mobile/data/kelas/kelas_repository.dart'
    show ExplainMateriAiResult;

class KelasController extends ChangeNotifier {
  final KelasRepository _repo;

  KelasController(this._repo);

  String get baseUrl => _repo.baseUrl;

  int? get currentUserId => _repo.currentUserId;

  bool get isAdmin => _repo.isAdmin;

  bool _disposed = false;
  int _loadSeq = 0;

  List<KelasModel>? _listKelas;
  List<KelasModel> get listKelas => _listKelas ?? [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> getListKelas() async {
    if (_disposed) return;
    final seq = ++_loadSeq;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final (listKelas, err) = await _repo.getListKelas(guru: false);
    if (_disposed || seq != _loadSeq) return;
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      _safeNotify();
      return;
    }
    _listKelas = (listKelas ?? []).where((k) => !k.guru).toList();
    _safeNotify();
  }

  Future<(List<AnggotaKelasModel>?, String?)> getListAnggota(String kodeKelas) {
    return _repo.getListAnggota(kodeKelas);
  }

  Future<String?> promoteToGuru(String kodeKelas, int penggunaId) {
    return _repo.promoteToGuru(kodeKelas, penggunaId);
  }

  Future<String?> demoteToMurid(String kodeKelas, int penggunaId) {
    return _repo.demoteToMurid(kodeKelas, penggunaId);
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

  Future<String?> joinKelas(String kodeKelas) async {
    if (_disposed) return null;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final err = await _repo.joinKelas(kodeKelas);
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

  Future<String?> leaveKelas(String kodeKelas) async {
    if (_disposed) return null;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final err = await _repo.leaveKelas(kodeKelas);
    if (_disposed) return err;
    if (err != null) {
      _isLoading = false;
      _errorMessage = err;
      _safeNotify();
      return err;
    }

    _listKelas?.removeWhere((k) => k.kodeKelas == kodeKelas);
    _isLoading = false;
    _safeNotify();
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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

  Future<(List<TipePostinganModel>?, String?)> getListTipePostingan() {
    return _repo.getListTipePostingan();
  }

  Future<(List<UploadedPostinganFile>?, String?)> uploadPostinganFiles(
    List<http.MultipartFile> files,
  ) {
    return _repo.uploadPostinganFiles(files);
  }

  Future<(PengumpulanTugasModel?, String?)> getPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) {
    return _repo.getPengumpulanTugas(kodeKelas, postinganId);
  }

  Future<(PengumpulanTugasModel?, String?)> submitPengumpulanTugas(
    String kodeKelas,
    int postinganId,
    List<String> lampiran,
  ) {
    return _repo.submitPengumpulanTugas(kodeKelas, postinganId, lampiran);
  }

  Future<(List<String>?, String?)> tarikPengumpulanTugas(
    String kodeKelas,
    int postinganId,
  ) {
    return _repo.tarikPengumpulanTugas(kodeKelas, postinganId);
  }

  Future<(String?, String?)> chatAi({
    required String pesan,
    String isiMateri = '',
    String jenjang = '',
    List<String> modes = const [],
    List<Map<String, String>> riwayat = const [],
    bool gunakanModelGratis = false,
  }) {
    return _repo.chatAi(
      pesan: pesan,
      isiMateri: isiMateri,
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
    String fokus = '',
    String jenjang = '',
    bool diagram = false,
    bool gunakanModelGratis = false,
  }) {
    return _repo.ringkasDokumenAi(
      lampiranPaths: lampiranPaths,
      judul: judul,
      fokus: fokus,
      jenjang: jenjang,
      diagram: diagram,
      gunakanModelGratis: gunakanModelGratis,
    );
  }
}
