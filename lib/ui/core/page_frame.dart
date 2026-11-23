import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/user_avatar.dart';
import 'package:path_mobile/utils/date_time_helper.dart';

/// Supplies admin profile & logout actions to [PageFrame] headers when rendered
/// inside the 4-tab admin shell (which has no Profil bottom navigation tab).
class AdminActionScope extends InheritedWidget {
  final VoidCallback onOpenProfile;
  final Future<void> Function() onLogout;
  final String? profilePicture;
  final String? baseUrl;

  const AdminActionScope({
    super.key,
    required this.onOpenProfile,
    required this.onLogout,
    this.profilePicture,
    this.baseUrl,
    required super.child,
  });

  static AdminActionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminActionScope>();
  }

  @override
  bool updateShouldNotify(AdminActionScope oldWidget) =>
      onOpenProfile != oldWidget.onOpenProfile ||
      onLogout != oldWidget.onLogout ||
      profilePicture != oldWidget.profilePicture ||
      baseUrl != oldWidget.baseUrl;
}

class PageFrame extends StatelessWidget {
  final List<String> breadcrumb;
  final Widget child;
  final List<Widget>? actions;

  const PageFrame({
    super.key,
    required this.breadcrumb,
    required this.child,
    this.actions,
  });

  Future<void> _confirmLogout(
    BuildContext context,
    AdminActionScope scope,
  ) async {
    final yes = await showConfirmDialog(
      context,
      title: 'Keluar',
      message: 'Apakah Anda yakin ingin keluar dari akun?',
    );
    if (!yes || !context.mounted) return;
    await scope.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final adminScope = AdminActionScope.maybeOf(context);
    final trailingActions =
        actions ??
        (adminScope != null
            ? [
                IconButton(
                  onPressed: adminScope.onOpenProfile,
                  tooltip: 'Profil',
                  icon: (adminScope.profilePicture?.trim().isNotEmpty ?? false)
                      ? UserAvatar(
                          picturePath: adminScope.profilePicture,
                          baseUrl: adminScope.baseUrl,
                          radius: 12,
                          backgroundColor: AppColors.color1,
                          fallback: const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: AppColors.text,
                        ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmLogout(context, adminScope),
                  tooltip: 'Keluar',
                  icon: const Icon(
                    Icons.logout,
                    size: 20,
                    color: AppColors.error,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ]
            : const <Widget>[]);

    return Material(
      color: AppColors.card,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                trailingActions.isEmpty ? 14 : 8,
                trailingActions.isEmpty ? 16 : 8,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'PATH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        for (final item in breadcrumb) ...[
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.secondaryText,
                          ),
                          Flexible(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingActions.isNotEmpty) ...trailingActions,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class BackTitleRow extends StatelessWidget {
  final String title;

  const BackTitleRow({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
              } else {
                GoRouter.maybeOf(context)?.go('/kelas');
              }
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.text),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> openPage<T>(
  BuildContext context, {
  required List<String> breadcrumb,
  required Widget page,
  String? routeName,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      settings: RouteSettings(name: routeName),
      builder: (_) => Scaffold(
        backgroundColor: AppColors.card,
        body: PageFrame(breadcrumb: breadcrumb, child: page),
      ),
    ),
  );
}

void replacePage(
  BuildContext context, {
  required List<String> breadcrumb,
  required Widget page,
}) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.card,
        body: PageFrame(breadcrumb: breadcrumb, child: page),
      ),
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.secondaryText,
          fontSize: 12,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, false),
          style: AppTheme.softCompactButton,
          child: const Text('Tidak'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: AppTheme.softCompactButton,
          child: const Text('Ya'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.secondaryText,
          fontSize: 12,
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: AppTheme.softCompactButton,
          child: const Text('Oke'),
        ),
      ],
    ),
  );
}

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatTanggal(DateTime date) {
  final gmt7 = toGmt7(date);
  return '${gmt7.day} ${_namaBulan[gmt7.month - 1]} ${gmt7.year}';
}

String formatJam(DateTime date) {
  final gmt7 = toGmt7(date);
  final h = gmt7.hour.toString().padLeft(2, '0');
  final m = gmt7.minute.toString().padLeft(2, '0');
  return '$h.$m';
}

String formatBulanTahun(DateTime date) {
  final gmt7 = toGmt7(date);
  return '${_namaBulan[gmt7.month - 1]} ${gmt7.year}';
}
