import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';

class KelasController extends ChangeNotifier {
  final KelasRepository _repo;

  KelasController(this._repo);

  List<KelasModel>? _listKelas;
  List<KelasModel> get listKelas => _listKelas ?? [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> getListKelas() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final (listKelas, err) = await _repo.getListKelas();
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return;
    }
    _listKelas = listKelas ?? [];
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

  Future<String?> joinKelas(String kodeKelas) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final err = await _repo.joinKelas(kodeKelas);
    if (err != null) {
      _isLoading = false;
      _errorMessage = err;
      notifyListeners();
      return err;
    }

    await getListKelas();
    return null;
  }

  Future<String?> leaveKelas(String kodeKelas) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final err = await _repo.leaveKelas(kodeKelas);
    if (err != null) {
      _isLoading = false;
      _errorMessage = err;
      notifyListeners();
      return err;
    }

    _listKelas?.removeWhere((k) => k.kodeKelas == kodeKelas);
    _isLoading = false;
    notifyListeners();
    return null;
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

  Future<(List<TipePostinganModel>?, String?)> getListTipePostingan() {
    return _repo.getListTipePostingan();
  }

  Future<(List<UploadedPostinganFile>?, String?)> uploadPostinganFiles(
    List<http.MultipartFile> files,
  ) {
    return _repo.uploadPostinganFiles(files);
  }
}
