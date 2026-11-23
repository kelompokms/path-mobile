import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/profil/profil_model.dart';
import 'package:path_mobile/data/profil/profil_repository.dart';

class ProfilController extends ChangeNotifier {
  final ProfilRepository _repo;

  ProfilController(this._repo);

  String get baseUrl => _repo.baseUrl;

  bool get isAdmin => _profil?.admin == true || _repo.isAdmin;

  bool _disposed = false;

  ProfilModel? _profil;
  ProfilModel? get profil => _profil;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadProfil() async {
    if (_disposed) return;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final (data, err) = await _repo.getProfil();
    if (_disposed) return;
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      _safeNotify();
      return;
    }
    _profil = data;
    _safeNotify();
  }

  Future<String?> updateProfil({String? email, String? phone}) async {
    if (_disposed) return null;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final currentEmail = _profil?.email ?? '';
    final currentPhone = _profil?.phone ?? '';

    if (email != null && email.isNotEmpty && email != currentEmail) {
      final (updated, err) = await _repo.updateEmail(email);
      if (_disposed) return err;
      if (err != null) {
        _isLoading = false;
        _errorMessage = err;
        _safeNotify();
        return err;
      }
      if (updated != null) {
        _profil = updated.copyWith(
          role: updated.role.isNotEmpty ? updated.role : (_profil?.role ?? ''),
          admin: updated.role.isNotEmpty
              ? updated.admin
              : (_profil?.admin ?? false),
        );
      }
    }

    if (phone != null && phone.isNotEmpty && phone != currentPhone) {
      final (updated, err) = await _repo.updatePhone(phone);
      if (_disposed) return err;
      if (err != null) {
        _isLoading = false;
        _errorMessage = err;
        _safeNotify();
        return err;
      }
      if (updated != null) {
        _profil = updated.copyWith(
          role: updated.role.isNotEmpty ? updated.role : (_profil?.role ?? ''),
          admin: updated.role.isNotEmpty
              ? updated.admin
              : (_profil?.admin ?? false),
        );
      }
    }

    _isLoading = false;
    _safeNotify();
    return null;
  }

  Future<String?> updateProfilePicture(http.MultipartFile file) async {
    if (_disposed) return null;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final (updated, err) = await _repo.updateProfilePicture(file);
    if (_disposed) return err;
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      _safeNotify();
      return err;
    }
    if (updated != null) {
      _profil = updated.copyWith(
        role: updated.role.isNotEmpty ? updated.role : (_profil?.role ?? ''),
        admin: updated.role.isNotEmpty
            ? updated.admin
            : (_profil?.admin ?? false),
      );
    }
    _safeNotify();
    return null;
  }

  Future<String?> resetPassword(String oldPassword, String newPassword) async {
    if (_disposed) return null;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final err = await _repo.resetPassword(oldPassword, newPassword);
    if (_disposed) return err;
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      _safeNotify();
      return err;
    }
    _safeNotify();
    return null;
  }

  Future<(List<BantuanKontenModel>?, String?)> getBantuan() =>
      _repo.getBantuan();

  Future<(BantuanKontenModel?, String?)> updateBantuan(
    String kunci,
    String isi,
  ) => _repo.updateBantuan(kunci, isi);

  void logout() {
    _repo.logout();
    _profil = null;
    _safeNotify();
  }

  Future<void> flushPersistence() => _repo.flushPersistence();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
