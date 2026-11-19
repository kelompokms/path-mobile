import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';

class MonthCalendar extends StatelessWidget {
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

  const MonthCalendar({
    super.key,
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
  static final _agendaHighlightColor = AppColors.warning.withValues(
    alpha: 0.30,
  );
  static final _agendaRangeBandColor = AppColors.warning.withValues(
    alpha: 0.18,
  );

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
            const CalendarLegendItem(
              color: AppColors.color1,
              label: 'Hari ini',
            ),
            CalendarLegendItem(
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
            : AppTheme.thinBorder,
        boxShadow: AppTheme.thinShadow,
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

class CalendarLegendItem extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;

  const CalendarLegendItem({
    super.key,
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
