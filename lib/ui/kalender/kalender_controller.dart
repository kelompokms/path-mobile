import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';

class KalenderController extends ChangeNotifier {
  final KalenderRepository _repo;

  KalenderController(this._repo);

  List<AgendaItemModel> _agendas = [];
  List<AgendaItemModel> get agendas => _agendas;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadAgendas() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final (list, err) = await _repo.getAgendas();
    _isLoading = false;
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return;
    }
    _agendas = list ?? [];
    notifyListeners();
  }

  Future<String?> uploadKalenderAkademik(http.MultipartFile fileCsv) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final err = await _repo.uploadKalenderAkademik(fileCsv);
    if (err != null) {
      _isLoading = false;
      _errorMessage = err;
      notifyListeners();
      return err;
    }

    await loadAgendas();
    return null;
  }
}
