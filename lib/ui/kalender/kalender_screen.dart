import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kalender/agenda_widgets.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/ui/kalender/month_calendar.dart';
import 'package:path_mobile/ui/kalender/tambah_agenda_dialog.dart';

export 'agenda_widgets.dart';
export 'month_calendar.dart';
export 'tambah_agenda_dialog.dart';

class KalenderScreen extends StatefulWidget {
  final KalenderController controller;
  final bool isAdmin;

  const KalenderScreen({
    super.key,
    required this.controller,
    this.isAdmin = false,
  });

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  static const int _initialPage = 1200;

  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late final DateTime _baseMonth = DateTime(_today.year, _today.month);
  late DateTime _shownMonth = _baseMonth;
  late DateTime _selectedDate = _today;
  late final PageController _pageController = PageController(
    initialPage: _initialPage,
  );
  int _targetPage = _initialPage;
  bool? _lastIsTwoPane;

  @override
  void initState() {
    super.initState();
    widget.controller.loadAgendas();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) =>
      DateTime(_baseMonth.year, _baseMonth.month + (page - _initialPage));

  void _onPageChanged(int page) {
    _targetPage = page;
    final nextMonth = _monthForPage(page);
    if (nextMonth.year == _shownMonth.year &&
        nextMonth.month == _shownMonth.month) {
      return;
    }
    setState(() {
      _shownMonth = nextMonth;
    });
  }

  void _changeMonth(int delta) {
    final nextPage = math.max(0, _targetPage + delta);
    if (nextPage == _targetPage) return;
    _targetPage = nextPage;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() {
      _shownMonth = _monthForPage(nextPage);
    });
  }

  void _jumpToMonth(DateTime date) {
    final monthsDelta =
        (date.year - _baseMonth.year) * 12 + (date.month - _baseMonth.month);
    final nextPage = math.max(0, _initialPage + monthsDelta);
    _targetPage = nextPage;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() {
      _shownMonth = _monthForPage(nextPage);
    });
  }

  Future<void> _openAddAgendaDialog() async {
    final result = await showDialog<TambahAgendaResult>(
      context: context,
      builder: (_) => TambahAgendaDialog(initialDate: _selectedDate),
    );
    if (result == null || !mounted) return;

    final err = await widget.controller.createAgenda(
      namaEvent: result.namaEvent,
      keterangan: result.keterangan,
      tanggalMulai: result.tanggalMulai,
      tanggalSelesai: result.tanggalSelesai,
    );
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() {
      _selectedDate = result.tanggalMulai;
    });
    if (result.tanggalMulai.year != _shownMonth.year ||
        result.tanggalMulai.month != _shownMonth.month) {
      _jumpToMonth(result.tanggalMulai);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Agenda berhasil ditambahkan')),
      );
  }

  Widget _buildCalendarHeader() {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const Text(
            'Kalender',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (widget.isAdmin)
            ElevatedButton.icon(
              key: const Key('admin_add_agenda_button'),
              onPressed: _openAddAgendaDialog,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Tambah Agenda'),
              style: AppTheme.softCompactButton,
            ),
        ],
      ),
    );
  }

  void _showDayAgendaDialog(DateTime day, List<AgendaItemModel> items) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
        title: Text(
          'Agenda • ${formatTanggal(day)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                Text(
                  items[i].title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatAgendaMeta(items[i]),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (items[i].description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    items[i].description,
                    style: const TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.softCompactButton,
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final globalAgendas = widget.controller.globalAgendasByDay;
    return MonthCalendar(
      month: _shownMonth,
      today: _today,
      selectedDate: widget.isAdmin ? _selectedDate : null,
      globalAgendasByDay: globalAgendas,
      pageController: _pageController,
      monthForPage: _monthForPage,
      onPageChanged: _onPageChanged,
      onPrev: () => _changeMonth(-1),
      onNext: () => _changeMonth(1),
      onSelectDate: widget.isAdmin
          ? (day) => setState(() => _selectedDate = DateUtils.dateOnly(day))
          : null,
      onTapAgendaDay: widget.isAdmin
          ? null
          : (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              final items = globalAgendas[normalized] ?? const [];
              if (items.isNotEmpty) {
                _showDayAgendaDialog(normalized, items);
              }
            },
    );
  }

  List<MapEntry<DateTime, List<AgendaItemModel>>> get _days {
    final grouped = <DateTime, List<AgendaItemModel>>{};
    final monthStart = DateTime(_shownMonth.year, _shownMonth.month, 1);
    final monthEnd = DateTime(
      _shownMonth.year,
      _shownMonth.month,
      DateUtils.getDaysInMonth(_shownMonth.year, _shownMonth.month),
    );
    for (final item in widget.controller.agendas) {
      final start = DateTime(item.date.year, item.date.month, item.date.day);
      if (start.year == _shownMonth.year && start.month == _shownMonth.month) {
        (grouped[start] ??= []).add(item);
        continue;
      }
      final rawEnd = item.endDate;
      if (rawEnd != null &&
          (item.isGlobal || item.heading == 'Kalender Akademik')) {
        final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
        if (!start.isAfter(monthEnd) && !end.isBefore(monthStart)) {
          (grouped[monthStart] ??= []).add(item);
        }
      }
    }
    return grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Kalender'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final days = _days;

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isTwoPane = width >= 720;
              if (_lastIsTwoPane != null && _lastIsTwoPane != isTwoPane) {
                final target = _targetPage;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients) {
                    _pageController.jumpToPage(target);
                  }
                });
              }
              _lastIsTwoPane = isTwoPane;

              if (isTwoPane) {
                final hPad = responsiveHorizontalPadding(width);
                final calendarPaneWidth = math.min(
                  420.0,
                  math.max(310.0, width * 0.4),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: calendarPaneWidth,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(hPad, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCalendarHeader(),
                            const SizedBox(height: 4),
                            _buildMonthCalendar(),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Colors.black12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(20, 12, hPad, 4),
                            child: const Text(
                              'Agenda',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildAgendaPane(
                              days,
                              leftPadding: 20,
                              rightPadding: hPad,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final hInset = responsiveHorizontalInset(width, maxWidth: 680);
              return RefreshIndicator(
                onRefresh: widget.controller.loadAgendas,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hInset, 8, hInset, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCalendarHeader(),
                            const SizedBox(height: 4),
                            _buildMonthCalendar(),
                            const Padding(
                              padding: EdgeInsets.only(top: 16, bottom: 4),
                              child: Text(
                                'Agenda',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.controller.isLoading && days.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (days.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Belum ada agenda',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hInset, 8, 0, 24),
                        sliver: SliverList.builder(
                          itemCount: days.length,
                          itemBuilder: (context, i) {
                            final day = days[i];
                            return AgendaRow(
                              date: day.key,
                              items: day.value,
                              isToday: DateUtils.isSameDay(day.key, _today),
                              rightPadding: hInset,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAgendaPane(
    List<MapEntry<DateTime, List<AgendaItemModel>>> days, {
    required double leftPadding,
    required double rightPadding,
  }) {
    if (widget.controller.isLoading && days.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (days.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.controller.loadAgendas,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada agenda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadAgendas,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(leftPadding, 8, 0, 24),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          return AgendaRow(
            date: day.key,
            items: day.value,
            isToday: DateUtils.isSameDay(day.key, _today),
            rightPadding: rightPadding,
          );
        },
      ),
    );
  }
}
