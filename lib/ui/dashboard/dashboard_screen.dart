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
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/list_pengumpulan_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';

class _GuruSubmissionSummary {
  final ClassItem classItem;
  final km.PostinganModel post;
  final int submissionCount;
  final String latestStudentName;

  const _GuruSubmissionSummary({
    required this.classItem,
    required this.post,
    required this.submissionCount,
    this.latestStudentName = '',
  });
}

class _MuridTaskSummary {
  final ClassItem classItem;
  final km.PostinganModel post;
  final bool submitted;

  const _MuridTaskSummary({
    required this.classItem,
    required this.post,
    required this.submitted,
  });
}

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
  static const int _maxCheckedTasks = 6;

  bool _isLoadingSummary = false;
  int _loadSeq = 0;

  int _totalGuruMateri = 0;
  int _totalGuruTugas = 0;
  int _totalGuruSubmissions = 0;
  List<_GuruSubmissionSummary> _guruSubmissions = const [];

  int _totalMuridTugas = 0;
  int _pendingMuridTugas = 0;
  List<_MuridTaskSummary> _muridTasks = const [];

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
    final upcoming =
        list.where((e) {
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

    var materiCount = 0;
    var tugasCount = 0;
    final allTasks = <({ClassItem item, pm.PostinganModel post})>[];

    final postBatches = await Future.wait([
      for (var i = 0; i < scoped.length; i++)
        Future.wait([
          pengajarCtrl.getListMateri(scoped[i].kodeKelas),
          pengajarCtrl.getListTugas(scoped[i].kodeKelas),
        ]),
    ]);
    if (!mounted || seq != _loadSeq) return;

    for (var i = 0; i < scoped.length; i++) {
      final (materiList, _) = postBatches[i][0];
      final (tugasList, _) = postBatches[i][1];
      materiCount += materiList?.length ?? 0;
      tugasCount += tugasList?.length ?? 0;
      final item = scoped[i].toClassItem(coverIndex: i);
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

    var submissionTotal = 0;
    final summaries = <_GuruSubmissionSummary>[];
    for (var i = 0; i < checkedTasks.length; i++) {
      final (items, _) = submissionResults[i];
      final list = items ?? const <pm.PengumpulanMuridModel>[];
      submissionTotal += list.length;
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
        _GuruSubmissionSummary(
          classItem: checkedTasks[i].item,
          post: checkedTasks[i].post,
          submissionCount: list.length,
          latestStudentName: sorted.isNotEmpty ? sorted.first.nama : '',
        ),
      );
    }

    summaries.sort((a, b) {
      if ((b.submissionCount > 0) != (a.submissionCount > 0)) {
        return b.submissionCount.compareTo(a.submissionCount);
      }
      return b.post.dibuat.compareTo(a.post.dibuat);
    });

    setState(() {
      _totalGuruMateri = materiCount;
      _totalGuruTugas = tugasCount;
      _totalGuruSubmissions = submissionTotal;
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
    final summaries = <_MuridTaskSummary>[];
    for (var i = 0; i < checkedTasks.length; i++) {
      final (submission, _) = statusResults[i];
      final submitted = submission?.submitted ?? false;
      if (!submitted) pending++;
      summaries.add(
        _MuridTaskSummary(
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

    final stats = [
      _DashboardStatCard(
        title: 'Kelas Diampu',
        value: '${teachingItems.length}',
        subtitle: teachingItems.isEmpty
            ? 'Belum ada penugasan'
            : '${teachingItems.length} kelas aktif',
        icon: Icons.school_outlined,
        accentColor: AppColors.color1,
      ),
      _DashboardStatCard(
        title: 'Total Tugas',
        value: '$_totalGuruTugas',
        subtitle: 'Pada kelas diampu',
        icon: Icons.assignment_outlined,
        accentColor: const Color(0xFF8E54E9),
      ),
      _DashboardStatCard(
        title: 'Total Materi',
        value: '$_totalGuruMateri',
        subtitle: 'Dipublikasikan',
        icon: Icons.menu_book_outlined,
        accentColor: AppColors.success,
      ),
      _DashboardStatCard(
        title: 'Pengumpulan',
        value: '$_totalGuruSubmissions',
        subtitle: 'Jawaban siswa masuk',
        icon: Icons.task_alt_outlined,
        accentColor: const Color(0xFFE09F00),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RoleHeader(
          title: 'Beranda Guru',
          badgeLabel: 'Guru',
          badgeColor: AppColors.color1,
          subtitle:
              'Ringkasan kelas yang Anda ampu, pengumpulan tugas terbaru, dan agenda sekolah',
        ),
        const SizedBox(height: 12),
        if (_isLoadingSummary &&
            teachingItems.isEmpty &&
            _guruSubmissions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _StatCardsLayout(cards: stats, width: width),
        const SizedBox(height: 20),
        _SectionHeaderRow(
          title: 'Monitoring Pengumpulan Tugas',
          actionLabel: widget.onOpenAllClasses != null ? 'Kelola Kelas' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (_guruSubmissions.isEmpty)
          const _EmptyNoticeBox(
            message: 'Belum ada tugas di kelas yang Anda ampu',
          )
        else
          for (final item in _guruSubmissions)
            _SummaryListCard(
              key: ValueKey('guru_submission_${item.classItem.code}_${item.post.id}'),
              title: item.post.judul,
              subtitle: item.latestStudentName.isNotEmpty
                  ? '${item.classItem.title} • Terbaru: ${item.latestStudentName}'
                  : '${item.classItem.title} • ${formatTanggal(item.post.dibuat)}',
              badgeLabel: item.submissionCount > 0
                  ? '${item.submissionCount} kumpul'
                  : 'Belum ada',
              badgeColor: item.submissionCount > 0
                  ? AppColors.success
                  : AppColors.secondaryText,
              icon: Icons.assignment_turned_in_outlined,
              onTap: () => openPage(
                context,
                breadcrumb: ['Beranda', item.classItem.title, item.post.judul],
                page: ListPengumpulanScreen(
                  classData: item.classItem,
                  postinganId: item.post.id,
                  tugasTitle: item.post.judul,
                  controller: widget.pengajarController,
                ),
              ),
            ),
        if (widget.kalenderRepository != null) ...[
          const SizedBox(height: 20),
          _AgendaPreviewBlock(
            agendas: _upcomingAgendas,
            onOpenCalendar: widget.onOpenCalendar,
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeaderRow(
          title: 'Kelas yang Diampu',
          actionLabel: widget.onOpenAllClasses != null ? 'Lihat Semua' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (teachingItems.isEmpty)
          const _EmptyNoticeBox(
            message:
                'Anda belum ditugaskan mengampu kelas. Admin dapat menunjuk pengampu melalui menu admin.',
          )
        else
          _EmbeddedClassGrid(
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
      _DashboardStatCard(
        title: 'Kelas Diikuti',
        value: '${enrolledItems.length}',
        subtitle: enrolledItems.isEmpty
            ? 'Belum bergabung'
            : '${enrolledItems.length} kelas aktif',
        icon: Icons.book_outlined,
        accentColor: AppColors.color1,
      ),
      _DashboardStatCard(
        title: 'Total Tugas',
        value: '$_totalMuridTugas',
        subtitle: 'Dari kelas diikuti',
        icon: Icons.assignment_outlined,
        accentColor: const Color(0xFF8E54E9),
      ),
      _DashboardStatCard(
        title: 'Belum Dikumpul',
        value: '$_pendingMuridTugas',
        subtitle: _pendingMuridTugas > 0 ? 'Perlu dikerjakan' : 'Semua aman',
        icon: Icons.pending_actions_outlined,
        accentColor: _pendingMuridTugas > 0
            ? AppColors.error
            : AppColors.success,
      ),
      if (isAssistant)
        _DashboardStatCard(
          title: 'Didampingi',
          value: '${assistantItems.length}',
          subtitle: 'Peran asisten kelas',
          icon: Icons.co_present_outlined,
          accentColor: const Color(0xFFE09F00),
        )
      else
        _DashboardStatCard(
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
        _RoleHeader(
          title: 'Beranda Murid',
          badgeLabel: isAssistant ? 'Murid • Asisten' : 'Murid',
          badgeColor: const Color(0xFF8E54E9),
          subtitle:
              'Pantau tugas yang belum dikumpulkan, jadwal agenda sekolah, dan akses cepat ke kelas Anda',
        ),
        const SizedBox(height: 12),
        if (_isLoadingSummary &&
            enrolledItems.isEmpty &&
            _muridTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _StatCardsLayout(cards: stats, width: width),
        const SizedBox(height: 20),
        _SectionHeaderRow(
          title: 'Tugas Kelas Terbaru',
          actionLabel: widget.onOpenAllClasses != null ? 'Lihat Kelas' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (_muridTasks.isEmpty)
          const _EmptyNoticeBox(
            message: 'Belum ada tugas dari kelas yang Anda ikuti',
          )
        else
          for (final task in _muridTasks)
            _SummaryListCard(
              key: ValueKey('murid_task_${task.classItem.code}_${task.post.id}'),
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
          _AgendaPreviewBlock(
            agendas: _upcomingAgendas,
            onOpenCalendar: widget.onOpenCalendar,
          ),
        ],
        if (isAssistant) ...[
          const SizedBox(height: 20),
          _SectionHeaderRow(
            title: 'Kelas Didampingi (Asisten)',
            actionLabel: widget.onOpenAllClasses != null ? 'Kelola' : null,
            onAction: widget.onOpenAllClasses,
          ),
          const SizedBox(height: 8),
          _EmbeddedClassGrid(
            items: assistantItems,
            width: width,
            onTapItem: _openTeachingDetail,
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeaderRow(
          title: 'Kelas Diikuti',
          actionLabel: widget.onOpenAllClasses != null ? 'Lihat Semua' : null,
          onAction: widget.onOpenAllClasses,
        ),
        const SizedBox(height: 8),
        if (enrolledItems.isEmpty)
          const _EmptyNoticeBox(
            message:
                'Anda belum bergabung ke kelas manapun. Buka tab Kelas untuk bergabung dengan kode kelas.',
          )
        else
          _EmbeddedClassGrid(
            items: enrolledItems,
            width: width,
            onTapItem: (item) => _openStudentDetail(item),
          ),
      ],
    );
  }
}

class _RoleHeader extends StatelessWidget {
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final String subtitle;

  const _RoleHeader({
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _StatCardsLayout extends StatelessWidget {
  final List<_DashboardStatCard> cards;
  final double width;

  const _StatCardsLayout({required this.cards, required this.width});

  @override
  Widget build(BuildContext context) {
    if (width >= 820) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeaderRow({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _SummaryListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final IconData icon;
  final VoidCallback onTap;

  const _SummaryListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.black12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final badgeWidthEstimate =
                    MediaQuery.textScalerOf(context).scale(11) *
                    badgeLabel.length;
                final stackBadge =
                    constraints.maxWidth < 300 ||
                    badgeWidthEstimate > constraints.maxWidth * 0.45;

                final textContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    if (stackBadge) ...[
                      const SizedBox(height: 6),
                      _buildBadge(),
                    ],
                  ],
                );

                return Row(
                  crossAxisAlignment: stackBadge
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: AppColors.color1),
                    const SizedBox(width: 10),
                    Expanded(child: textContent),
                    if (!stackBadge) ...[
                      const SizedBox(width: 8),
                      _buildBadge(),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        badgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}

class _AgendaPreviewBlock extends StatelessWidget {
  final List<KalenderAkademikModel> agendas;
  final VoidCallback? onOpenCalendar;

  const _AgendaPreviewBlock({required this.agendas, this.onOpenCalendar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: 'Agenda Sekolah Terdekat',
          actionLabel: onOpenCalendar != null ? 'Lihat Kalender' : null,
          onAction: onOpenCalendar,
        ),
        const SizedBox(height: 8),
        if (agendas.isEmpty)
          const _EmptyNoticeBox(message: 'Belum ada agenda sekolah mendatang')
        else
          for (final item in agendas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE09F00).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: Color(0xFF7A4F01),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaKegiatan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateUtils.isSameDay(
                                  item.tanggalMulai,
                                  item.tanggalSelesai,
                                )
                                ? formatTanggal(item.tanggalMulai)
                                : '${formatTanggal(item.tanggalMulai)} - ${formatTanggal(item.tanggalSelesai)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _EmbeddedClassGrid extends StatelessWidget {
  final List<ClassItem> items;
  final double width;
  final ValueChanged<ClassItem> onTapItem;

  const _EmbeddedClassGrid({
    required this.items,
    required this.width,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.min(width, ResponsiveBreakpoints.wide);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: responsiveClassGridDelegate(
        context,
        maxWidth,
        maxContentWidth: ResponsiveBreakpoints.wide,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => ClassCard(
        data: items[i],
        onTap: () => onTapItem(items[i]),
      ),
    );
  }
}

class _EmptyNoticeBox extends StatelessWidget {
  final String message;

  const _EmptyNoticeBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
    );
  }
}
