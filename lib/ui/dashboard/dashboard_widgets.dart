import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart' as km;
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

class GuruSubmissionSummary {
  final ClassItem classItem;
  final km.PostinganModel post;
  final int submissionCount;
  final int totalStudents;
  final String latestStudentName;

  const GuruSubmissionSummary({
    required this.classItem,
    required this.post,
    required this.submissionCount,
    this.totalStudents = 0,
    this.latestStudentName = '',
  });

  double? get completionRate {
    if (totalStudents <= 0) return null;
    final denom = math.max(totalStudents, submissionCount);
    return (submissionCount / denom).clamp(0.0, 1.0);
  }
}

class MuridTaskSummary {
  final ClassItem classItem;
  final km.PostinganModel post;
  final bool submitted;

  const MuridTaskSummary({
    required this.classItem,
    required this.post,
    required this.submitted,
  });
}

class RoleHeader extends StatelessWidget {
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final String subtitle;

  const RoleHeader({
    super.key,
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
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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

class StatCardsLayout extends StatelessWidget {
  final List<DashboardStatCard> cards;
  final double width;

  const StatCardsLayout({
    super.key,
    required this.cards,
    required this.width,
  });

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

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const DashboardStatCard({
    super.key,
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
      decoration: AppTheme.cardDecoration(),
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

class SectionHeaderRow extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeaderRow({
    super.key,
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

class SummaryListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final IconData icon;
  final VoidCallback onTap;
  final double? progress;
  final Color? progressColor;

  const SummaryListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.icon,
    required this.onTap,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        margin: EdgeInsets.zero,
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: AppTheme.cardShape(),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                    if (progress != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor ?? badgeColor,
                          ),
                        ),
                      ),
                    ],
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
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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

class AgendaPreviewBlock extends StatelessWidget {
  final List<KalenderAkademikModel> agendas;
  final VoidCallback? onOpenCalendar;

  const AgendaPreviewBlock({
    super.key,
    required this.agendas,
    this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeaderRow(
          title: 'Agenda Sekolah Terdekat',
          actionLabel: onOpenCalendar != null ? 'Lihat Kalender' : null,
          onAction: onOpenCalendar,
        ),
        const SizedBox(height: 8),
        if (agendas.isEmpty)
          const EmptyNoticeBox(message: 'Belum ada agenda sekolah mendatang')
        else
          for (final item in agendas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: AppTheme.cardDecoration(
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
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

class EmbeddedClassGrid extends StatelessWidget {
  final List<ClassItem> items;
  final double width;
  final ValueChanged<ClassItem> onTapItem;

  const EmbeddedClassGrid({
    super.key,
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

class EmptyNoticeBox extends StatelessWidget {
  final String message;

  const EmptyNoticeBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: AppTheme.cardDecoration(),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
    );
  }
}
