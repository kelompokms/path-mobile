import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart' as km;
import 'package:path_mobile/data/pengajar/pengajar_model.dart' as pm;
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/dashboard/dashboard_widgets.dart';
import 'package:path_mobile/ui/dashboard/guru_stats_widgets.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/date_time_helper.dart';

export 'dashboard_widgets.dart';
export 'guru_stats_widgets.dart';

/// Role-specific Home dashboard:
/// - `isGuruRole == true` (`Beranda Guru`): teaching summary, active assignments &
///   recent submissions to review, upcoming school agendas, and taught class shortcuts.
/// - `isGuruRole == false` (`Beranda Murid`): learning summary, pending/recent class tasks,
///   upcoming school agendas, enrolled class shortcuts, and adaptive `Asisten` section
///   if promoted in any class (`k.guru == true`).
class DashboardScreen extends StatefulWidget {
  final KelasController? kelasController;
  final PengajarController? pengajarController;
  final KalenderRepository? kalenderRepository;
  final bool isGuruRole;
  final VoidCallback? onOpenAllClasses;
  final VoidCallback? onOpenCalendar;

  const DashboardScreen({
    super.key,
    this.kelasController,
    this.pengajarController,
    this.kalenderRepository,
    this.isGuruRole = false,
    this.onOpenAllClasses,
    this.onOpenCalendar,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _maxSummaryClasses = 6;
  static const int _maxCheckedTasks = 8;
  static const List<String> _weekdayLabels = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

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

  @override
  void initState() {
    super.initState();
    _refreshSummary();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuruRole != widget.isGuruRole ||
        oldWidget.kelasController != widget.kelasController ||
        oldWidget.pengajarController != widget.pengajarController ||
        oldWidget.kalenderRepository != widget.kalenderRepository) {
      _refreshSummary();
    }
  }

  Future<void> _refreshSummary() async {
    final seq = ++_loadSeq;
    setState(() => _isLoadingSummary = true);

    await Future.wait([
      _loadClassData(seq),
      _loadAgendaPreview(seq),
    ]);

    if (!mounted || seq != _loadSeq) return;
    setState(() => _isLoadingSummary = false);
  }

  Future<void> _loadAgendaPreview(int seq) async {
    final repo = widget.kalenderRepository;
    if (repo == null) return;
    final (list, err) = await repo.getKalenderAkademik();
    if (!mounted || seq != _loadSeq || err != null || list == null) return;

    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming = list.where((e) {
      final end = DateTime(
        e.tanggalSelesai.year,
        e.tanggalSelesai.month,
        e.tanggalSelesai.day,
      );
      return !end.isBefore(today);
    }).toList()..sort((a, b) => a.tanggalMulai.compareTo(b.tanggalMulai));

    setState(() {
      _upcomingAgendas = upcoming.take(3).toList();
    });
  }

  Future<void> _loadClassData(int seq) async {
    if (widget.isGuruRole) {
      await _loadGuruSummary(seq);
    } else {
      await _loadMuridSummary(seq);
    }
  }

  Future<void> _loadGuruSummary(int seq) async {
    final pengajarCtrl = widget.pengajarController;
    final kelasCtrl = widget.kelasController;
    await Future.wait([
      if (pengajarCtrl != null) pengajarCtrl.getListKelas(),
      if (kelasCtrl != null) kelasCtrl.getListKelas(),
    ]);
    if (!mounted || seq != _loadSeq || pengajarCtrl == null) return;

    final teaching = pengajarCtrl.listKelas.where((k) => k.guru).toList();
    final scoped = teaching.take(_maxSummaryClasses).toList();

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
    if (!mounted || seq != _loadSeq) return;

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
    final checkedTasks = allTasks.take(_maxCheckedTasks).toList();

    final submissionResults = await Future.wait([
      for (final entry in checkedTasks)
        pengajarCtrl.listPengumpulanTugas(entry.item.code, entry.post.id),
    ]);
    if (!mounted || seq != _loadSeq) return;

    final today = DateUtils.dateOnly(nowGmt7());
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
          final day = DateUtils.dateOnly(submittedAt);
          final diffDays = today.difference(day).inDays;
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
          final date = today.subtract(Duration(days: 6 - i));
          return DailySubmissionBucket(
            date: date,
            label: _weekdayLabels[date.weekday - 1],
            count: dailyCounts[i],
            isToday: i == 6,
          );
        }(),
    ];

    setState(() {
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
    });
  }

  Future<void> _loadMuridSummary(int seq) async {
    final kelasCtrl = widget.kelasController;
    final pengajarCtrl = widget.pengajarController;
    await Future.wait([
      if (kelasCtrl != null) kelasCtrl.getListKelas(),
      if (pengajarCtrl != null) pengajarCtrl.getListKelas(),
    ]);
    if (!mounted || seq != _loadSeq || kelasCtrl == null) return;

    final enrolled = kelasCtrl.listKelas.where((k) => !k.guru).toList();
    final scoped = enrolled.take(_maxSummaryClasses).toList();

    final tugasBatches = await Future.wait([
      for (final k in scoped) kelasCtrl.getListTugas(k.kodeKelas),
    ]);
    if (!mounted || seq != _loadSeq) return;

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
    final checkedTasks = allTasks.take(_maxCheckedTasks).toList();

    final statusResults = await Future.wait([
      for (final entry in checkedTasks)
        kelasCtrl.getPengumpulanTugas(entry.item.code, entry.post.id),
    ]);
    if (!mounted || seq != _loadSeq) return;

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
        ),
      );
    }

    summaries.sort((a, b) {
      if (a.submitted != b.submitted) {
        return a.submitted ? 1 : -1;
      }
      return b.post.dibuat.compareTo(a.post.dibuat);
    });

    setState(() {
      _totalMuridTugas = allTasks.length;
      _pendingMuridTugas = pending;
      _muridTasks = summaries;
    });
  }

  List<ClassItem> _mapItems(List<km.KelasModel> models) {
    return [
      for (var i = 0; i < models.length; i++)
        models[i].toClassItem(coverIndex: i),
    ];
  }

  void _openTeachingDetail(ClassItem item) {
    openPage(
      context,
      breadcrumb: ['Beranda', item.title],
      page: PengajarDetailScreen(
        classData: item,
        controller: widget.pengajarController,
        breadcrumbRoot: 'Beranda',
      ),
      routeName: 'pengajar-detail',
    );
  }

  void _openStudentDetail(ClassItem item, {int initialTab = 0}) {
    openPage(
      context,
      breadcrumb: ['Beranda', item.title],
      page: ClassDetailScreen(
        classData: item,
        breadcrumb: ['Beranda', item.title],
        controller: widget.kelasController,
        initialTab: initialTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      if (widget.kelasController != null) widget.kelasController!,
      if (widget.pengajarController != null) widget.pengajarController!,
    ];

    Widget buildBody(BuildContext context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final hPad = responsiveHorizontalInset(
            width,
            maxWidth: ResponsiveBreakpoints.wide,
          );

          return RefreshIndicator(
            onRefresh: _refreshSummary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              child: widget.isGuruRole
                  ? _buildGuruDashboard(context, width)
                  : _buildMuridDashboard(context, width),
            ),
          );
        },
      );
    }

    return PageFrame(
      breadcrumb: const ['Beranda'],
      child: listenables.isEmpty
          ? buildBody(context)
          : ListenableBuilder(
              listenable: Listenable.merge(listenables),
              builder: (context, _) => buildBody(context),
            ),
    );
  }

  Widget _buildGuruDashboard(BuildContext context, double width) {
    final teachingModels =
        widget.pengajarController?.listKelas.where((k) => k.guru).toList() ??
        const <km.KelasModel>[];
    final teachingItems = _mapItems(teachingModels);

    final overallRate = _totalGuruExpected > 0
        ? (_totalGuruSubmissions / _totalGuruExpected).clamp(0.0, 1.0)
        : null;
    final rateValue = overallRate != null
        ? '${(overallRate * 100).round()}%'
        : (_totalGuruSubmissions > 0 ? '$_totalGuruSubmissions' : '—');
    final rateSubtitle = overallRate != null
        ? '$_totalGuruSubmissions/$_totalGuruExpected kiriman'
        : (_guruSubmissions.isEmpty
              ? 'Belum ada tugas'
              : '$_totalGuruSubmissions kiriman masuk');

    final stats = [
      DashboardStatCard(
        title: 'Tingkat Pengumpulan',
        value: rateValue,
        subtitle: rateSubtitle,
        icon: Icons.pie_chart_outline,
        accentColor: overallRate != null
            ? guruProgressColor(overallRate)
            : AppColors.color1,
      ),
      DashboardStatCard(
        title: 'Belum Kumpul',
        value: '$_totalGuruMissing',
        subtitle: _totalGuruMissing > 0
            ? 'Perlu tindak lanjut'
            : (_totalGuruExpected > 0
                  ? 'Semua terkumpul'
                  : 'Belum ada data murid'),
        icon: Icons.pending_actions_outlined,
        accentColor: _totalGuruMissing > 0
            ? AppColors.error
            : AppColors.success,
      ),
      DashboardStatCard(
        title: 'Kiriman 7 Hari',
        value: _recent7DaysSubmissions > 0 ? '+$_recent7DaysSubmissions' : '0',
        subtitle: _todaySubmissions > 0
            ? '$_todaySubmissions masuk hari ini'
            : 'Minggu terakhir',
        icon: Icons.trending_up_outlined,
        accentColor: const Color(0xFF8E54E9),
      ),
      DashboardStatCard(
        title: 'Total Murid',
        value: '$_totalGuruStudents',
        subtitle: teachingItems.isEmpty
            ? 'Belum ada kelas'
            : 'Di ${teachingItems.length} kelas diampu',
        icon: Icons.groups_outlined,
        accentColor: AppColors.color1,
      ),
    ];

    final showInitialLoader =
        _isLoadingSummary && teachingItems.isEmpty && _guruSubmissions.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RoleHeader(
          title: 'Beranda Guru',
          subtitle: 'Statistik partisipasi kelas, progres pengumpulan tugas, dan agenda sekolah',
        ),
        const SizedBox(height: 12),
        if (showInitialLoader)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          StatCardsLayout(cards: stats, width: width),
          if (_classProgressList.isNotEmpty ||
              _dailySubmissions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeaderRow(title: 'Statistik Pengumpulan'),
            const SizedBox(height: 8),
            GuruStatsPanel(
              width: width,
              classProgress: _classProgressList,
              dailySubmissions: _dailySubmissions,
              withAttachmentCount: _withAttachmentCount,
              markAsDoneCount: _markAsDoneCount,
              onTapClass: _openTeachingDetail,
            ),
          ],
        ],
        const SizedBox(height: 20),
        SectionHeaderRow(
          title: 'Monitoring Pengumpulan Tugas',
          actionLabel: widget.onOpenAllClasses != null ? 'Kelola Kelas' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (_guruSubmissions.isEmpty)
          const EmptyNoticeBox(
            message: 'Belum ada tugas di kelas yang Anda ampu',
          )
        else
          for (final item in _guruSubmissions)
            SummaryListCard(
              key: ValueKey(
                'guru_submission_${item.classItem.code}_${item.post.id}',
              ),
              title: item.post.judul,
              subtitle: item.latestStudentName.isNotEmpty
                  ? '${item.classItem.title} • Terbaru: ${item.latestStudentName}'
                  : '${item.classItem.title} • ${formatTanggal(item.post.dibuat)}',
              badgeLabel: item.totalStudents > 0
                  ? '${item.submissionCount}/${item.totalStudents} murid'
                  : (item.submissionCount > 0
                        ? '${item.submissionCount} kumpul'
                        : 'Belum ada'),
              badgeColor: item.completionRate != null
                  ? guruProgressColor(item.completionRate)
                  : (item.submissionCount > 0
                        ? AppColors.success
                        : AppColors.secondaryText),
              progress: item.completionRate,
              progressColor: guruProgressColor(item.completionRate),
              icon: Icons.assignment_turned_in_outlined,
              onTap: () => openPage(
                context,
                breadcrumb: ['Beranda', item.classItem.title, item.post.judul],
                page: PengumpulanPenilaianScreen(
                  classData: item.classItem,
                  postinganId: item.post.id,
                  tugasTitle: item.post.judul,
                  controller: widget.pengajarController,
                ),
                routeName: 'pengumpulan-penilaian',
              ),
            ),
        if (widget.kalenderRepository != null) ...[
          const SizedBox(height: 20),
          AgendaPreviewBlock(
            agendas: _upcomingAgendas,
            onOpenCalendar: widget.onOpenCalendar,
          ),
        ],
        const SizedBox(height: 20),
        SectionHeaderRow(
          title: 'Kelas yang Diampu',
          actionLabel: widget.onOpenAllClasses != null ? 'Lihat Semua' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (teachingItems.isEmpty)
          const EmptyNoticeBox(
            message: 'Anda belum ditugaskan mengampu kelas. Admin dapat menunjuk pengampu melalui menu admin.',
          )
        else
          EmbeddedClassGrid(
            items: teachingItems,
            width: width,
            onTapItem: _openTeachingDetail,
          ),
      ],
    );
  }

  Widget _buildMuridDashboard(BuildContext context, double width) {
    final enrolledModels =
        widget.kelasController?.listKelas.where((k) => !k.guru).toList() ??
        const <km.KelasModel>[];
    final assistantModels =
        widget.pengajarController?.listKelas.where((k) => k.guru).toList() ??
        const <km.KelasModel>[];

    final enrolledItems = _mapItems(enrolledModels);
    final assistantItems = _mapItems(assistantModels);
    final isAssistant = assistantItems.isNotEmpty;

    final stats = [
      DashboardStatCard(
        title: 'Kelas Diikuti',
        value: '${enrolledItems.length}',
        subtitle: enrolledItems.isEmpty
            ? 'Belum bergabung'
            : '${enrolledItems.length} kelas aktif',
        icon: Icons.book_outlined,
        accentColor: AppColors.color1,
      ),
      DashboardStatCard(
        title: 'Total Tugas',
        value: '$_totalMuridTugas',
        subtitle: 'Dari kelas diikuti',
        icon: Icons.assignment_outlined,
        accentColor: const Color(0xFF8E54E9),
      ),
      DashboardStatCard(
        title: 'Belum Dikumpul',
        value: '$_pendingMuridTugas',
        subtitle: _pendingMuridTugas > 0 ? 'Perlu dikerjakan' : 'Semua aman',
        icon: Icons.pending_actions_outlined,
        accentColor: _pendingMuridTugas > 0
            ? AppColors.error
            : AppColors.success,
      ),
      if (isAssistant)
        DashboardStatCard(
          title: 'Didampingi',
          value: '${assistantItems.length}',
          subtitle: 'Peran asisten kelas',
          icon: Icons.co_present_outlined,
          accentColor: const Color(0xFFE09F00),
        )
      else
        DashboardStatCard(
          title: 'Agenda Terdekat',
          value: '${_upcomingAgendas.length}',
          subtitle: 'Kalender sekolah',
          icon: Icons.event_note_outlined,
          accentColor: const Color(0xFFE09F00),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleHeader(
          title: 'Beranda Murid',
          subtitle: 'Pantau tugas yang belum dikumpulkan, jadwal agenda sekolah, dan akses cepat ke kelas Anda',
        ),
        const SizedBox(height: 12),
        if (_isLoadingSummary && enrolledItems.isEmpty && _muridTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          StatCardsLayout(cards: stats, width: width),
        const SizedBox(height: 20),
        SectionHeaderRow(
          title: 'Tugas Kelas Terbaru',
          actionLabel: widget.onOpenAllClasses != null ? 'Lihat Kelas' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (_muridTasks.isEmpty)
          const EmptyNoticeBox(
            message: 'Belum ada tugas dari kelas yang Anda ikuti',
          )
        else
          for (final task in _muridTasks)
            SummaryListCard(
              key: ValueKey(
                'murid_task_${task.classItem.code}_${task.post.id}',
              ),
              title: task.post.judul,
              subtitle:
                  '${task.classItem.title} • ${formatTanggal(task.post.dibuat)}',
              badgeLabel: task.submitted ? 'Dikumpulkan' : 'Belum Dikumpul',
              badgeColor: task.submitted ? AppColors.success : AppColors.error,
              icon: Icons.assignment_outlined,
              onTap: () => _openStudentDetail(task.classItem, initialTab: 1),
            ),
        if (widget.kalenderRepository != null) ...[
          const SizedBox(height: 20),
          AgendaPreviewBlock(
            agendas: _upcomingAgendas,
            onOpenCalendar: widget.onOpenCalendar,
          ),
        ],
        if (isAssistant) ...[
          const SizedBox(height: 20),
          SectionHeaderRow(
            title: 'Kelas Didampingi (Asisten)',
            actionLabel: widget.onOpenAllClasses != null ? 'Kelola' : null,
            onAction: widget.onOpenAllClasses,
          ),
          const SizedBox(height: 8),
          EmbeddedClassGrid(
            items: assistantItems,
            width: width,
            onTapItem: _openTeachingDetail,
          ),
        ],
        const SizedBox(height: 20),
        SectionHeaderRow(
          title: 'Kelas Diikuti',
          actionLabel: widget.onOpenAllClasses != null ? 'Lihat Semua' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (enrolledItems.isEmpty)
          const EmptyNoticeBox(
            message: 'Anda belum bergabung ke kelas manapun. Buka tab Kelas untuk bergabung dengan kode kelas.',
          )
        else
          EmbeddedClassGrid(
            items: enrolledItems,
            width: width,
            onTapItem: (item) => _openStudentDetail(item),
          ),
      ],
    );
  }
}
