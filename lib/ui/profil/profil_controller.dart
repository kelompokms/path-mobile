import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/profil/profil_model.dart';
import 'package:path_mobile/data/profil/profil_repository.dart';

class ProfilController extends ChangeNotifier {
  final ProfilRepository _repo;

  ProfilController(this._repo);

  ProfilModel? _profil;
  ProfilModel? get profil => _profil;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadProfil() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final (data, err) = await _repo.getProfil();
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return;
    }
    _profil = data;
    notifyListeners();
  }

  Future<String?> updateProfil({String? email, String? phone}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final currentEmail = _profil?.email ?? '';
    final currentPhone = _profil?.phone ?? '';

    if (email != null && email.isNotEmpty && email != currentEmail) {
      final (updated, err) = await _repo.updateEmail(email);
      if (err != null) {
        _isLoading = false;
        _errorMessage = err;
        notifyListeners();
        return err;
      }
      if (updated != null) {
        _profil = updated;
      }
    }

    if (phone != null && phone.isNotEmpty && phone != currentPhone) {
      final (updated, err) = await _repo.updatePhone(phone);
      if (err != null) {
        _isLoading = false;
        _errorMessage = err;
        notifyListeners();
        return err;
      }
      if (updated != null) {
        _profil = updated;
      }
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<String?> updateProfilePicture(http.MultipartFile file) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final (updated, err) = await _repo.updateProfilePicture(file);
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return err;
    }
    if (updated != null) {
      _profil = updated;
    }
    notifyListeners();
    return null;
  }

  Future<String?> resetPassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final err = await _repo.resetPassword(oldPassword, newPassword);
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return err;
    }
    notifyListeners();
    return null;
  }

  void logout() {
    _repo.logout();
    _profil = null;
    notifyListeners();
  }
}
