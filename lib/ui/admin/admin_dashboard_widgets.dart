import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

class AiUsageItem {
  final String nama;
  final bool isGuru;
  final String detail;
  final int aiUsage;

  const AiUsageItem({
    required this.nama,
    required this.isGuru,
    required this.detail,
    required this.aiUsage,
  });
}

class StatRowPair extends StatelessWidget {
  final Widget left;
  final Widget right;

  const StatRowPair({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class StatSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String badgeLabel;
  final Color badgeColor;

  const StatSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.badgeLabel,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              PillBadge(label: badgeLabel, color: badgeColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class PillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const PillBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class RoleFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const RoleFilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dimmed ? color.withValues(alpha: 0.45) : color,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiUsageRow extends StatelessWidget {
  final AiUsageItem item;
  final Color accentColor;

  const AiUsageRow({super.key, required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final roleLabel = item.isGuru ? 'Guru' : 'Siswa';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accentColor,
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.nama} ($roleLabel)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PillBadge(
            label: 'Pakai AI: ${item.aiUsage}x',
            color: accentColor,
          ),
        ],
      ),
    );
  }
}
