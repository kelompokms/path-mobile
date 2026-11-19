import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

class AdminUserSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const AdminUserSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class AdminEmptySectionNotice extends StatelessWidget {
  final String message;

  const AdminEmptySectionNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: AppTheme.cardDecoration(color: AppColors.background),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
    );
  }
}

class AdminUserCard extends StatelessWidget {
  final AdminPenggunaModel user;
  final Color accentColor;
  final String roleLabel;
  final String emptyClassLabel;
  final String classPrefix;
  final String actionLabel;
  final VoidCallback onToggleRole;

  const AdminUserCard({
    super.key,
    required this.user,
    required this.accentColor,
    required this.roleLabel,
    required this.emptyClassLabel,
    required this.classPrefix,
    required this.actionLabel,
    required this.onToggleRole,
  });

  @override
  Widget build(BuildContext context) {
    final classSummary = user.kelas.isEmpty
        ? emptyClassLabel
        : '$classPrefix${user.kelas.join(', ')}';

    return Card(
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              user.nama.isNotEmpty ? user.nama : 'Tanpa Nama',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<int>(
                        key: Key('user_role_menu_${user.id}'),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.text,
                        ),
                        tooltip: 'Ubah role',
                        elevation: AppTheme.cardElevation,
                        shadowColor: AppTheme.shadowColor,
                        color: AppColors.background,
                        surfaceTintColor: Colors.transparent,
                        shape: AppTheme.cardShape(),
                        onSelected: (_) => onToggleRole(),
                        itemBuilder: (_) => [
                          PopupMenuItem<int>(
                            value: 0,
                            child: Text(actionLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    classSummary,
                    style: const TextStyle(fontSize: 11, color: AppColors.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
