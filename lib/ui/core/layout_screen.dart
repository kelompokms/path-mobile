import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({
    super.key,
    required this.child,
    this.isAdmin = false,
    this.userRole,
    this.onOpenProfile,
    this.onLogout,
    this.profilController,
  });

  final Widget child;
  final bool isAdmin;
  final String? userRole;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;
  final ProfilController? profilController;

  static const List<({String route, String label, IconData icon})>
  _muridDestinations = [
    (route: '/beranda', label: 'Beranda', icon: Icons.home),
    (route: '/kelas', label: 'Kelas', icon: Icons.book),
    (route: '/kalender', label: 'Kalender', icon: Icons.calendar_month),
    (route: '/profil', label: 'Profil', icon: Icons.person),
  ];

  static const List<({String route, String label, IconData icon})>
  _guruDestinations = [
    (route: '/beranda', label: 'Beranda', icon: Icons.home),
    (route: '/kelas', label: 'Kelas', icon: Icons.school),
    (route: '/kalender', label: 'Kalender', icon: Icons.calendar_month),
    (route: '/profil', label: 'Profil', icon: Icons.person),
  ];

  static const List<({String route, String label, IconData icon})>
  _adminDestinations = [
    (route: '/beranda', label: 'Beranda', icon: Icons.home),
    (route: '/admin/pengguna', label: 'Guru & Murid', icon: Icons.groups),
    (route: '/kelas', label: 'Kelas', icon: Icons.book),
    (route: '/kalender', label: 'Kalender', icon: Icons.calendar_month),
  ];

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  static const int _maxHistoryLength = 20;

  final List<String> _tabHistory = [];
  String? _currentTabRoute;
  bool _isNavigatingBack = false;

  List<({String route, String label, IconData icon})> get _destinations {
    if (widget.isAdmin) return LayoutScreen._adminDestinations;
    if (widget.userRole?.toLowerCase().trim() == 'guru') {
      return LayoutScreen._guruDestinations;
    }
    return LayoutScreen._muridDestinations;
  }

  String? _tabRouteForLocation(String location) {
    for (final dest in _destinations) {
      if (location == dest.route) return dest.route;
    }
    if (!widget.isAdmin && location == '/pengajar') {
      return '/kelas';
    }
    return null;
  }

  int _calculateSelectedIndex(String location) {
    final int index = _destinations.indexWhere(
      (dest) => location.startsWith(dest.route),
    );
    if (index >= 0) return index;
    if (!widget.isAdmin && location.startsWith('/pengajar')) {
      final kelasIndex = _destinations.indexWhere(
        (dest) => dest.route == '/kelas',
      );
      if (kelasIndex >= 0) return kelasIndex;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _ensureAdminProfilLoaded();
  }

  void _ensureAdminProfilLoaded() {
    final ctrl = widget.profilController;
    if (widget.isAdmin && ctrl != null && ctrl.profil == null && !ctrl.isLoading) {
      Future<void>.microtask(() {
        if (mounted && ctrl.profil == null && !ctrl.isLoading) {
          ctrl.loadProfil();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant LayoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdmin != widget.isAdmin ||
        oldWidget.userRole != widget.userRole) {
      _tabHistory.clear();
      _currentTabRoute = null;
      _isNavigatingBack = false;
    }
    if (oldWidget.isAdmin != widget.isAdmin ||
        oldWidget.profilController != widget.profilController) {
      _ensureAdminProfilLoaded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    final tabRoute = _tabRouteForLocation(location);
    if (tabRoute == null) return;

    if (_currentTabRoute == null) {
      _currentTabRoute = tabRoute;
      return;
    }

    if (tabRoute != _currentTabRoute) {
      if (_isNavigatingBack) {
        _isNavigatingBack = false;
      } else {
        if (_tabHistory.isEmpty || _tabHistory.last != _currentTabRoute) {
          _tabHistory.add(_currentTabRoute!);
          if (_tabHistory.length > _maxHistoryLength) {
            _tabHistory.removeAt(0);
          }
        }
      }
      _currentTabRoute = tabRoute;
    } else if (_isNavigatingBack) {
      _isNavigatingBack = false;
    }
  }

  bool _canSystemPop(String location) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) return false;
    if (_tabHistory.isNotEmpty) return false;
    final tabRoute = _tabRouteForLocation(location);
    if (tabRoute != null && tabRoute != '/beranda') return false;
    return true;
  }

  void _handleBackNavigation(String location) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    if (_tabHistory.isNotEmpty) {
      final previous = _tabHistory.removeLast();
      _isNavigatingBack = true;
      context.go(previous);
      return;
    }
    final tabRoute = _tabRouteForLocation(location);
    if (tabRoute != null && tabRoute != '/beranda') {
      _isNavigatingBack = true;
      context.go('/beranda');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _calculateSelectedIndex(location);
    final isOnProfil = location.startsWith('/profil');
    final profilCtrl = widget.profilController;
    Widget scopedChild = widget.child;
    if (widget.isAdmin && !isOnProfil) {
      Widget buildScope(String? picture, String? baseUrl) => AdminActionScope(
        onOpenProfile:
            widget.onOpenProfile ??
            () => GoRouter.maybeOf(context)?.push('/profil'),
        onLogout:
            widget.onLogout ??
            () async => GoRouter.maybeOf(context)?.go('/login'),
        profilePicture: picture,
        baseUrl: baseUrl,
        child: widget.child,
      );
      scopedChild = profilCtrl != null
          ? ListenableBuilder(
              listenable: profilCtrl,
              builder: (_, _) => buildScope(
                profilCtrl.profil?.profilePicture,
                profilCtrl.baseUrl,
              ),
            )
          : buildScope(null, null);
    }

    return PopScope(
      canPop: _canSystemPop(location),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation(location);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width < ResponsiveBreakpoints.compact) {
            final isNarrow = width < ResponsiveBreakpoints.narrow;
            return Scaffold(
              body: scopedChild,
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
                Expanded(child: scopedChild),
              ],
            ),
          );
        },
      ),
    );
  }
}
