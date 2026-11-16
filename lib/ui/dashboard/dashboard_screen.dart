import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';

class DashboardScreen extends StatefulWidget {
  final KelasController? kelasController;
  final PengajarController? pengajarController;

  const DashboardScreen({
    super.key,
    this.kelasController,
    this.pengajarController,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    widget.pengajarController?.getListKelas();
  }

  List<ClassItem> get _teachingClasses {
    final ctrl = widget.pengajarController;
    if (ctrl == null) return const [];
    final teaching = ctrl.listKelas.where((k) => k.guru).toList();
    return [
      for (var i = 0; i < teaching.length; i++)
        teaching[i].toClassItem(coverIndex: i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Beranda'],
      child: _selectedTab == 1
          ? _buildTeachingTab()
          : RegisteredClassesSection(
              controller: widget.kelasController,
              breadcrumbRoot: 'Beranda',
              emptyMessage:
                  'Anda belum memiliki kelas atau bergabung ke kelas manapun',
              emptyHint: 'Gabung Kelas atau Tambah Kelas',
              onAddClass: () => context.go('/pengajar'),
              listTopBar: _buildHeader(),
            ),
    );
  }

  Widget _buildTeachingTab() {
    final ctrl = widget.pengajarController;

    Widget buildContent() {
      final classes = _teachingClasses;
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: (ctrl != null && ctrl.isLoading && classes.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : classes.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Belum ada kelas yang Anda ajar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ctrl?.getListKelas(),
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
                          itemBuilder: (context, i) {
                            final item = classes[i];
                            return ClassCard(
                              data: item,
                              onTap: () => openPage(
                                context,
                                breadcrumb: ['Beranda', item.title],
                                page: PengajarDetailScreen(
                                  classData: item,
                                  controller: ctrl,
                                  breadcrumbRoot: 'Beranda',
                                ),
                                routeName: 'pengajar-detail',
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      );
    }

    if (ctrl == null) return buildContent();
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => buildContent(),
    );
  }

  Widget _buildHeader() {
    final textTheme = Theme.of(context).textTheme;
    final title = _selectedTab == 0 ? 'Kelas Terdaftar' : 'Pengajar';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: ResponsiveBreakpoints.wide,
        );
        return SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.fromLTRB(h, 12, h, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildTabButton('Terdaftar', 0),
                    _buildTabButton('Pengajar', 1),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isCurrent = _selectedTab == index;
    void onPressed() {
      if (_selectedTab == index) return;
      setState(() => _selectedTab = index);
      if (index == 0) {
        widget.kelasController?.getListKelas();
      } else {
        widget.pengajarController?.getListKelas();
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 104),
      child: isCurrent
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
