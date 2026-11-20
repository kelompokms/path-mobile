import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/dashboard/dashboard_controller.dart';
import 'package:path_mobile/ui/dashboard/dashboard_widgets.dart';
import 'package:path_mobile/ui/dashboard/guru_stats_widgets.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';

export 'dashboard_models.dart';
export 'dashboard_widgets.dart';
export 'guru_stats_widgets.dart';

/// Role-specific Home dashboard:
/// - `isGuruRole == true` (`Beranda Guru`): teaching summary, active assignments &
///   recent submissions to review, upcoming school agendas, and taught class shortcuts.
/// - `isGuruRole == false` (`Beranda Murid`): learning summary, pending/recent class tasks,
///   upcoming school agendas, enrolled class shortcuts, and adaptive `Asisten` section
///   if promoted in any class (`k.guru == true`).
class DashboardScreen extends StatefulWidget {
  final DashboardController? controller;
  final KelasController? kelasController;
  final PengajarController? pengajarController;
  final KalenderRepository? kalenderRepository;
  final bool isGuruRole;
  final VoidCallback? onOpenAllClasses;
  final VoidCallback? onOpenCalendar;

  const DashboardScreen({
    super.key,
    this.controller,
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
  DashboardController? _ownedController;

  DashboardController get _controller =>
      widget.controller ?? _ownedController!;

  DashboardController _createOwnedController() {
    return DashboardController(
      kelasController: widget.kelasController,
      pengajarController: widget.pengajarController,
      kalenderRepository: widget.kalenderRepository,
      isGuruRole: widget.isGuruRole,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = _createOwnedController();
    }
    _controller.refreshSummary();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    var shouldRefresh = false;

    if (widget.controller != oldWidget.controller) {
      _ownedController?.dispose();
      _ownedController = widget.controller == null
          ? _createOwnedController()
          : null;
      shouldRefresh = true;
    } else if (widget.controller == null &&
        (oldWidget.isGuruRole != widget.isGuruRole ||
            oldWidget.kelasController != widget.kelasController ||
            oldWidget.pengajarController != widget.pengajarController ||
            oldWidget.kalenderRepository != widget.kalenderRepository)) {
      _ownedController?.dispose();
      _ownedController = _createOwnedController();
      shouldRefresh = true;
    }

    if (shouldRefresh) {
      final ctrl = _controller;
      Future<void>.microtask(() {
        if (mounted && _controller == ctrl) {
          ctrl.refreshSummary();
        }
      });
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  void _openTeachingDetail(ClassItem item) {
    openPage(
      context,
      breadcrumb: ['Beranda', item.title],
      page: PengajarDetailScreen(
        classData: item,
        controller: _controller.pengajarController,
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
        controller: _controller.kelasController,
        initialTab: initialTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return PageFrame(
      breadcrumb: const ['Beranda'],
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final hPad = responsiveHorizontalInset(
                width,
                maxWidth: ResponsiveBreakpoints.wide,
              );

              return RefreshIndicator(
                onRefresh: ctrl.refreshSummary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
                  child: ctrl.isGuruRole
                      ? _buildGuruDashboard(context, ctrl, width)
                      : _buildMuridDashboard(context, ctrl, width),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGuruDashboard(
    BuildContext context,
    DashboardController ctrl,
    double width,
  ) {
    final teachingItems = ctrl.teachingItems;
    final overallRate = ctrl.overallSubmissionRate;
    final rateValue = overallRate != null
        ? '${(overallRate * 100).round()}%'
        : (ctrl.totalGuruSubmissions > 0 ? '${ctrl.totalGuruSubmissions}' : '—');
    final rateSubtitle = overallRate != null
        ? '${ctrl.totalGuruSubmissions}/${ctrl.totalGuruExpected} kiriman'
        : (ctrl.guruSubmissions.isEmpty
              ? 'Belum ada tugas'
              : '${ctrl.totalGuruSubmissions} kiriman masuk');

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
        value: '${ctrl.totalGuruMissing}',
        subtitle: ctrl.totalGuruMissing > 0
            ? 'Perlu tindak lanjut'
            : (ctrl.totalGuruExpected > 0
                  ? 'Semua terkumpul'
                  : 'Belum ada data murid'),
        icon: Icons.pending_actions_outlined,
        accentColor: ctrl.totalGuruMissing > 0
            ? AppColors.error
            : AppColors.success,
      ),
      DashboardStatCard(
        title: 'Kiriman 7 Hari',
        value: ctrl.recent7DaysSubmissions > 0
            ? '+${ctrl.recent7DaysSubmissions}'
            : '0',
        subtitle: ctrl.todaySubmissions > 0
            ? '${ctrl.todaySubmissions} masuk hari ini'
            : 'Minggu terakhir',
        icon: Icons.trending_up_outlined,
        accentColor: const Color(0xFF8E54E9),
      ),
      DashboardStatCard(
        title: 'Total Murid',
        value: '${ctrl.totalGuruStudents}',
        subtitle: teachingItems.isEmpty
            ? 'Belum ada kelas'
            : 'Di ${teachingItems.length} kelas diampu',
        icon: Icons.groups_outlined,
        accentColor: AppColors.color1,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RoleHeader(
          title: 'Beranda Guru',
          subtitle:
              'Statistik partisipasi kelas, progres pengumpulan tugas, dan agenda sekolah',
        ),
        const SizedBox(height: 12),
        if (ctrl.showGuruInitialLoader)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          StatCardsLayout(cards: stats, width: width),
          if (ctrl.classProgressList.isNotEmpty ||
              ctrl.dailySubmissions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeaderRow(title: 'Statistik Pengumpulan'),
            const SizedBox(height: 8),
            GuruStatsPanel(
              width: width,
              classProgress: ctrl.classProgressList,
              dailySubmissions: ctrl.dailySubmissions,
              withAttachmentCount: ctrl.withAttachmentCount,
              markAsDoneCount: ctrl.markAsDoneCount,
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
        if (ctrl.guruSubmissions.isEmpty)
          const EmptyNoticeBox(
            message: 'Belum ada tugas di kelas yang Anda ampu',
          )
        else
          for (final item in ctrl.guruSubmissions)
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
                  controller: ctrl.pengajarController,
                ),
                routeName: 'pengumpulan-penilaian',
              ),
            ),
        if (ctrl.hasKalender) ...[
          const SizedBox(height: 20),
          AgendaPreviewBlock(
            agendas: ctrl.upcomingAgendas,
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
            message:
                'Anda belum ditugaskan mengampu kelas. Admin dapat menunjuk pengampu melalui menu admin.',
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

  Widget _buildMuridDashboard(
    BuildContext context,
    DashboardController ctrl,
    double width,
  ) {
    final enrolledItems = ctrl.enrolledItems;
    final assistantItems = ctrl.assistantItems;
    final isAssistant = ctrl.isAssistant;

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
        value: '${ctrl.totalMuridTugas}',
        subtitle: 'Dari kelas diikuti',
        icon: Icons.assignment_outlined,
        accentColor: const Color(0xFF8E54E9),
      ),
      DashboardStatCard(
        title: 'Belum Dikumpul',
        value: '${ctrl.pendingMuridTugas}',
        subtitle: ctrl.pendingMuridTugas > 0 ? 'Perlu dikerjakan' : 'Semua aman',
        icon: Icons.pending_actions_outlined,
        accentColor: ctrl.pendingMuridTugas > 0
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
          value: '${ctrl.upcomingAgendas.length}',
          subtitle: 'Kalender sekolah',
          icon: Icons.event_note_outlined,
          accentColor: const Color(0xFFE09F00),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RoleHeader(
          title: 'Beranda Murid',
          subtitle:
              'Pantau tugas yang belum dikumpulkan, jadwal agenda sekolah, dan akses cepat ke kelas Anda',
        ),
        const SizedBox(height: 12),
        if (ctrl.showMuridInitialLoader)
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
        if (ctrl.muridTasks.isEmpty)
          const EmptyNoticeBox(
            message: 'Belum ada tugas dari kelas yang Anda ikuti',
          )
        else
          for (final task in ctrl.muridTasks)
            SummaryListCard(
              key: ValueKey(
                'murid_task_${task.classItem.code}_${task.post.id}',
              ),
              title: task.post.judul,
              subtitle:
                  '${task.classItem.title} • ${formatTanggal(task.post.dibuat)}',
              badgeLabel: task.nilai != null
                  ? 'Nilai: ${task.nilai}/100'
                  : (task.submitted ? 'Dikumpulkan' : 'Belum Dikumpul'),
              badgeColor: task.nilai != null
                  ? AppColors.color1
                  : (task.submitted ? AppColors.success : AppColors.error),
              icon: Icons.assignment_outlined,
              onTap: () => _openStudentDetail(task.classItem, initialTab: 1),
            ),
        if (ctrl.hasKalender) ...[
          const SizedBox(height: 20),
          AgendaPreviewBlock(
            agendas: ctrl.upcomingAgendas,
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
            message:
                'Anda belum bergabung ke kelas manapun. Buka tab Kelas untuk bergabung dengan kode kelas.',
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
