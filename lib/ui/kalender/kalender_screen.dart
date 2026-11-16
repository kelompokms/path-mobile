import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';

class KalenderScreen extends StatefulWidget {
  final KalenderController controller;

  const KalenderScreen({super.key, required this.controller});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _shownMonth = DateTime(_today.year, _today.month);

  @override
  void initState() {
    super.initState();
    widget.controller.loadAgendas();
  }

  void _changeMonth(int delta) {
    setState(() {
      _shownMonth = DateTime(_shownMonth.year, _shownMonth.month + delta);
    });
  }

  List<MapEntry<DateTime, List<AgendaItemModel>>> get _days {
    final grouped = <DateTime, List<AgendaItemModel>>{};
    for (final item in widget.controller.agendas) {
      if (item.date.year != _shownMonth.year ||
          item.date.month != _shownMonth.month) {
        continue;
      }
      final day = DateUtils.dateOnly(item.date);
      (grouped[day] ??= []).add(item);
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

              if (width >= 720) {
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
                            const Text(
                              'Kalender',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _MonthCalendar(
                              month: _shownMonth,
                              today: _today,
                              onPrev: () => _changeMonth(-1),
                              onNext: () => _changeMonth(1),
                            ),
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
                            const Text(
                              'Kalender',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _MonthCalendar(
                              month: _shownMonth,
                              today: _today,
                              onPrev: () => _changeMonth(-1),
                              onNext: () => _changeMonth(1),
                            ),
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

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.onPrev,
    required this.onNext,
  });

  static const _weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
  static const _line = Divider(height: 1, thickness: 1, color: Colors.black12);

  @override
  Widget build(BuildContext context) {
    final leading = month.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((leading + daysInMonth) / 7).ceil();
    final textScaler = MediaQuery.textScalerOf(context);
    final weekdayHeight = math.max(36.0, textScaler.scale(13) + 18.0);
    final cellHeight = math.max(44.0, textScaler.scale(12) + 28.0);
    final circleDiameter = math.max(32.0, textScaler.scale(12) + 18.0);

    return Column(
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
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _buildCell(
                    r * 7 + c,
                    leading,
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
    required double cellHeight,
    required double circleDiameter,
  }) {
    final date = DateTime(month.year, month.month, 1 - leading + index);
    final inMonth = date.month == month.month;
    final isToday = inMonth && DateUtils.isSameDay(date, today);
    final isSunday = date.weekday == DateTime.sunday;

    final Color color;
    if (inMonth) {
      color = isSunday ? AppColors.error : AppColors.text;
    } else {
      color = isSunday
          ? AppColors.error.withValues(alpha: 0.35)
          : AppColors.secondaryText.withValues(alpha: 0.45);
    }

    return SizedBox(
      height: cellHeight,
      child: Center(
        child: DecoratedBox(
          decoration: isToday
              ? const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.color1,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: SizedBox(
            width: circleDiameter,
            height: circleDiameter,
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: isToday ? Colors.white : color,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
