import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

class PageFrame extends StatelessWidget {
  final List<String> breadcrumb;
  final Widget child;

  const PageFrame({super.key, required this.breadcrumb, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

String formatTanggal(DateTime date) =>
    '${date.day} ${_namaBulan[date.month - 1]} ${date.year}';

String formatJam(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h.$m';
}

String formatBulanTahun(DateTime date) =>
    '${_namaBulan[date.month - 1]} ${date.year}';
