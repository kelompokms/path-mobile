import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/class_detail_screen.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';

export 'class_detail_screen.dart';
export 'kelas_items.dart';
export 'materi_detail_screen.dart';
export 'tugas_detail_screen.dart';

/// Role-aware Classes screen:
/// - Universal `guru` defaults to the `Mengajar` tab with secondary `Diikuti` tab.
/// - Universal `murid` shows enrolled classes directly, and adaptively reveals
///   a `Mendampingi` tab when promoted as a class assistant (`k.guru == true`).
class KelasScreen extends StatefulWidget {
  final KelasController controller;
  final PengajarController? pengajarController;
  final bool isGuruRole;

  const KelasScreen({
    super.key,
    required this.controller,
    this.pengajarController,
    this.isGuruRole = false,
  });

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final pengajarCtrl = widget.pengajarController;
    if (pengajarCtrl != null) {
      Future<void>.microtask(() {
        if (mounted) {
          pengajarCtrl.getListKelas();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant KelasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuruRole != widget.isGuruRole) {
      setState(() => _selectedTab = 0);
      Future<void>.microtask(() {
        if (!mounted) return;
        widget.controller.getListKelas();
        widget.pengajarController?.getListKelas();
      });
    }
  }

  Widget _buildModeChip({
    required String label,
    required int tabIndex,
    required Key key,
  }) {
    final active = _selectedTab == tabIndex;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: active,
      onSelected: (_) {
        if (_selectedTab == tabIndex) return;
        setState(() => _selectedTab = tabIndex);
        if (widget.isGuruRole) {
          if (tabIndex == 0) {
            widget.pengajarController?.getListKelas();
          } else {
            widget.controller.getListKelas();
          }
        } else {
          if (tabIndex == 0) {
            widget.controller.getListKelas();
          } else {
            widget.pengajarController?.getListKelas();
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pengajarCtrl = widget.pengajarController;
    if (pengajarCtrl == null) {
      return PageFrame(
        breadcrumb: const ['Kelas'],
        child: RegisteredClassesSection(
          controller: widget.controller,
          breadcrumbRoot: 'Kelas',
          emptyMessage: 'Anda belum bergabung kelas manapun',
        ),
      );
    }

    return PageFrame(
      breadcrumb: const ['Kelas'],
      child: ListenableBuilder(
        listenable: pengajarCtrl,
        builder: (context, _) {
          final hasAssistantClasses = pengajarCtrl.listKelas.any((k) => k.guru);
          final showTeaching =
              (widget.isGuruRole && _selectedTab == 0) ||
              (!widget.isGuruRole && hasAssistantClasses && _selectedTab == 1);
          final showSwitcher = widget.isGuruRole || hasAssistantClasses;

          return Column(
            children: [
              if (showSwitcher)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final h = responsiveHorizontalInset(
                      constraints.maxWidth,
                      maxWidth: ResponsiveBreakpoints.wide,
                    );
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(h, 12, h, 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.isGuruRole
                            ? [
                                _buildModeChip(
                                  key: const Key('kelas_tab_mengajar'),
                                  label: 'Mengajar',
                                  tabIndex: 0,
                                ),
                                _buildModeChip(
                                  key: const Key('kelas_tab_diikuti'),
                                  label: 'Diikuti',
                                  tabIndex: 1,
                                ),
                              ]
                            : [
                                _buildModeChip(
                                  key: const Key('kelas_tab_diikuti'),
                                  label: 'Diikuti',
                                  tabIndex: 0,
                                ),
                                _buildModeChip(
                                  key: const Key('kelas_tab_mendampingi'),
                                  label: 'Mendampingi',
                                  tabIndex: 1,
                                ),
                              ],
                      ),
                    );
                  },
                ),
              Expanded(
                child: showTeaching
                    ? TeachingClassesSection(
                        controller: pengajarCtrl,
                        breadcrumbRoot: 'Kelas',
                        headerTitle: widget.isGuruRole
                            ? 'Kelas Mengajar'
                            : 'Kelas Didampingi',
                        fetchOnInit: false,
                        emptyMessage: widget.isGuruRole
                            ? 'Anda belum ditugaskan mengampu kelas'
                            : 'Belum ada kelas yang Anda dampingi',
                      )
                    : RegisteredClassesSection(
                        controller: widget.controller,
                        breadcrumbRoot: 'Kelas',
                        emptyMessage: 'Anda belum bergabung kelas manapun',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RegisteredClassesSection extends StatefulWidget {
  final KelasController? controller;
  final String breadcrumbRoot;
  final String emptyMessage;
  final String? emptyHint;
  final VoidCallback? onAddClass;
  final Widget? listTopBar;

  const RegisteredClassesSection({
    super.key,
    this.controller,
    required this.breadcrumbRoot,
    required this.emptyMessage,
    this.emptyHint,
    this.onAddClass,
    this.listTopBar,
  });

  @override
  State<RegisteredClassesSection> createState() =>
      _RegisteredClassesSectionState();
}

class _RegisteredClassesSectionState extends State<RegisteredClassesSection> {
  bool _isJoining = false;
  final List<ClassItem> _fallbackClasses = [];

  @override
  void initState() {
    super.initState();
    widget.controller?.getListKelas();
  }

  List<ClassItem> get _classes {
    final ctrl = widget.controller;
    if (ctrl == null) return _fallbackClasses;
    final enrolled = ctrl.listKelas.where((k) => !k.guru).toList();
    return [
      for (var i = 0; i < enrolled.length; i++)
        enrolled[i].toClassItem(coverIndex: i),
    ];
  }

  void _openClass(ClassItem data) {
    final trail = [widget.breadcrumbRoot, data.title];
    openPage(
      context,
      breadcrumb: trail,
      page: ClassDetailScreen(
        classData: data,
        breadcrumb: trail,
        controller: widget.controller,
      ),
    );
  }

  Future<void> _confirmLeave(ClassItem data) async {
    final yes = await showConfirmDialog(
      context,
      title: 'Batalkan Pendaftaran',
      message: 'Apakah anda yakin ingin membatalkan pendaftaran',
    );
    if (!yes || !mounted) return;

    final ctrl = widget.controller;
    if (ctrl != null) {
      final err = await ctrl.leaveKelas(data.code);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(err)));
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Berhasil keluar dari kelas')),
          );
      }
    } else {
      setState(() => _fallbackClasses.remove(data));
    }
  }

  Future<void> _handleJoinClass(String code) async {
    final ctrl = widget.controller;
    if (ctrl != null) {
      final err = await ctrl.joinKelas(code);
      if (!mounted) return;
      if (err != null) {
        await showInfoDialog(
          context,
          title: 'Terjadi error',
          message: err,
        );
        return;
      }
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Berhasil bergabung ke dalam kelas')),
        );
    } else {
      setState(() {
        _fallbackClasses.add(
          ClassItem(
            title: 'Kelas $code',
            grade: 'Kelas X',
            teacher: 'Pengajar',
            coverIndex: _fallbackClasses.length,
            code: code,
          ),
        );
        _isJoining = false;
      });
    }
  }

  Widget _buildBody(BuildContext context) {
    final ctrl = widget.controller;

    if (_isJoining) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: JoinClassForm(
            onCancel: () => setState(() => _isJoining = false),
            onJoined: _handleJoinClass,
          ),
        ),
      );
    }

    if (ctrl != null && ctrl.isLoading && ctrl.listKelas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final classes = _classes;

    if (classes.isEmpty) {
      return Column(
        children: [
          if (widget.listTopBar != null) widget.listTopBar!,
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: EmptyClassView(
                  message: widget.emptyMessage,
                  hint: widget.emptyHint,
                  onJoinClass: () => setState(() => _isJoining = true),
                  onAddClass: widget.onAddClass,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final h = responsiveHorizontalInset(
          width,
          maxWidth: ResponsiveBreakpoints.wide,
        );

        return Column(
          children: [
            widget.listTopBar ??
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(h, 12, h, 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Kelas Terdaftar',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isJoining = true),
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text('Gabung Kelas'),
                          style: AppTheme.softCompactButton,
                        ),
                      ],
                    ),
                  ),
                ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => widget.controller?.getListKelas(),
                child: GridView.builder(
                  padding: responsiveListPadding(
                    width,
                    maxWidth: ResponsiveBreakpoints.wide,
                    top: 0,
                    bottom: 16,
                  ),
                  gridDelegate: responsiveClassGridDelegate(
                    context,
                    width,
                    maxContentWidth: ResponsiveBreakpoints.wide,
                  ),
                  itemCount: classes.length,
                  itemBuilder: (context, index) => ClassCard(
                    data: classes[index],
                    onTap: () => _openClass(classes[index]),
                    menuLabel: 'Batalkan Pendaftaran',
                    onMenuSelected: () => _confirmLeave(classes[index]),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (ctrl == null) {
      return _buildBody(context);
    }
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => _buildBody(context),
    );
  }
}
