import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';

class KalenderController extends ChangeNotifier {
  final KalenderRepository _repo;

  KalenderController(this._repo);

  List<AgendaItemModel> _agendas = [];
  List<AgendaItemModel> get agendas => _agendas;

  /// Normalized date (midnight local) -> global school agendas active on that day.
  Map<DateTime, List<AgendaItemModel>> get globalAgendasByDay {
    final map = <DateTime, List<AgendaItemModel>>{};
    for (final item in _agendas) {
      if (!item.isGlobal && item.heading != 'Kalender Akademik') continue;
      final start = DateTime(item.date.year, item.date.month, item.date.day);
      final rawEnd = item.endDate ?? start;
      var end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
      if (end.isBefore(start)) {
        end = start;
      }
      var daysAdded = 0;
      for (
        var day = start;
        !day.isAfter(end) && daysAdded <= 366;
        day = DateTime(day.year, day.month, day.day + 1), daysAdded++
      ) {
        (map[day] ??= []).add(item);
      }
    }
    return map;
  }

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

  static String formatApiDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<String?> createAgenda({
    required String namaEvent,
    String keterangan = '',
    required DateTime tanggalMulai,
    DateTime? tanggalSelesai,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final payload = CreateAgendaPayload(
      namaKegiatan: namaEvent.trim(),
      keterangan: keterangan.trim(),
      tanggalMulai: formatApiDate(tanggalMulai),
      tanggalSelesai: formatApiDate(tanggalSelesai ?? tanggalMulai),
    );

    final (_, err) = await _repo.createAgenda(payload);
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
