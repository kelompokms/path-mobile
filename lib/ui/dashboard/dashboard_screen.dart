import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
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
    return [
      for (var i = 0; i < ctrl.listKelas.length; i++)
        ctrl.listKelas[i].toClassItem(coverIndex: i),
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
      return Column(
        children: [
          _buildHeader(),
          Expanded(
            child: (ctrl != null && ctrl.isLoading && classes.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : classes.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada kelas yang Anda ajar',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => ctrl?.getListKelas(),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 152,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
          Row(
            children: [
              _buildTabButton('Terdaftar', 0),
              const SizedBox(width: 12),
              _buildTabButton('Pengajar', 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isCurrent = _selectedTab == index;
    void onPressed() => setState(() => _selectedTab = index);

    return SizedBox(
      width: 110,
      child: isCurrent
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
