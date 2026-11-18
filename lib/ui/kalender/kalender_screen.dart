import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';

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
    final result = await showDialog<_TambahAgendaResult>(
      context: context,
      builder: (_) => _TambahAgendaDialog(initialDate: _selectedDate),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  _formatAgendaMeta(items[i]),
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
    return _MonthCalendar(
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
                            return _AgendaRow(
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
          return _AgendaRow(
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

String _formatAgendaMeta(AgendaItemModel item) {
  final end = item.endDate;
  final hasRange = end != null && !DateUtils.isSameDay(item.date, end);
  final dateText = hasRange
      ? '${formatTanggal(item.date)} - ${formatTanggal(end)}'
      : formatTanggal(item.date);
  return '${item.heading} • $dateText (${item.time})';
}

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final DateTime? selectedDate;
  final Map<DateTime, List<AgendaItemModel>> globalAgendasByDay;
  final PageController pageController;
  final DateTime Function(int page) monthForPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime>? onSelectDate;
  final ValueChanged<DateTime>? onTapAgendaDay;

  const _MonthCalendar({
    required this.month,
    required this.today,
    this.selectedDate,
    this.globalAgendasByDay = const {},
    required this.pageController,
    required this.monthForPage,
    required this.onPageChanged,
    required this.onPrev,
    required this.onNext,
    this.onSelectDate,
    this.onTapAgendaDay,
  });

  static const _weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
  static const _maxRows = 6;
  static const _line = Divider(height: 1, thickness: 1, color: Colors.black12);
  static const _agendaAccentColor = Color(0xFFE09F00);
  static const _agendaTextColor = Color(0xFF7A4F01);
  static final _agendaHighlightColor = AppColors.warning.withValues(alpha: 0.30);
  static final _agendaRangeBandColor = AppColors.warning.withValues(alpha: 0.18);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final weekdayHeight = math.max(36.0, textScaler.scale(13) + 18.0);
    final cellHeight = math.max(44.0, textScaler.scale(12) + 28.0);
    final circleDiameter = math.max(32.0, textScaler.scale(12) + 18.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.chevron_left, 'Bulan sebelumnya', onPrev),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    formatBulanTahun(month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
            _arrow(Icons.chevron_right, 'Bulan berikutnya', onNext),
          ],
        ),
        _line,
        SizedBox(
          height: weekdayHeight,
          child: Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _line,
        SizedBox(
          height: cellHeight * _maxRows,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemBuilder: (context, page) => _buildMonthGrid(
              monthForPage(page),
              cellHeight: cellHeight,
              circleDiameter: circleDiameter,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            const _CalendarLegendItem(
              color: AppColors.color1,
              label: 'Hari ini',
            ),
            _CalendarLegendItem(
              color: _agendaHighlightColor,
              borderColor: _agendaAccentColor,
              label: 'Agenda global',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthGrid(
    DateTime displayMonth, {
    required double cellHeight,
    required double circleDiameter,
  }) {
    final leading = displayMonth.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(
      displayMonth.year,
      displayMonth.month,
    );
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _buildCell(
                    r * 7 + c,
                    leading,
                    displayMonth: displayMonth,
                    cellHeight: cellHeight,
                    circleDiameter: circleDiameter,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(
    int index,
    int leading, {
    required DateTime displayMonth,
    required double cellHeight,
    required double circleDiameter,
  }) {
    final date = DateTime(
      displayMonth.year,
      displayMonth.month,
      1 - leading + index,
    );
    final inMonth = date.month == displayMonth.month;
    final isToday = inMonth && DateUtils.isSameDay(date, today);
    final isSelected =
        inMonth &&
        selectedDate != null &&
        DateUtils.isSameDay(date, selectedDate);
    final isSunday = date.weekday == DateTime.sunday;

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final agendasOnDay = inMonth
        ? (globalAgendasByDay[normalizedDate] ?? const <AgendaItemModel>[])
        : const <AgendaItemModel>[];
    final hasGlobalAgenda = agendasOnDay.isNotEmpty;

    final col = index % 7;
    final prevDate = DateTime(date.year, date.month, date.day - 1);
    final nextDate = DateTime(date.year, date.month, date.day + 1);
    final hasPrevInRow =
        col > 0 &&
        hasGlobalAgenda &&
        prevDate.month == displayMonth.month &&
        (globalAgendasByDay[prevDate]?.isNotEmpty ?? false);
    final hasNextInRow =
        col < 6 &&
        hasGlobalAgenda &&
        nextDate.month == displayMonth.month &&
        (globalAgendasByDay[nextDate]?.isNotEmpty ?? false);
    final isBandMiddle = hasPrevInRow && hasNextInRow;

    final Color color;
    if (inMonth) {
      color = isSunday ? AppColors.error : AppColors.text;
    } else {
      color = isSunday
          ? AppColors.error.withValues(alpha: 0.35)
          : AppColors.secondaryText.withValues(alpha: 0.45);
    }

    final BoxDecoration decoration;
    if (isToday) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.color1,
        border: hasGlobalAgenda
            ? Border.all(color: AppColors.warning, width: 2.2)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      );
    } else if (isSelected) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: hasGlobalAgenda
            ? _agendaHighlightColor
            : AppColors.color1.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.color1, width: 1.5),
      );
    } else if (hasGlobalAgenda) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: isBandMiddle ? _agendaRangeBandColor : _agendaHighlightColor,
        border: isBandMiddle
            ? null
            : Border.all(color: _agendaAccentColor, width: 1.3),
      );
    } else {
      decoration = const BoxDecoration();
    }

    final Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (isSelected) {
      textColor = AppColors.color3;
    } else if (hasGlobalAgenda) {
      textColor = isSunday ? AppColors.error : _agendaTextColor;
    } else {
      textColor = color;
    }

    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    Widget cell = SizedBox(
      height: cellHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasGlobalAgenda && (hasPrevInRow || hasNextInRow))
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  height: circleDiameter,
                  child: Row(
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: hasPrevInRow
                              ? _agendaRangeBandColor
                              : Colors.transparent,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Container(
                        width: circleDiameter,
                        decoration: BoxDecoration(
                          color: _agendaRangeBandColor,
                          borderRadius: BorderRadius.horizontal(
                            left: hasPrevInRow
                                ? Radius.zero
                                : Radius.circular(circleDiameter / 2),
                            right: hasNextInRow
                                ? Radius.zero
                                : Radius.circular(circleDiameter / 2),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: hasNextInRow
                              ? _agendaRangeBandColor
                              : Colors.transparent,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          DecoratedBox(
            key: hasGlobalAgenda
                ? ValueKey('calendar_global_agenda_$dateKey')
                : null,
            decoration: decoration,
            child: SizedBox(
              width: circleDiameter,
              height: circleDiameter,
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: (isToday || isSelected || hasGlobalAgenda)
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          if (hasGlobalAgenda)
            Positioned(
              bottom: 1.5,
              child: Container(
                key: ValueKey('calendar_global_agenda_dot_$dateKey'),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? AppColors.warning : _agendaAccentColor,
                ),
              ),
            ),
        ],
      ),
    );

    if (hasGlobalAgenda) {
      cell = Tooltip(
        message: agendasOnDay.map((a) => a.title).join(', '),
        child: cell,
      );
    }

    if (!inMonth) {
      return cell;
    }

    if (onSelectDate != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelectDate!(date),
        child: cell,
      );
    }

    if (hasGlobalAgenda && onTapAgendaDay != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTapAgendaDay!(date),
        child: cell,
      );
    }

    return cell;
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: AppColors.text),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;

  const _CalendarLegendItem({
    required this.color,
    this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.2)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final DateTime date;
  final List<AgendaItemModel> items;
  final bool isToday;
  final double rightPadding;

  const _AgendaRow({
    required this.date,
    required this.items,
    required this.isToday,
    this.rightPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final dayColWidth = math.max(44.0, textScaler.scale(15) + 26.0);
    final badgeSize = math.max(28.0, textScaler.scale(12) + 16.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: dayColWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isToday
                  ? Container(
                      width: badgeSize,
                      height: badgeSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.color1,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availWidth = constraints.maxWidth;
                if (availWidth >= 460) {
                  final cardMaxWidth = math.min(
                    260.0,
                    math.max(180.0, availWidth - rightPadding),
                  );
                  return Padding(
                    padding: EdgeInsets.fromLTRB(0, 8, rightPadding, 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in items)
                          _AgendaCard(item: item, maxWidth: cardMaxWidth),
                      ],
                    ),
                  );
                }

                final cardMaxWidth = math.min(
                  220.0,
                  math.max(150.0, availWidth * 0.72),
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(0, 8, rightPadding, 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        _AgendaCard(item: items[i], maxWidth: cardMaxWidth),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final AgendaItemModel item;
  final double maxWidth;

  const _AgendaCard({required this.item, this.maxWidth = 200});

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatAgendaMeta(item),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.description,
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ],
          ],
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(
                        item.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        item.time,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TambahAgendaResult {
  final String namaEvent;
  final String keterangan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;

  const _TambahAgendaResult({
    required this.namaEvent,
    required this.keterangan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
  });
}

class _TambahAgendaDialog extends StatefulWidget {
  final DateTime initialDate;

  const _TambahAgendaDialog({required this.initialDate});

  @override
  State<_TambahAgendaDialog> createState() => _TambahAgendaDialogState();
}

class _TambahAgendaDialogState extends State<_TambahAgendaDialog> {
  final _namaController = TextEditingController();
  final _keteranganController = TextEditingController();
  late DateTime _tanggalMulai = DateUtils.dateOnly(widget.initialDate);
  late DateTime _tanggalSelesai = DateUtils.dateOnly(widget.initialDate);
  bool _triedSubmit = false;

  bool get _canSave => _namaController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _namaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalMulai,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggalMulai = DateUtils.dateOnly(picked);
      if (_tanggalSelesai.isBefore(_tanggalMulai)) {
        _tanggalSelesai = _tanggalMulai;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalSelesai.isBefore(_tanggalMulai)
          ? _tanggalMulai
          : _tanggalSelesai,
      firstDate: _tanggalMulai,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggalSelesai = DateUtils.dateOnly(picked);
    });
  }

  void _submit() {
    if (!_canSave) {
      setState(() => _triedSubmit = true);
      return;
    }
    Navigator.pop(
      context,
      _TambahAgendaResult(
        namaEvent: _namaController.text.trim(),
        keterangan: _keteranganController.text.trim(),
        tanggalMulai: _tanggalMulai,
        tanggalSelesai: _tanggalSelesai,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Agenda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nama Event',
                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('agenda_nama_field'),
                controller: _namaController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama event',
                  errorText: _triedSubmit && !_canSave
                      ? 'Nama event wajib diisi'
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Keterangan',
                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('agenda_keterangan_field'),
                controller: _keteranganController,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Tambahkan keterangan agenda (opsional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 340;
                  final startBtn = _DatePickerField(
                    key: const Key('agenda_tanggal_mulai_field'),
                    label: 'Tanggal Mulai',
                    date: _tanggalMulai,
                    onTap: _pickStartDate,
                  );
                  final endBtn = _DatePickerField(
                    key: const Key('agenda_tanggal_selesai_field'),
                    label: 'Tanggal Selesai',
                    date: _tanggalSelesai,
                    onTap: _pickEndDate,
                  );
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: startBtn),
                        const SizedBox(width: 8),
                        Expanded(child: endBtn),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      startBtn,
                      const SizedBox(height: 8),
                      endBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.text,
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton(
                      key: const Key('agenda_submit_button'),
                      onPressed: _submit,
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                formatTanggal(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
