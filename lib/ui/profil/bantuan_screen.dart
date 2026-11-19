import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

class BantuanScreen extends StatelessWidget {
  const BantuanScreen({super.key});

  static const _titles = ['Panduan AI', 'Etika Penggunaan AI', 'Kontak Kami'];
  static const _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
      'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim '
      'veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
      'commodo consequat.';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 720,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Bantuan'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                children: [
                  for (final title in _titles) ...[
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: AppColors.text,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      children: const [
                        Text(
                          _lorem,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
