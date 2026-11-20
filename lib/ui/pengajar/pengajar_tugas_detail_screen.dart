import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/ui/pengajar/pengumpulan_penilaian_screen.dart';
import 'package:path_mobile/ui/pengajar/tugas_form_screen.dart';

class PengajarTugasDetailScreen extends StatefulWidget {
  final ClassItem classData;
  final TugasPengajar tugas;
  final bool isGuru;
  final PengajarController? controller;
  final String? baseUrl;
  final Future<bool> Function(TugasPengajar draft)? onEdited;

  const PengajarTugasDetailScreen({
    super.key,
    required this.classData,
    required this.tugas,
    this.isGuru = true,
    this.controller,
    this.baseUrl,
    this.onEdited,
  });

  @override
  State<PengajarTugasDetailScreen> createState() =>
      _PengajarTugasDetailScreenState();
}

class _PengajarTugasDetailScreenState extends State<PengajarTugasDetailScreen> {
  Future<void> _handleEdit() async {
    final onEdited = widget.onEdited;
    if (onEdited == null) return;
    final saved = await openPage<bool>(
      context,
      breadcrumb: [
        'Pengajar',
        widget.classData.title,
        'Tugas',
        'Edit Tugas',
      ],
      page: TugasFormScreen(
        classData: widget.classData,
        existing: widget.tugas,
        controller: widget.controller,
        onSaved: onEdited,
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final classData = widget.classData;
    final tugas = widget.tugas;
    final isGuru = widget.isGuru;
    final baseUrl = widget.baseUrl;
    final meta =
        'Pengajar • ${formatJam(tugas.postedAt)} • ${formatTanggal(tugas.postedAt)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 800,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: Row(
                children: [
                  Expanded(child: BackTitleRow(title: tugas.title)),
                  if (isGuru && widget.onEdited != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Edit tugas',
                        onPressed: _handleEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${tugas.points} poin',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 10,
                          color: AppColors.secondaryText,
                        ),
                        Text(
                          tugas.dueDate == null
                              ? 'Tanpa tenggat'
                              : 'Tenggat: ${formatTanggal(tugas.dueDate!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    if (tugas.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        tugas.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final item in tugas.lampiran) ...[
                      FileCard.fromItem(item, baseUrl: baseUrl),
                      const SizedBox(height: 12),
                    ],
                    if (isGuru) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'AI bisa membantu guru dalam mengecek jawaban siswa',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => openPage(
                          context,
                          breadcrumb: [
                            'Pengajar',
                            classData.title,
                            tugas.title,
                            'Pengumpulan & Penilaian',
                          ],
                          page: PengumpulanPenilaianScreen(
                            classData: classData,
                            tugas: tugas,
                            postinganId: tugas.id,
                            tugasTitle: tugas.title,
                            controller: widget.controller,
                            baseUrl: baseUrl,
                          ),
                          routeName: 'pengumpulan-penilaian',
                        ),
                        icon: const Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 18,
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        label: const Text('Pengumpulan & Penilaian'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
