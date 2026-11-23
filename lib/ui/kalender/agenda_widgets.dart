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
  final ValueChanged<AgendaItemModel>? onEditAgenda;
  final ValueChanged<AgendaItemModel>? onDeleteAgenda;

  const AgendaRow({
    super.key,
    required this.date,
    required this.items,
    required this.isToday,
    this.rightPadding = 16,
    this.onEditAgenda,
    this.onDeleteAgenda,
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
                          AgendaCard(
                            item: item,
                            maxWidth: cardMaxWidth,
                            onEdit: onEditAgenda,
                            onDelete: onDeleteAgenda,
                          ),
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
                        AgendaCard(
                          item: items[i],
                          maxWidth: cardMaxWidth,
                          onEdit: onEditAgenda,
                          onDelete: onDeleteAgenda,
                        ),
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
  final ValueChanged<AgendaItemModel>? onEdit;
  final ValueChanged<AgendaItemModel>? onDelete;

  const AgendaCard({
    super.key,
    required this.item,
    this.maxWidth = 200,
    this.onEdit,
    this.onDelete,
  });

  bool get _canManage =>
      item.isGlobal &&
      item.id != null &&
      item.id! > 0 &&
      (onEdit != null || onDelete != null);

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
        content: SingleChildScrollView(
          child: Column(
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
        ),
        actions: [
          if (_canManage && onDelete != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onDelete!(item);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Hapus'),
            ),
          if (_canManage && onEdit != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onEdit!(item);
              },
              child: const Text('Edit'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
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
                      ),
                      if (_canManage) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            key: Key('admin_agenda_menu_${item.id}'),
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppColors.text,
                            ),
                            tooltip: 'Opsi agenda',
                            elevation: AppTheme.cardElevation,
                            shadowColor: AppTheme.shadowColor,
                            color: AppColors.background,
                            surfaceTintColor: Colors.transparent,
                            shape: AppTheme.cardShape(),
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit?.call(item);
                              } else if (value == 'delete') {
                                onDelete?.call(item);
                              }
                            },
                            itemBuilder: (_) => [
                              if (onEdit != null)
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Edit Agenda'),
                                ),
                              if (onDelete != null)
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text(
                                    'Hapus Agenda',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
