import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/dashboard/dashboard_models.dart';

export 'dashboard_models.dart';

Color guruProgressColor(double? rate) {
  if (rate == null) return AppColors.secondaryText;
  if (rate >= 0.8) return AppColors.success;
  if (rate >= 0.5) return const Color(0xFFE09F00);
  return AppColors.error;
}

/// Responsive visual analytics panel for Beranda Guru:
/// - Wide screens (`>= 720px`): shows Class Participation and 7-Day Activity side-by-side.
/// - Compact screens (`< 720px`): shows a single card with a tab toggle so the
///   dashboard stays scannable and above the fold.
class GuruStatsPanel extends StatefulWidget {
  final double width;
  final List<GuruClassProgress> classProgress;
  final List<DailySubmissionBucket> dailySubmissions;
  final int withAttachmentCount;
  final int markAsDoneCount;
  final ValueChanged<ClassItem> onTapClass;

  const GuruStatsPanel({
    super.key,
    required this.width,
    required this.classProgress,
    required this.dailySubmissions,
    required this.withAttachmentCount,
    required this.markAsDoneCount,
    required this.onTapClass,
  });

  @override
  State<GuruStatsPanel> createState() => _GuruStatsPanelState();
}

class _GuruStatsPanelState extends State<GuruStatsPanel> {
  int _mobileTab = 0;

  @override
  Widget build(BuildContext context) {
    final classCard = ClassParticipationChartCard(
      classProgress: widget.classProgress,
      onTapClass: widget.onTapClass,
      embedded: widget.width < 720,
    );
    final activityCard = SubmissionActivityChartCard(
      buckets: widget.dailySubmissions,
      withAttachmentCount: widget.withAttachmentCount,
      markAsDoneCount: widget.markAsDoneCount,
      embedded: widget.width < 720,
    );

    if (widget.width >= 720) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: classCard),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: activityCard),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatsTabPill(
                key: const Key('guru_stats_tab_kelas'),
                label: 'Per Kelas',
                selected: _mobileTab == 0,
                onTap: () => setState(() => _mobileTab = 0),
              ),
              _StatsTabPill(
                key: const Key('guru_stats_tab_aktivitas'),
                label: '7 Hari Terakhir',
                selected: _mobileTab == 1,
                onTap: () => setState(() => _mobileTab = 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_mobileTab == 0) classCard else activityCard,
        ],
      ),
    );
  }
}

class _StatsTabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatsTabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.color1
          : AppColors.color1.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.color1,
            ),
          ),
        ),
      ),
    );
  }
}

class ClassParticipationChartCard extends StatelessWidget {
  final List<GuruClassProgress> classProgress;
  final ValueChanged<ClassItem> onTapClass;
  final bool embedded;

  const ClassParticipationChartCard({
    super.key,
    required this.classProgress,
    required this.onTapClass,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayed = classProgress.take(4).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            const Text(
              'Partisipasi per Kelas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              '${classProgress.length} kelas',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (displayed.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Belum ada data kelas yang diampu',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          )
        else
          for (var i = 0; i < displayed.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ClassProgressRow(
              entry: displayed[i],
              onTap: () => onTapClass(displayed[i].classItem),
            ),
          ],
      ],
    );

    if (embedded) return content;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: content,
    );
  }
}

class _ClassProgressRow extends StatelessWidget {
  final GuruClassProgress entry;
  final VoidCallback onTap;

  const _ClassProgressRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rate = entry.completionRate;
    final barColor = guruProgressColor(rate);
    final rightLabel = rate != null
        ? '${(rate * 100).round()}% (${entry.submissionCount}/${entry.expectedSubmissions})'
        : (entry.taskCount == 0
              ? 'Belum ada tugas'
              : '${entry.submissionCount} kiriman');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
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
                  entry.classItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  rightLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: rate != null ? barColor : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate ?? 0,
                minHeight: 6,
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${entry.studentCount} murid • ${entry.taskCount} tugas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubmissionActivityChartCard extends StatelessWidget {
  final List<DailySubmissionBucket> buckets;
  final int withAttachmentCount;
  final int markAsDoneCount;
  final bool embedded;

  const SubmissionActivityChartCard({
    super.key,
    required this.buckets,
    required this.withAttachmentCount,
    required this.markAsDoneCount,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final total7Days = buckets.fold<int>(0, (sum, b) => sum + b.count);
    final maxCount = buckets.fold<int>(
      1,
      (prev, b) => math.max(prev, b.count),
    );
    final totalComposition = withAttachmentCount + markAsDoneCount;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            const Text(
              'Aktivitas 7 Hari Terakhir',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              '$total7Days kiriman',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.color1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (buckets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Belum ada aktivitas pengumpulan',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bucket in buckets)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${bucket.count}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: bucket.count > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: bucket.count > 0
                                ? AppColors.text
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 54,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 0.48,
                            child: Container(
                              height: bucket.count == 0
                                  ? 4
                                  : 8 + (bucket.count / maxCount) * 44,
                              decoration: BoxDecoration(
                                color: bucket.count == 0
                                    ? Colors.black12
                                    : (bucket.isToday
                                          ? AppColors.color1
                                          : AppColors.color1.withValues(
                                              alpha: 0.45,
                                            )),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bucket.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: bucket.isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: bucket.isToday
                                ? AppColors.color1
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: Colors.black12),
        const SizedBox(height: 10),
        const Text(
          'Komposisi Kiriman',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: totalComposition == 0
                ? const ColoredBox(color: Colors.black12)
                : Row(
                    children: [
                      if (withAttachmentCount > 0)
                        Expanded(
                          flex: withAttachmentCount,
                          child: const ColoredBox(color: AppColors.color1),
                        ),
                      if (markAsDoneCount > 0)
                        Expanded(
                          flex: markAsDoneCount,
                          child: const ColoredBox(color: Color(0xFFE09F00)),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _CompositionLegend(
              color: AppColors.color1,
              label: 'Lampiran: $withAttachmentCount',
            ),
            _CompositionLegend(
              color: const Color(0xFFE09F00),
              label: 'Tandai Selesai: $markAsDoneCount',
            ),
          ],
        ),
      ],
    );

    if (embedded) return content;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: content,
    );
  }
}

class _CompositionLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CompositionLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}
