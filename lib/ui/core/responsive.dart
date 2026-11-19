import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

/// Shared responsive breakpoints and layout helpers across app screens.
abstract final class ResponsiveBreakpoints {
  static const double narrow = 360;
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1024;
  static const double wide = 1200;
}

/// Returns adaptive outer horizontal padding for the given viewport width.
double responsiveHorizontalPadding(double width) {
  if (width < ResponsiveBreakpoints.narrow) return 12;
  if (width < ResponsiveBreakpoints.compact) return 16;
  if (width < ResponsiveBreakpoints.medium) return 24;
  return 32;
}

/// Computes horizontal padding that centers content within [maxWidth] while
/// keeping at least [responsiveHorizontalPadding] on smaller viewports.
double responsiveHorizontalInset(
  double availableWidth, {
  double maxWidth = 960,
}) {
  final base = responsiveHorizontalPadding(availableWidth);
  final centered = (availableWidth - maxWidth) / 2;
  return math.max(base, centered);
}

/// Computes EdgeInsets for scrollable lists/grids centered within [maxWidth].
EdgeInsets responsiveListPadding(
  double availableWidth, {
  double maxWidth = 960,
  double top = 12,
  double bottom = 24,
}) {
  final horizontal = responsiveHorizontalInset(
    availableWidth,
    maxWidth: maxWidth,
  );
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}

/// Adjusts outer horizontal padding around `BackTitleRow` (whose visual
/// inset is 16px) so it aligns cleanly with [horizontalInset].
EdgeInsets alignedBackTitlePadding(double horizontalInset) {
  final extra = math.max(0.0, horizontalInset - 16);
  return EdgeInsets.symmetric(horizontal: extra);
}

/// Computes an appropriate column count for class grids given available width
/// and the user's text scale factor.
int classGridColumns(double availableWidth, {double textScale = 1.0}) {
  if (availableWidth < 300) return 1;
  if (availableWidth < 380 && textScale >= 1.45) return 1;
  if (availableWidth < 560) return 2;
  if (availableWidth < 820) return 3;
  if (availableWidth < 1100) return 4;
  return 5;
}

/// Builds a [SliverGridDelegateWithFixedCrossAxisCount] for `ClassCard` grids
/// that adapts column count to width and tile height to text scaling.
SliverGridDelegateWithFixedCrossAxisCount responsiveClassGridDelegate(
  BuildContext context,
  double availableWidth, {
  double maxContentWidth = 1200,
}) {
  final textTheme = Theme.of(context).textTheme;
  final textScaler = MediaQuery.textScalerOf(context);
  final titleFontSize = textTheme.titleSmall?.fontSize ?? 14;
  final bodyFontSize = textTheme.bodySmall?.fontSize ?? 12;
  final textScale = textScaler.scale(titleFontSize) / titleFontSize;

  final inset = responsiveHorizontalInset(
    availableWidth,
    maxWidth: maxContentWidth,
  );
  final contentWidth = math.max(0.0, availableWidth - inset * 2);
  final columns = classGridColumns(contentWidth, textScale: textScale);
  final spacing = availableWidth < ResponsiveBreakpoints.narrow ? 10.0 : 12.0;

  final titleHeight = textScaler.scale(titleFontSize) * 1.45;
  final subHeight = textScaler.scale(bodyFontSize) * 1.4;
  final mainAxisExtent =
      (70 + 16 + titleHeight + 2 + subHeight + 2 + subHeight + 10)
          .ceilToDouble();

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
    mainAxisExtent: mainAxisExtent,
  );
}

/// Responsive container for bottom-sheet auth screens on phones and centered
/// card modals on tablets/desktops.
class ResponsiveAuthSheet extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints viewport,
    bool isCompactSheet,
  )
  builder;

  const ResponsiveAuthSheet({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSystemPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final isWide = width >= ResponsiveBreakpoints.compact;
          final isShort = height < 540;
          final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

          if (isWide) {
            final maxHeight = math.max(240.0, height - 32);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: 500,
                    maxHeight: maxHeight,
                  ),
                  decoration: BoxDecoration(
                    boxShadow: AppTheme.thinShadow,
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.sheetRadius),
                    border: AppTheme.thinBorder,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      36,
                      isShort ? 20 : 28,
                      36,
                      isShort ? 20 : 28,
                    ),
                    child: builder(context, constraints, false),
                  ),
                ),
              ),
            );
          }

          final horizontalPadding = width < ResponsiveBreakpoints.narrow
              ? 20.0
              : 28.0;
          final topRadius = width < ResponsiveBreakpoints.narrow
              ? AppTheme.dialogRadius
              : AppTheme.sheetRadius;
          final maxSheetHeight = (keyboardVisible || isShort)
              ? height * 0.96
              : height * 0.82;
          final minSheetHeight = (keyboardVisible || isShort)
              ? 0.0
              : math.min(height * 0.65, maxSheetHeight);

          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: minSheetHeight,
                maxHeight: maxSheetHeight,
              ),
              decoration: BoxDecoration(
                boxShadow: AppTheme.thinShadow,
                color: theme.cardColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(topRadius),
                ),
                border: AppTheme.thinBorder,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isShort ? 18 : 24,
                      horizontalPadding,
                      24 + bottomSystemPadding,
                    ),
                    child: builder(context, constraints, true),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Responsive header row shared by login and registration auth sheets.
class AuthSheetHeader extends StatelessWidget {
  final String title;
  final double viewportWidth;

  const AuthSheetHeader({
    super.key,
    required this.title,
    required this.viewportWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleFontSize = viewportWidth < ResponsiveBreakpoints.narrow
        ? 24.0
        : viewportWidth < ResponsiveBreakpoints.compact
        ? 28.0
        : 32.0;

    return Row(
      children: [
        const BackButton(color: AppColors.text),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: const Icon(Icons.person),
        ),
      ],
    );
  }
}
