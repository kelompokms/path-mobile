import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/data/admin/admin_repository.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';

/// State controller for admin school management views (users and classes).
class AdminController extends ChangeNotifier {
  final AdminRepository _repo;

  AdminController(this._repo);

  String get baseUrl => _repo.baseUrl;

  Map<int, int> _aiUsageByUserId = const {};
  Map<int, int> get aiUsageByUserId => _aiUsageByUserId;

  AdminAiOpsUsageModel? _aiOpsUsage;
  AdminAiOpsUsageModel? get aiOpsUsage => _aiOpsUsage;

  List<AdminPenggunaModel> _guruList = [];
  List<AdminPenggunaModel> get guruList => _guruList;

  List<AdminPenggunaModel> _muridList = [];
  List<AdminPenggunaModel> get muridList => _muridList;

  bool _isLoadingUsers = false;
  bool get isLoadingUsers => _isLoadingUsers;

  String? _usersError;
  String? get usersError => _usersError;

  List<AdminKelasModel> _allKelas = [];
  List<AdminKelasModel> get allKelas => _allKelas;

  bool _isLoadingKelas = false;
  bool get isLoadingKelas => _isLoadingKelas;

  String? _kelasError;
  String? get kelasError => _kelasError;

  String? _selectedTahunAjaran;
  String? get selectedTahunAjaran => _selectedTahunAjaran;

  int? _selectedTingkat;
  int? get selectedTingkat => _selectedTingkat;

  String _searchNamaKelas = '';
  String get searchNamaKelas => _searchNamaKelas;

  bool get hasActiveKelasFilters =>
      _selectedTahunAjaran != null ||
      _selectedTingkat != null ||
      _searchNamaKelas.trim().isNotEmpty;

  List<String> get tahunAjaranOptions {
    final values =
        _allKelas
            .map((k) => k.tahunAjaran.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return values;
  }

  List<int> get tingkatOptions {
    final values = _allKelas.map((k) => k.tingkat).toSet().toList()..sort();
    return values;
  }

  List<AdminKelasModel> get filteredKelas {
    final query = _searchNamaKelas.trim().toLowerCase();
    return _allKelas.where((k) {
      if (_selectedTahunAjaran != null &&
          k.tahunAjaran.trim().toLowerCase() !=
              _selectedTahunAjaran!.trim().toLowerCase()) {
        return false;
      }
      if (_selectedTingkat != null && k.tingkat != _selectedTingkat) {
        return false;
      }
      if (query.isNotEmpty && !k.nama.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<AdminPenggunaModel> filteredUsers(
    List<AdminPenggunaModel> source,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((u) {
      if (u.nama.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q)) {
        return true;
      }
      return u.kelas.any((c) => c.toLowerCase().contains(q));
    }).toList();
  }

  bool _disposed = false;
  int _usersLoadSeq = 0;
  int _kelasLoadSeq = 0;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadUsers() async {
    if (_disposed) return;
    final seq = ++_usersLoadSeq;
    _isLoadingUsers = true;
    _usersError = null;
    _safeNotify();

    final (data, err) = await _repo.getGuruDanMurid();
    if (_disposed || seq != _usersLoadSeq) return;
    _isLoadingUsers = false;
    if (err != null) {
      _usersError = err;
      _safeNotify();
      return;
    }

    _guruList = data?.guru ?? [];
    _muridList = data?.murid ?? [];
    _safeNotify();
  }

  Future<void> loadAiUsage({int? bulan, int? tahun}) async {
    if (_disposed) return;
    final (usage, err) = await _repo.getAiUsage(bulan: bulan, tahun: tahun);
    if (_disposed || err != null || usage == null) return;
    _aiUsageByUserId = usage;
    _safeNotify();
  }

  Future<void> loadAiOpsUsage() async {
    if (_disposed) return;
    final (ops, _) = await _repo.getAiOpsUsage();
    if (_disposed || ops == null) return;
    _aiOpsUsage = ops;
    _safeNotify();
  }

  Future<void> loadAllKelas({
    String? tahunAjaran,
    int? tingkat,
    String? nama,
  }) async {
    if (_disposed) return;
    final seq = ++_kelasLoadSeq;
    _isLoadingKelas = true;
    _kelasError = null;
    _safeNotify();

    final (list, err) = await _repo.getAllKelas(
      tahunAjaran: tahunAjaran,
      tingkat: tingkat,
      nama: nama,
    );
    if (_disposed || seq != _kelasLoadSeq) return;
    _isLoadingKelas = false;
    if (err != null) {
      _kelasError = err;
      _safeNotify();
      return;
    }

    _allKelas = list ?? [];
    if (_selectedTahunAjaran != null &&
        !tahunAjaranOptions.contains(_selectedTahunAjaran)) {
      _selectedTahunAjaran = null;
    }
    if (_selectedTingkat != null &&
        !tingkatOptions.contains(_selectedTingkat)) {
      _selectedTingkat = null;
    }
    _safeNotify();
  }

  void setTahunAjaranFilter(String? value) {
    final normalized = (value == null || value.trim().isEmpty)
        ? null
        : value.trim();
    if (_selectedTahunAjaran == normalized) return;
    _selectedTahunAjaran = normalized;
    _safeNotify();
  }

  void setTingkatFilter(int? value) {
    if (_selectedTingkat == value) return;
    _selectedTingkat = value;
    _safeNotify();
  }

  void setNamaKelasFilter(String value) {
    if (_searchNamaKelas == value) return;
    _searchNamaKelas = value;
    _safeNotify();
  }

  void resetKelasFilters() {
    if (!hasActiveKelasFilters) return;
    _selectedTahunAjaran = null;
    _selectedTingkat = null;
    _searchNamaKelas = '';
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String defaultTahunAjaran([DateTime? now]) =>
      PengajarController.defaultTahunAjaran(now);

  static int parseTingkat(String gradeInput) =>
      PengajarController.parseTingkat(gradeInput);

  Future<String?> createUser({
    required String nama,
    required String email,
    required String password,
    required String role,
  }) async {
    final err = await _repo.createUser(
      nama: nama.trim(),
      email: email.trim(),
      password: password,
      role: role.trim().toLowerCase(),
    );
    if (err != null) return err;
    await loadUsers();
    if (_allKelas.isNotEmpty) {
      await loadAllKelas();
    }
    return null;
  }

  Future<String?> deleteUser(int penggunaId) async {
    final err = await _repo.deleteUser(penggunaId);
    if (err != null) return err;
    await loadUsers();
    if (_allKelas.isNotEmpty) {
      await loadAllKelas();
    }
    return null;
  }

  Future<String?> updateUserRole(int penggunaId, String role) async {
    final err = await _repo.updateUserRole(penggunaId, role);
    if (err != null) return err;
    await loadUsers();
    if (_allKelas.isNotEmpty) {
      await loadAllKelas();
    }
    return null;
  }

  Future<String?> createKelas({
    required String nama,
    String deskripsi = '',
    required String gradeInput,
    String? tahunAjaran,
    int? pengampuId,
  }) async {
    final normalizedYear = (tahunAjaran ?? '').trim();
    final err = await _repo.createKelas(
      nama: nama.trim(),
      deskripsi: deskripsi.trim(),
      tingkat: parseTingkat(gradeInput),
      tahunAjaran: normalizedYear.isEmpty
          ? defaultTahunAjaran()
          : normalizedYear,
      pengampuId: pengampuId,
    );
    if (err != null) return err;
    await loadAllKelas();
    return null;
  }

  Future<(String?, String?)> uploadKelasCsv(http.MultipartFile fileCsv) async {
    final (message, err) = await _repo.uploadKelasCsv(fileCsv);
    if (err != null) return (null, err);
    await loadAllKelas();
    return (message, null);
  }

  Future<String?> updatePengampuKelas(String kodeKelas, int? pengampuId) async {
    final err = await _repo.updatePengampuKelas(kodeKelas, pengampuId);
    if (err != null) return err;
    await loadAllKelas();
    if (_guruList.isNotEmpty || _muridList.isNotEmpty) {
      await loadUsers();
    }
    return null;
  }
}
