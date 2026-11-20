import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_detail_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';

export 'buat_materi_screen.dart';
export 'koreksi_ai_screen.dart';
export 'pengajar_detail_screen.dart';
export 'pengajar_items.dart';
export 'pengajar_materi_detail_screen.dart';
export 'pengajar_tugas_detail_screen.dart';
export 'pengajar_widgets.dart';
export 'pengumpulan_penilaian_screen.dart';
export 'tugas_form_screen.dart';

class PengajarScreen extends StatelessWidget {
  final PengajarController controller;

  const PengajarScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Pengajar'],
      child: TeachingClassesSection(
        controller: controller,
        breadcrumbRoot: 'Pengajar',
      ),
    );
  }
}

/// Reusable list/grid of classes where the signed-in user holds a teaching/assistant role (`k.guru`).
class TeachingClassesSection extends StatefulWidget {
  final PengajarController controller;
  final String breadcrumbRoot;
  final String headerTitle;
  final bool showHeader;
  final bool fetchOnInit;
  final String emptyMessage;
  final String emptyHint;

  const TeachingClassesSection({
    super.key,
    required this.controller,
    this.breadcrumbRoot = 'Pengajar',
    this.headerTitle = 'Kelas',
    this.showHeader = true,
    this.fetchOnInit = true,
    this.emptyMessage = 'Anda belum ditugaskan mengampu kelas',
    this.emptyHint =
        'Hanya admin yang dapat membuat atau menetapkan pengampu kelas',
  });

  @override
  State<TeachingClassesSection> createState() => _TeachingClassesSectionState();
}

class _TeachingClassesSectionState extends State<TeachingClassesSection> {
  @override
  void initState() {
    super.initState();
    if (widget.fetchOnInit) {
      widget.controller.getListKelas();
    }
  }

  List<ClassItem> get _classes {
    final teaching = widget.controller.listKelas.where((k) => k.guru).toList();
    return [
      for (var i = 0; i < teaching.length; i++)
        teaching[i].toClassItem(coverIndex: i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final classes = _classes;
        if (widget.controller.isLoading && classes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (classes.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: EmptyClassView(
                message: widget.emptyMessage,
                hint: widget.emptyHint,
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final h = responsiveHorizontalInset(
              width,
              maxWidth: ResponsiveBreakpoints.wide,
            );

            return Column(
              children: [
                if (widget.showHeader)
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(h, 12, h, 12),
                      child: Text(
                        widget.headerTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: widget.controller.getListKelas,
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
                            breadcrumb: [widget.breadcrumbRoot, item.title],
                            page: PengajarDetailScreen(
                              classData: item,
                              controller: widget.controller,
                              breadcrumbRoot: widget.breadcrumbRoot,
                            ),
                            routeName: 'pengajar-detail',
                          ),
                          menuItems: [
                            (
                              label: 'Edit kelas',
                              onSelected: () => editKelasWithDialog(
                                context,
                                item,
                                widget.controller,
                              ),
                            ),
                            (
                              label: 'Salin link undangan kelas',
                              onSelected: () => copyPengajarText(
                                context,
                                item.inviteLink,
                                'Link undangan kelas disalin',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
