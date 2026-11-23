import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/profil/bantuan_screen.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';

class ProfilHeader extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onLogout;
  final double horizontalPadding;
  final ProfilController? controller;

  const ProfilHeader({
    super.key,
    this.showBack = false,
    this.onLogout,
    this.horizontalPadding = 16,
    this.controller,
  });

  void _handleBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftPad = showBack
        ? math.max(4.0, horizontalPadding - 12)
        : horizontalPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < ResponsiveBreakpoints.narrow;
        final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
        final stackActions = isNarrow && textScale >= 1.35;

        final buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.text,
          elevation: AppTheme.cardElevation,
          shadowColor: AppTheme.shadowColor,
          side: AppTheme.thinBorderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 14),
          minimumSize: const Size(0, 32),
          textStyle: const TextStyle(fontSize: 11),
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => openPage(
                context,
                breadcrumb: const ['Profil', 'Bantuan'],
                page: BantuanScreen(controller: controller),
              ),
              style: buttonStyle,
              child: const Text('Bantuan'),
            ),
            if (onLogout != null)
              ElevatedButton(
                onPressed: onLogout,
                style: buttonStyle,
                child: const Text('Keluar'),
              ),
          ],
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(leftPad, 8, horizontalPadding, 8),
          child: stackActions
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          IconButton(
                            onPressed: () => _handleBack(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.text,
                            ),
                          ),
                        const Expanded(
                          child: Text(
                            'Profil',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => _handleBack(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.text,
                        ),
                      ),
                    const Expanded(
                      child: Text(
                        'Profil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}

class ProfilInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfilInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.text),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
