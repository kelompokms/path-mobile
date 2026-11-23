import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/data/kalender/kalender_repository.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/admin/admin_dashboard_widgets.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/utils/date_time_helper.dart';

export 'admin_dashboard_widgets.dart';

enum _AiRoleFilter { all, guru, siswa }

enum _AiSortOption { nama, penggunaan }

/// Admin Beranda screen displaying school statistics summary and AI usage
/// overview backed by real users from `/admin/pengguna` with randomized AI
/// usage counts until backend AI telemetry is available.
class AdminDashboardScreen extends StatefulWidget {
  final AdminController controller;
  final KalenderRepository? kalenderRepository;
  final math.Random? random;

  const AdminDashboardScreen({
    super.key,
    required this.controller,
    this.kalenderRepository,
    this.random,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _guruColor = AppColors.color1;
  static const Color _siswaColor = Color(0xFF8E54E9);
  static const Color _eventColor = Color(0xFF34C759);

  int _eventCount = 0;

  _AiRoleFilter _roleFilter = _AiRoleFilter.all;
  _AiSortOption _sortOption = _AiSortOption.nama;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        _refresh();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      Future<void>.microtask(() {
        if (mounted) {
          _refresh();
        }
      });
    }
  }

  Future<void> _refresh({bool showRefreshError = false}) async {
    await Future.wait([
      widget.controller.loadUsers(),
      widget.controller.loadAiUsage(),
      widget.controller.loadAiOpsUsage(),
      _loadEvents(),
    ]);
    if (showRefreshError &&
        mounted &&
        widget.controller.usersError != null &&
        (widget.controller.guruList.isNotEmpty ||
            widget.controller.muridList.isNotEmpty)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.controller.usersError!)));
    }
  }

  Future<void> _loadEvents() async {
    final repo = widget.kalenderRepository;
    if (repo == null) return;
    final (events, err) = await repo.getKalenderAkademik();
    if (!mounted || err != null || events == null) return;
    final now = nowGmt7();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(
      now.year,
      now.month,
      DateUtils.getDaysInMonth(now.year, now.month),
    );
    final inCurrentMonth = events.where((e) {
      final start = DateTime(
        e.tanggalMulai.year,
        e.tanggalMulai.month,
        e.tanggalMulai.day,
      );
      final end = DateTime(
        e.tanggalSelesai.year,
        e.tanggalSelesai.month,
        e.tanggalSelesai.day,
      );
      return !start.isAfter(monthEnd) && !end.isBefore(monthStart);
    }).length;
    setState(() {
      _eventCount = inCurrentMonth;
    });
  }

  int _usageFor(AdminPenggunaModel user) {
    return widget.controller.aiUsageByUserId[user.id] ?? 0;
  }

  String _buildDetail(AdminPenggunaModel user, {required bool isGuru}) {
    if (user.kelas.isNotEmpty) {
      return isGuru
          ? 'Mengampu: ${user.kelas.join(', ')}'
          : 'Kelas: ${user.kelas.join(', ')}';
    }
    if (user.email.isNotEmpty) {
      return user.email;
    }
    return isGuru ? 'Belum mengampu kelas' : 'Belum bergabung kelas';
  }

  List<AiUsageItem> _buildAllUsageItems() {
    final ctrl = widget.controller;
    return [
      for (final guru in ctrl.guruList)
        AiUsageItem(
          nama: guru.nama.isNotEmpty ? guru.nama : 'Tanpa Nama',
          isGuru: true,
          detail: _buildDetail(guru, isGuru: true),
          aiUsage: _usageFor(guru),
          profilePicture: guru.profilePicture,
        ),
      for (final murid in ctrl.muridList)
        AiUsageItem(
          nama: murid.nama.isNotEmpty ? murid.nama : 'Tanpa Nama',
          isGuru: false,
          detail: _buildDetail(murid, isGuru: false),
          aiUsage: _usageFor(murid),
          profilePicture: murid.profilePicture,
        ),
    ];
  }

  List<AiUsageItem> _filterAndSort(List<AiUsageItem> source) {
    final items = source.where((item) {
      return switch (_roleFilter) {
        _AiRoleFilter.all => true,
        _AiRoleFilter.guru => item.isGuru,
        _AiRoleFilter.siswa => !item.isGuru,
      };
    }).toList();

    switch (_sortOption) {
      case _AiSortOption.nama:
        items.sort(
          (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()),
        );
      case _AiSortOption.penggunaan:
        items.sort((a, b) => b.aiUsage.compareTo(a.aiUsage));
    }
    return items;
  }

  void _toggleRole(_AiRoleFilter tapped) {
    setState(() {
      _roleFilter = _roleFilter == tapped ? _AiRoleFilter.all : tapped;
    });
  }

  String _formatTokenCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthName = formatBulanTahun(nowGmt7()).split(' ').first;

    return PageFrame(
      breadcrumb: const ['Admin'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final allItems = _buildAllUsageItems();
          final items = _filterAndSort(allItems);

          final guruCount = ctrl.guruList.length;
          final siswaCount = ctrl.muridList.length;
          final guruAiTotal = allItems
              .where((i) => i.isGuru)
              .fold<int>(0, (sum, item) => sum + item.aiUsage);
          final siswaAiTotal = allItems
              .where((i) => !i.isGuru)
              .fold<int>(0, (sum, item) => sum + item.aiUsage);
          final totalAiUsage = guruAiTotal + siswaAiTotal;

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final hPad = responsiveHorizontalInset(width, maxWidth: 900);
              final fourCol = width >= 820;

              final statCards = [
                StatSummaryCard(
                  title: 'Total Guru',
                  value: '$guruCount Guru',
                  badgeLabel: 'Pakai AI: ${guruAiTotal}x',
                  badgeColor: _guruColor,
                ),
                StatSummaryCard(
                  title: 'Total Siswa',
                  value: '$siswaCount Siswa',
                  badgeLabel: 'Pakai AI: ${siswaAiTotal}x',
                  badgeColor: _siswaColor,
                ),
                StatSummaryCard(
                  title: 'Total Pakai AI (Semua)',
                  value: '$totalAiUsage Kali',
                  badgeLabel: 'Bulan ini',
                  badgeColor: AppColors.error,
                ),
                StatSummaryCard(
                  title: 'Total Event',
                  value: '$_eventCount Event',
                  badgeLabel: currentMonthName,
                  badgeColor: _eventColor,
                ),
              ];

              return RefreshIndicator(
                onRefresh: () => _refresh(showRefreshError: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Rangkuman Statistik Sekolah',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (fourCol)
                        Row(
                          children: [
                            for (var i = 0; i < statCards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: statCards[i]),
                            ],
                          ],
                        )
                      else ...[
                        StatRowPair(left: statCards[0], right: statCards[1]),
                        const SizedBox(height: 12),
                        StatRowPair(left: statCards[2], right: statCards[3]),
                      ],
                      if (ctrl.aiOpsUsage != null) ...[
                        const SizedBox(height: 12),
                        StatRowPair(
                          left: StatSummaryCard(
                            title: 'Sisa Token AI',
                            value:
                                '${_formatTokenCount(ctrl.aiOpsUsage!.budgetRemaining)} / ${_formatTokenCount(ctrl.aiOpsUsage!.budgetLimit)}',
                            badgeLabel:
                                'Terpakai: ${_formatTokenCount(ctrl.aiOpsUsage!.budgetUsed)}',
                            badgeColor: _guruColor,
                          ),
                          right: StatSummaryCard(
                            title: 'Kuota Model Gratis',
                            value:
                                '${ctrl.aiOpsUsage!.freeRemaining} / ${ctrl.aiOpsUsage!.freeLimit}',
                            badgeLabel:
                                'Terpakai: ${ctrl.aiOpsUsage!.freeUsed}x',
                            badgeColor: _eventColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Ringkasan Penggunaan AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 170,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Urutkan berdasarkan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                DropdownButton<_AiSortOption>(
                                  value: _sortOption,
                                  isExpanded: true,
                                  isDense: true,
                                  underline: Container(
                                    height: 1,
                                    color: AppColors.text.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: _AiSortOption.nama,
                                      child: Text('Nama'),
                                    ),
                                    DropdownMenuItem(
                                      value: _AiSortOption.penggunaan,
                                      child: Text('Penggunaan AI'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _sortOption = v);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              RoleFilterChip(
                                key: const Key('admin_ai_filter_guru'),
                                label: 'Guru',
                                color: _guruColor,
                                selected: _roleFilter == _AiRoleFilter.guru,
                                dimmed: _roleFilter == _AiRoleFilter.siswa,
                                onTap: () => _toggleRole(_AiRoleFilter.guru),
                              ),
                              RoleFilterChip(
                                key: const Key('admin_ai_filter_siswa'),
                                label: 'Siswa',
                                color: _siswaColor,
                                selected: _roleFilter == _AiRoleFilter.siswa,
                                dimmed: _roleFilter == _AiRoleFilter.guru,
                                onTap: () => _toggleRole(_AiRoleFilter.siswa),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (ctrl.isLoadingUsers && allItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (ctrl.usersError != null && allItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Text(
                                ctrl.usersError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _refresh,
                                style: AppTheme.softCompactButton,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      else if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            allItems.isEmpty
                                ? 'Belum ada pengguna terdaftar'
                                : 'Tidak ada pengguna sesuai filter',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.black26,
                            ),
                          AiUsageRow(
                            item: items[i],
                            accentColor: items[i].isGuru
                                ? _guruColor
                                : _siswaColor,
                            baseUrl: ctrl.baseUrl,
                          ),
                        ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
