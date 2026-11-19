import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/utils/date_time_helper.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class BuatMateriScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final ValueChanged<MateriPengajar> onCreated;
  final String initialTitle;
  final String initialDescription;
  final List<LampiranItem> initialLampiran;

  const BuatMateriScreen({
    super.key,
    required this.classData,
    this.controller,
    required this.onCreated,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialLampiran = const [],
  });

  @override
  State<BuatMateriScreen> createState() => _BuatMateriScreenState();
}

class _BuatMateriScreenState extends State<BuatMateriScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late List<LampiranItem> _lampiran;
  bool _isUploading = false;

  bool get _canSave => _titleController.text.trim().isNotEmpty && !_isUploading;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDescription);
    _lampiran = List.of(widget.initialLampiran);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    widget.onCreated(
      MateriPengajar(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        postedAt: nowGmt7(),
        lampiran: _lampiran,
      ),
    );
    Navigator.of(context).popUntil(ModalRoute.withName('pengajar-detail'));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 760,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Buat Materi'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  spacing: 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ketikkan judul materi',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    if (!_canSave)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Isian wajib diisi',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Deskripsi materi (opsional)',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LampiranEditor(
                      items: _lampiran,
                      onChanged: (v) => setState(() => _lampiran = v),
                      onUploadFiles: widget.controller?.uploadPostinganFiles,
                      onUploadingChanged: (uploading) {
                        if (mounted) setState(() => _isUploading = uploading);
                      },
                      baseUrl: widget.controller?.baseUrl,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Atau buat otomatis menggunakan AI',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => openPage(
                        context,
                        breadcrumb: [
                          'Pengajar',
                          widget.classData.title,
                          'Buat Materi',
                        ],
                        page: BuatMateriAiScreen(
                          classData: widget.classData,
                          controller: widget.controller,
                          onCreated: widget.onCreated,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Buat materi dengan AI',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
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

class BuatMateriAiScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final ValueChanged<MateriPengajar> onCreated;

  const BuatMateriAiScreen({
    super.key,
    required this.classData,
    this.controller,
    required this.onCreated,
  });

  @override
  State<BuatMateriAiScreen> createState() => _BuatMateriAiScreenState();
}

class _BuatMateriAiScreenState extends State<BuatMateriAiScreen> {
  static const _baseModes = ['Tabel', 'Diagram', 'Ilustrasi'];
  static const _modes = ['Tabel', 'Diagram', 'Ilustrasi', 'Kombinasi'];

  final _titleController = TextEditingController();
  final _promptController = TextEditingController();
  final Set<String> _selectedModes = {};

  bool get _canCreate =>
      _titleController.text.trim().isNotEmpty &&
      _promptController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _toggleMode(String label) {
    setState(() {
      if (label == 'Kombinasi') {
        if (_selectedModes.contains('Kombinasi')) {
          _selectedModes.clear();
        } else {
          _selectedModes.addAll(_modes);
        }
      } else {
        if (_selectedModes.contains(label)) {
          _selectedModes.remove(label);
          _selectedModes.remove('Kombinasi');
        } else {
          _selectedModes.add(label);
          if (_baseModes.every(_selectedModes.contains)) {
            _selectedModes.add('Kombinasi');
          }
        }
      }
    });
  }

  void _generate() {
    if (!_canCreate) return;
    final title = _titleController.text.trim();
    final prompt = _promptController.text.trim();
    final generated = MateriPengajar(
      title: title,
      description: 'Materi hasil AI untuk topik "$prompt".',
      postedAt: nowGmt7(),
      lampiran: [
        LampiranItem(name: 'Materi_AI_$title.pdf', detail: 'PDF'),
      ],
    );

    openPage(
      context,
      breadcrumb: ['Pengajar', widget.classData.title, 'Buat Materi'],
      page: KonfirmasiMateriAiScreen(
        classData: widget.classData,
        controller: widget.controller,
        materi: generated,
        onCreated: widget.onCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 760,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Buat materi dengan AI'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _generate(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ketikkan judul materi',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptController,
                      onChanged: (_) => setState(() {}),
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _generate(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Apa materi yang ingin anda buat?',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tambahkan elemen pendukung',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in _modes)
                          ElevatedButton(
                            onPressed: () => _toggleMode(label),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedModes.contains(label)
                                  ? AppColors.color1
                                  : AppColors.card,
                              foregroundColor: _selectedModes.contains(label)
                                  ? Colors.white
                                  : AppColors.text,
                              elevation: AppTheme.cardElevation,
                              shadowColor: AppTheme.shadowColor,
                              side: AppTheme.thinBorderSide,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.cardRadius,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minimumSize: const Size(0, 32),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: Text(label),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _canCreate ? _generate : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Buat materi'),
                    ),
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

class KonfirmasiMateriAiScreen extends StatelessWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final MateriPengajar materi;
  final ValueChanged<MateriPengajar> onCreated;

  const KonfirmasiMateriAiScreen({
    super.key,
    required this.classData,
    this.controller,
    required this.materi,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
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
              child: BackTitleRow(title: materi.title),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materi.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in materi.lampiran) ...[
                      FileCard.fromItem(item, baseUrl: controller?.baseUrl),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Apakah anda ingin menggunakan materi ini ?',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: () {
                            onCreated(materi);
                            Navigator.of(context).popUntil(
                              ModalRoute.withName('pengajar-detail'),
                            );
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Materi berhasil dibuat'),
                                ),
                              );
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.cardRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: const Text('Gunakan materi'),
                        ),
                        ElevatedButton(
                          style: AppTheme.softCompactButton,
                          onPressed: () => replacePage(
                            context,
                            breadcrumb: [
                              'Pengajar',
                              classData.title,
                              'Buat Materi',
                            ],
                            page: BuatMateriScreen(
                              classData: classData,
                              controller: controller,
                              onCreated: onCreated,
                              initialTitle: materi.title,
                              initialDescription: materi.description,
                              initialLampiran: materi.lampiran,
                            ),
                          ),
                          child: const Text('Sesuaikan'),
                        ),
                      ],
                    ),
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
