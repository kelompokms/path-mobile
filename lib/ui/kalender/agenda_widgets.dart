import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';

String formatAgendaMeta(AgendaItemModel item) {
  final end = item.endDate;
  final hasRange = end != null && !DateUtils.isSameDay(item.date, end);
  final dateText = hasRange
      ? '${formatTanggal(item.date)} - ${formatTanggal(end)}'
      : formatTanggal(item.date);
  return '${item.heading} • $dateText (${item.time})';
}

class AgendaRow extends StatelessWidget {
  final DateTime date;
  final List<AgendaItemModel> items;
  final bool isToday;
  final double rightPadding;

  const AgendaRow({
    super.key,
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
                          AgendaCard(item: item, maxWidth: cardMaxWidth),
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
                        AgendaCard(item: items[i], maxWidth: cardMaxWidth),
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

class AgendaCard extends StatelessWidget {
  final AgendaItemModel item;
  final double maxWidth;

  const AgendaCard({super.key, required this.item, this.maxWidth = 200});

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
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
              formatAgendaMeta(item),
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
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: AppTheme.cardShape(),
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
