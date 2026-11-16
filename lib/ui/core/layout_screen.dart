import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/responsive.dart';

class LayoutScreen extends StatelessWidget {
  const new({super.key, required this.child});

  final Widget child;

  static const List<({String route, String label, IconData icon})>
  _destinations = [
    (route: '/beranda', label: 'Beranda', icon: Icons.home),
    (route: '/pengajar', label: 'Pengajar', icon: Icons.engineering),
    (route: '/kelas', label: 'Kelas', icon: Icons.book),
    (route: '/kalender', label: 'Kalender', icon: Icons.calendar_month),
    (route: '/profil', label: 'Profil', icon: Icons.person),
  ];

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final int index = _destinations.indexWhere(
      (dest) => location.startsWith(dest.route),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < ResponsiveBreakpoints.compact) {
          final isNarrow = width < ResponsiveBreakpoints.narrow;
          return Scaffold(
            body: child,
            bottomNavigationBar: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.25,
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: selectedIndex,
                onTap: (index) => context.go(_destinations[index].route),
                selectedItemColor: AppColors.color1,
                unselectedItemColor: AppColors.secondaryText,
                selectedFontSize: isNarrow ? 11 : 12,
                unselectedFontSize: isNarrow ? 10 : 12,
                iconSize: isNarrow ? 22 : 24,
                items: [
                  for (final dest in _destinations)
                    BottomNavigationBarItem(
                      label: dest.label,
                      icon: Icon(dest.icon),
                    ),
                ],
              ),
            ),
          );
        }

        final extended = width >= ResponsiveBreakpoints.expanded;
        final minRailHeight = extended ? 300.0 : 380.0;

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: LayoutBuilder(
                  builder: (context, railConstraints) {
                    return SingleChildScrollView(
                      child: SizedBox(
                        height: math.max(
                          railConstraints.maxHeight,
                          minRailHeight,
                        ),
                        child: NavigationRail(
                          extended: extended,
                          labelType: extended
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          backgroundColor: AppColors.card,
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (index) =>
                              context.go(_destinations[index].route),
                          selectedIconTheme: const IconThemeData(
                            color: AppColors.color1,
                          ),
                          unselectedIconTheme: const IconThemeData(
                            color: AppColors.secondaryText,
                          ),
                          selectedLabelTextStyle: const TextStyle(
                            color: AppColors.color1,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelTextStyle: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                          destinations: [
                            for (final dest in _destinations)
                              NavigationRailDestination(
                                icon: Icon(dest.icon),
                                label: Text(dest.label),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.black12,
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
