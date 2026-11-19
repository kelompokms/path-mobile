import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/ui/pengajar/pengajar_tugas_detail_screen.dart';
import 'package:path_mobile/utils/date_time_helper.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class TugasFormScreen extends StatefulWidget {
  final ClassItem classData;
  final TugasPengajar? existing;
  final PengajarController? controller;
  final Future<bool> Function(TugasPengajar tugas) onSaved;
  final Future<bool> Function(TugasPengajar target, TugasPengajar draft)?
  onEditedCreated;

  const TugasFormScreen({
    super.key,
    required this.classData,
    this.existing,
    this.controller,
    required this.onSaved,
    this.onEditedCreated,
  });

  @override
  State<TugasFormScreen> createState() => _TugasFormScreenState();
}

class _TugasFormScreenState extends State<TugasFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  DateTime? _dueDate;
  bool _accept = true;
  late List<LampiranItem> _lampiran;
  bool _isUploading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;
  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _canSave => _hasTitle && !_isUploading && !_isSaving;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _dueDate = t?.dueDate;
    _accept = t?.acceptSubmissions ?? true;
    _lampiran = List.of(t?.lampiran ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    final existing = widget.existing;
    try {
      if (existing == null) {
        final created = TugasPengajar(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          postedAt: nowGmt7(),
          dueDate: _dueDate,
          lampiran: List<LampiranItem>.from(_lampiran),
        );
        final ok = await widget.onSaved(created);
        if (!mounted || !ok) return;
        replacePage(
          context,
          breadcrumb: ['Pengajar', widget.classData.title, created.title],
          page: PengajarTugasDetailScreen(
            classData: widget.classData,
            tugas: created,
            controller: widget.controller,
            baseUrl: widget.controller?.baseUrl,
            onEdited: widget.onEditedCreated == null
                ? null
                : (draft) => widget.onEditedCreated!(created, draft),
          ),
        );
      } else {
        final draft = TugasPengajar(
          id: existing.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          postedAt: existing.postedAt,
          dueDate: _dueDate,
          lampiran: List<LampiranItem>.from(_lampiran),
          pengumpulan: existing.pengumpulan,
        )..acceptSubmissions = _accept;
        final ok = await widget.onSaved(draft);
        if (!mounted || !ok) return;
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = _isEdit
        ? 'Edit Tenggat Waktu (opsional)'
        : 'Tenggat Waktu (opsional)';
    final dueLabel = _dueDate == null
        ? hint
        : '${formatTanggal(_dueDate!)}, ${formatJam(_dueDate!)}';

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
              child: BackTitleRow(
                title: _isEdit ? 'Edit Tugas' : 'Tambah Tugas',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  spacing: 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEdit)
                      const Text(
                        'Edit Judul',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
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
                        hintText: 'Ketikkan judul tugas',
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
                    if (_isEdit)
                      const Text(
                        'Edit Deskripsi',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
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
                        hintText: 'Deskripsi petunjuk (opsional)',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Switch(
                            value: _accept,
                            onChanged: (v) => setState(() => _accept = v),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Menerima kiriman',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Tenggat waktu',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: InkWell(
                            onTap: _pickDueDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      dueLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            tooltip: 'Hapus tenggat',
                            onPressed: () => setState(() => _dueDate = null),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                      ],
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
