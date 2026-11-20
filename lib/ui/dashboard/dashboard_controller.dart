import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart' as km;
import 'package:path_mobile/data/pengajar/pengajar_model.dart' as pm;
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/dashboard/dashboard_models.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/utils/date_time_helper.dart';

export 'dashboard_models.dart';

/// State controller for the role-aware Home dashboard (`Beranda Guru` and `Beranda Murid`).
class DashboardController extends ChangeNotifier {
  static const int maxSummaryClasses = 6;
  static const int maxCheckedTasks = 8;
  static const List<String> weekdayLabels = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  final KelasController? kelasController;
  final PengajarController? pengajarController;
  final KalenderRepository? kalenderRepository;
  final bool isGuruRole;
  final DateTime Function() _nowProvider;

  DashboardController({
    this.kelasController,
    this.pengajarController,
    this.kalenderRepository,
    this.isGuruRole = false,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? nowGmt7 {
    kelasController?.addListener(_handleDependencyChanged);
    pengajarController?.addListener(_handleDependencyChanged);
  }

  bool _disposed = false;
  bool _isLoadingSummary = false;
  int _loadSeq = 0;

  int _totalGuruStudents = 0;
  int _totalGuruSubmissions = 0;
  int _totalGuruExpected = 0;
  int _totalGuruMissing = 0;
  int _recent7DaysSubmissions = 0;
  int _todaySubmissions = 0;
  int _withAttachmentCount = 0;
  int _markAsDoneCount = 0;
  List<GuruClassProgress> _classProgressList = const [];
  List<DailySubmissionBucket> _dailySubmissions = const [];
  List<GuruSubmissionSummary> _guruSubmissions = const [];

  int _totalMuridTugas = 0;
  int _pendingMuridTugas = 0;
  List<MuridTaskSummary> _muridTasks = const [];

  List<KalenderAkademikModel> _upcomingAgendas = const [];

  bool get isLoadingSummary => _isLoadingSummary;
  bool get hasKalender => kalenderRepository != null;

  int get totalGuruStudents => _totalGuruStudents;
  int get totalGuruSubmissions => _totalGuruSubmissions;
  int get totalGuruExpected => _totalGuruExpected;
  int get totalGuruMissing => _totalGuruMissing;
  int get recent7DaysSubmissions => _recent7DaysSubmissions;
  int get todaySubmissions => _todaySubmissions;
  int get withAttachmentCount => _withAttachmentCount;
  int get markAsDoneCount => _markAsDoneCount;
  List<GuruClassProgress> get classProgressList => _classProgressList;
  List<DailySubmissionBucket> get dailySubmissions => _dailySubmissions;
  List<GuruSubmissionSummary> get guruSubmissions => _guruSubmissions;

  int get totalMuridTugas => _totalMuridTugas;
  int get pendingMuridTugas => _pendingMuridTugas;
  List<MuridTaskSummary> get muridTasks => _muridTasks;

  List<KalenderAkademikModel> get upcomingAgendas => _upcomingAgendas;

  List<ClassItem> get teachingItems {
    final models =
        pengajarController?.listKelas.where((k) => k.guru).toList() ??
        const <km.KelasModel>[];
    return _mapItems(models);
  }

  List<ClassItem> get enrolledItems {
    final models =
        kelasController?.listKelas.where((k) => !k.guru).toList() ??
        const <km.KelasModel>[];
    return _mapItems(models);
  }

  List<ClassItem> get assistantItems => teachingItems;

  bool get isAssistant => assistantItems.isNotEmpty;

  double? get overallSubmissionRate => _totalGuruExpected > 0
      ? (_totalGuruSubmissions / _totalGuruExpected).clamp(0.0, 1.0)
      : null;

  bool get showGuruInitialLoader =>
      _isLoadingSummary && teachingItems.isEmpty && _guruSubmissions.isEmpty;

  bool get showMuridInitialLoader =>
      _isLoadingSummary && enrolledItems.isEmpty && _muridTasks.isEmpty;

  Future<void> refreshSummary() async {
    if (_disposed) return;
    final seq = ++_loadSeq;
    _isLoadingSummary = true;
    _safeNotify();

    await Future.wait([
      _loadClassData(seq),
      _loadAgendaPreview(seq),
    ]);

    if (_disposed || seq != _loadSeq) return;
    _isLoadingSummary = false;
    _safeNotify();
  }

  Future<void> _loadAgendaPreview(int seq) async {
    final repo = kalenderRepository;
    if (repo == null) return;
    final (list, err) = await repo.getKalenderAkademik();
    if (_disposed || seq != _loadSeq || err != null || list == null) return;

    final today = _dateOnly(_nowProvider());
    final upcoming = list.where((e) {
      final end = _dateOnly(e.tanggalSelesai);
      return !end.isBefore(today);
    }).toList()..sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));

    _upcomingAgendas = upcoming.take(3).toList();
    _safeNotify();
  }

  Future<void> _loadClassData(int seq) async {
    if (isGuruRole) {
      await _loadGuruSummary(seq);
    } else {
      await _loadMuridSummary(seq);
    }
  }

  Future<void> _loadGuruSummary(int seq) async {
    final pengajarCtrl = pengajarController;
    final kelasCtrl = kelasController;
    await Future.wait([
      if (pengajarCtrl != null) pengajarCtrl.getListKelas(),
      if (kelasCtrl != null) kelasCtrl.getListKelas(),
    ]);
    if (_disposed || seq != _loadSeq || pengajarCtrl == null) return;

    final teaching = pengajarCtrl.listKelas.where((k) => k.guru).toList();
    final scoped = teaching.take(maxSummaryClasses).toList();

    final allTasks = <({ClassItem item, pm.PostinganModel post})>[];
    final studentCountByCode = <String, int>{};
    final taskCountByCode = <String, int>{};
    final classItemByCode = <String, ClassItem>{};
    final uniqueStudentIds = <int>{};
    var anonymousStudents = 0;

    final classBatches = await Future.wait([
      for (var i = 0; i < scoped.length; i++)
        Future.wait<Object?>([
          pengajarCtrl.getListTugas(scoped[i].kodeKelas),
          pengajarCtrl.getListAnggota(scoped[i].kodeKelas),
        ]),
    ]);
    if (_disposed || seq != _loadSeq) return;

    for (var i = 0; i < scoped.length; i++) {
      final (tugasList, _) =
          classBatches[i][0] as (List<pm.PostinganModel>?, String?);
      final (anggotaList, _) =
          classBatches[i][1] as (List<pm.AnggotaKelasModel>?, String?);
      final item = scoped[i].toClassItem(coverIndex: i);
      final code = item.code;
      classItemByCode[code] = item;

      final students = (anggotaList ?? const <pm.AnggotaKelasModel>[])
          .where((m) => !m.isGuru)
          .toList();
      studentCountByCode[code] = students.length;
      for (final student in students) {
        if (student.penggunaId > 0) {
          uniqueStudentIds.add(student.penggunaId);
        } else {
          anonymousStudents++;
        }
      }

      taskCountByCode[code] = tugasList?.length ?? 0;
      if (tugasList != null) {
        for (final t in tugasList) {
          allTasks.add((item: item, post: t));
        }
      }
    }

    allTasks.sort((a, b) => b.post.dibuat.compareTo(a.post.dibuat));
    final checkedTasks = allTasks.take(maxCheckedTasks).toList();

    final submissionResults = await Future.wait([
      for (final entry in checkedTasks)
        pengajarCtrl.listPengumpulanTugas(entry.item.code, entry.post.id),
    ]);
    if (_disposed || seq != _loadSeq) return;

    final today = _dateOnly(_nowProvider());
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final dailyCounts = List<int>.filled(7, 0);

    var submissionTotal = 0;
    var expectedTotal = 0;
    var missingTotal = 0;
    var withAttachment = 0;
    var markAsDone = 0;
    final submissionsByCode = <String, int>{};
    final expectedByCode = <String, int>{};
    final summaries = <GuruSubmissionSummary>[];

    for (var i = 0; i < checkedTasks.length; i++) {
      final entry = checkedTasks[i];
      final code = entry.item.code;
      final (items, _) = submissionResults[i];
      final list = items ?? const <pm.PengumpulanMuridModel>[];
      final count = list.length;
      final classStudents = studentCountByCode[code] ?? 0;

      submissionTotal += count;
      submissionsByCode[code] = (submissionsByCode[code] ?? 0) + count;
      if (classStudents > 0) {
        final effectiveExpected = math.max(classStudents, count);
        expectedTotal += effectiveExpected;
        expectedByCode[code] = (expectedByCode[code] ?? 0) + effectiveExpected;
        missingTotal += math.max(0, classStudents - count);
      }

      for (final s in list) {
        if (s.isMarkAsDone) {
          markAsDone++;
        } else {
          withAttachment++;
        }
        final submittedAt = s.dibuat;
        if (submittedAt != null) {
          final dayUtc = DateTime.utc(
            submittedAt.year,
            submittedAt.month,
            submittedAt.day,
          );
          final diffDays = todayUtc.difference(dayUtc).inDays;
          if (diffDays >= 0 && diffDays < 7) {
            dailyCounts[6 - diffDays]++;
          }
        }
      }

      final sorted = [...list]
        ..sort((a, b) {
          final da = a.dibuat;
          final db = b.dibuat;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
      summaries.add(
        GuruSubmissionSummary(
          classItem: entry.item,
          post: entry.post,
          submissionCount: count,
          totalStudents: classStudents,
          latestStudentName: sorted.isNotEmpty ? sorted.first.nama : '',
        ),
      );
    }

    summaries.sort((a, b) {
      final ra = a.completionRate;
      final rb = b.completionRate;
      if (ra != null && rb != null && ra != rb) {
        return ra.compareTo(rb);
      }
      if ((b.submissionCount > 0) != (a.submissionCount > 0)) {
        return b.submissionCount.compareTo(a.submissionCount);
      }
      return b.post.dibuat.compareTo(a.post.dibuat);
    });

    final classProgress =
        [
          for (final k in scoped)
            GuruClassProgress(
              classItem: classItemByCode[k.kodeKelas]!,
              studentCount: studentCountByCode[k.kodeKelas] ?? 0,
              taskCount: taskCountByCode[k.kodeKelas] ?? 0,
              submissionCount: submissionsByCode[k.kodeKelas] ?? 0,
              expectedSubmissions: expectedByCode[k.kodeKelas] ?? 0,
            ),
        ]..sort((a, b) {
          final ra = a.completionRate;
          final rb = b.completionRate;
          if (ra != null && rb != null) return ra.compareTo(rb);
          if (ra != null) return -1;
          if (rb != null) return 1;
          return b.submissionCount.compareTo(a.submissionCount);
        });

    final dailyBuckets = [
      for (var i = 0; i < 7; i++)
        () {
          final date = DateTime(today.year, today.month, today.day - (6 - i));
          return DailySubmissionBucket(
            date: date,
            label: weekdayLabels[date.weekday - 1],
            count: dailyCounts[i],
            isToday: i == 6,
          );
        }(),
    ];

    _totalGuruStudents = uniqueStudentIds.length + anonymousStudents;
    _totalGuruSubmissions = submissionTotal;
    _totalGuruExpected = expectedTotal;
    _totalGuruMissing = missingTotal;
    _recent7DaysSubmissions = dailyCounts.fold<int>(0, (s, c) => s + c);
    _todaySubmissions = dailyCounts.last;
    _withAttachmentCount = withAttachment;
    _markAsDoneCount = markAsDone;
    _classProgressList = classProgress;
    _dailySubmissions = dailyBuckets;
    _guruSubmissions = summaries;
    _safeNotify();
  }

  Future<void> _loadMuridSummary(int seq) async {
    final kelasCtrl = kelasController;
    final pengajarCtrl = pengajarController;
    await Future.wait([
      if (kelasCtrl != null) kelasCtrl.getListKelas(),
      if (pengajarCtrl != null) pengajarCtrl.getListKelas(),
    ]);
    if (_disposed || seq != _loadSeq || kelasCtrl == null) return;

    final enrolled = kelasCtrl.listKelas.where((k) => !k.guru).toList();
    final scoped = enrolled.take(maxSummaryClasses).toList();

    final tugasBatches = await Future.wait([
      for (final k in scoped) kelasCtrl.getListTugas(k.kodeKelas),
    ]);
    if (_disposed || seq != _loadSeq) return;

    final allTasks = <({ClassItem item, km.PostinganModel post})>[];
    for (var i = 0; i < scoped.length; i++) {
      final (tugasList, _) = tugasBatches[i];
      if (tugasList == null) continue;
      final item = scoped[i].toClassItem(coverIndex: i);
      for (final t in tugasList) {
        allTasks.add((item: item, post: t));
      }
    }

    allTasks.sort((a, b) => b.post.dibuat.compareTo(a.post.dibuat));
    final checkedTasks = allTasks.take(maxCheckedTasks).toList();

    final statusResults = await Future.wait([
      for (final entry in checkedTasks)
        kelasCtrl.getPengumpulanTugas(entry.item.code, entry.post.id),
    ]);
    if (_disposed || seq != _loadSeq) return;

    var pending = 0;
    final summaries = <MuridTaskSummary>[];
    for (var i = 0; i < checkedTasks.length; i++) {
      final (submission, _) = statusResults[i];
      final submitted = submission?.submitted ?? false;
      if (!submitted) pending++;
      summaries.add(
        MuridTaskSummary(
          classItem: checkedTasks[i].item,
          post: checkedTasks[i].post,
          submitted: submitted,
          nilai: submission?.nilai,
        ),
      );
    }

    summaries.sort((a, b) {
      if (a.submitted != b.submitted) {
        return a.submitted ? 1 : -1;
      }
      return b.post.dibuat.compareTo(a.post.dibuat);
    });

    _totalMuridTugas = allTasks.length;
    _pendingMuridTugas = pending;
    _muridTasks = summaries;
    _safeNotify();
  }

  List<ClassItem> _mapItems(List<km.KelasModel> models) {
    return [
      for (var i = 0; i < models.length; i++)
        models[i].toClassItem(coverIndex: i),
    ];
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void _handleDependencyChanged() {
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    kelasController?.removeListener(_handleDependencyChanged);
    pengajarController?.removeListener(_handleDependencyChanged);
    super.dispose();
  }
}
