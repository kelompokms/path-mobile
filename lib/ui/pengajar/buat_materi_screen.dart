import 'dart:async';

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

typedef MateriCreatedCallback = FutureOr<bool> Function(MateriPengajar materi);

class BuatMateriScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final String breadcrumbRoot;
  final MateriCreatedCallback onCreated;
  final String initialTitle;
  final String initialDescription;
  final List<LampiranItem> initialLampiran;

  const BuatMateriScreen({
    super.key,
    required this.classData,
    this.controller,
    this.breadcrumbRoot = 'Pengajar',
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
  bool _isSaving = false;

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _canSave => _hasTitle && !_isUploading && !_isSaving;

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

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final ok = await widget.onCreated(
        MateriPengajar(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          postedAt: nowGmt7(),
          lampiran: _lampiran,
        ),
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).popUntil(ModalRoute.withName('pengajar-detail'));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (!_hasTitle)
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
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan'),
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
                      onPressed: _isSaving
                          ? null
                          : () => openPage(
                              context,
                              breadcrumb: [
                                widget.breadcrumbRoot,
                                widget.classData.title,
                                'Buat Materi',
                              ],
                              page: BuatMateriAiScreen(
                                classData: widget.classData,
                                controller: widget.controller,
                                breadcrumbRoot: widget.breadcrumbRoot,
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
  final String breadcrumbRoot;
  final MateriCreatedCallback onCreated;

  const BuatMateriAiScreen({
    super.key,
    required this.classData,
    this.controller,
    this.breadcrumbRoot = 'Pengajar',
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
  bool _generating = false;
  bool _gunakanModelGratis = false;

  bool get _usesImageMode =>
      _selectedModes.contains('Ilustrasi') ||
      _selectedModes.contains('Kombinasi');

  bool get _effectiveFreeModel => !_usesImageMode && _gunakanModelGratis;

  bool get _canCreate =>
      !_generating &&
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
      if (_usesImageMode) {
        _gunakanModelGratis = false;
      }
    });
  }

  Future<void> _generate() async {
    if (!_canCreate) return;
    final title = _titleController.text.trim();
    final prompt = _promptController.text.trim();
    final ctrl = widget.controller;

    MateriPengajar generated;
    if (ctrl == null) {
      generated = MateriPengajar(
        title: title,
        description: 'Materi hasil AI untuk topik "$prompt".',
        postedAt: nowGmt7(),
        lampiran: [
          LampiranItem(name: 'Materi_AI_$title.pdf', detail: 'PDF'),
        ],
      );
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _generating = true);
      final (res, err) = await ctrl.generateMateriAi(
        judul: title,
        deskripsiMateri: prompt,
        jenjang: widget.classData.grade,
        tabel: _selectedModes.contains('Tabel'),
        diagram: _selectedModes.contains('Diagram'),
        ilustrasi: _selectedModes.contains('Ilustrasi'),
        kombinasi: _selectedModes.contains('Kombinasi'),
        gunakanModelGratis: _effectiveFreeModel,
      );
      if (!mounted) return;
      setState(() => _generating = false);
      if (err != null || res == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(err ?? 'Gagal membuat materi dengan AI')),
          );
        return;
      }
      generated = MateriPengajar(
        title: res.judul.isNotEmpty ? res.judul : title,
        description: res.deskripsi.isNotEmpty
            ? res.deskripsi
            : 'Materi hasil AI untuk topik "$prompt".',
        postedAt: nowGmt7(),
        lampiran: res.lampiran,
      );
    }

    openPage(
      context,
      breadcrumb: [widget.breadcrumbRoot, widget.classData.title, 'Buat Materi'],
      page: KonfirmasiMateriAiScreen(
        classData: widget.classData,
        controller: widget.controller,
        breadcrumbRoot: widget.breadcrumbRoot,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          key: const Key('buat_materi_ai_free_model_switch'),
                          value: _effectiveFreeModel,
                          onChanged: (_generating || _usesImageMode)
                              ? null
                              : (v) => setState(() => _gunakanModelGratis = v),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _usesImageMode
                                ? 'Model AI gratis (nonaktif untuk Ilustrasi/Kombinasi)'
                                : 'Gunakan model AI gratis',
                            style: TextStyle(
                              fontSize: 11,
                              color: _usesImageMode
                                  ? AppColors.secondaryText
                                  : AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                      child: _generating
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Membuat materi AI...'),
                              ],
                            )
                          : const Text('Buat materi'),
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

class KonfirmasiMateriAiScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final String breadcrumbRoot;
  final MateriPengajar materi;
  final MateriCreatedCallback onCreated;

  const KonfirmasiMateriAiScreen({
    super.key,
    required this.classData,
    this.controller,
    this.breadcrumbRoot = 'Pengajar',
    required this.materi,
    required this.onCreated,
  });

  @override
  State<KonfirmasiMateriAiScreen> createState() =>
      _KonfirmasiMateriAiScreenState();
}

class _KonfirmasiMateriAiScreenState extends State<KonfirmasiMateriAiScreen> {
  bool _isSaving = false;

  Future<void> _useMateri() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final ok = await widget.onCreated(widget.materi);
      if (!mounted) return;
      if (ok) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil(ModalRoute.withName('pengajar-detail'));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Materi berhasil dibuat')),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final materi = widget.materi;
    final meta =
        'Pengajar • ${formatTanggal(materi.postedAt)} • ${formatJam(materi.postedAt)}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 800,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      meta,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      materi.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in materi.lampiran) ...[
                      FileCard.fromItem(
                        item,
                        baseUrl: widget.controller?.baseUrl,
                      ),
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
                          onPressed: _isSaving ? null : _useMateri,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.cardRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Gunakan materi'),
                        ),
                        ElevatedButton(
                          style: AppTheme.softCompactButton,
                          onPressed: _isSaving
                              ? null
                              : () => replacePage(
                                  context,
                                  breadcrumb: [
                                    widget.breadcrumbRoot,
                                    widget.classData.title,
                                    'Buat Materi',
                                  ],
                                  page: BuatMateriScreen(
                                    classData: widget.classData,
                                    controller: widget.controller,
                                    breadcrumbRoot: widget.breadcrumbRoot,
                                    onCreated: widget.onCreated,
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
