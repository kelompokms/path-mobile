import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class ClassCodeCard extends StatelessWidget {
  final ClassItem classData;

  const ClassCodeCard({super.key, required this.classData});

  void _showBigCode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kode kelas',
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.text),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      classData.code,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  classData.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kode kelas',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: PopupMenuButton<int>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.more_vert, color: AppColors.text),
                    elevation: AppTheme.cardElevation,
                    shadowColor: AppTheme.shadowColor,
                    color: AppColors.background,
                    surfaceTintColor: Colors.transparent,
                    shape: AppTheme.cardShape(),
                    onSelected: (i) {
                      if (i == 0) {
                        copyPengajarText(
                          context,
                          classData.inviteLink,
                          'Link undangan kelas disalin',
                        );
                      } else {
                        copyPengajarText(
                          context,
                          classData.code,
                          'Kode kelas disalin',
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 0,
                        child: Text('Salin link undangan kelas'),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Text('Menyalin kode kelas'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      classData.code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showBigCode(context),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 16,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditPostinganDialog extends StatefulWidget {
  final String headerTitle;
  final String initialTitle;
  final String initialDescription;
  final List<LampiranItem> initialLampiran;
  final UploadLampiranFiles? onUploadFiles;
  final String? baseUrl;
  final String titleHint;
  final String descHint;

  const EditPostinganDialog({
    super.key,
    required this.headerTitle,
    required this.initialTitle,
    required this.initialDescription,
    this.initialLampiran = const [],
    this.onUploadFiles,
    this.baseUrl,
    required this.titleHint,
    required this.descHint,
  });

  @override
  State<EditPostinganDialog> createState() => _EditPostinganDialogState();
}

class _EditPostinganDialogState extends State<EditPostinganDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late List<LampiranItem> _lampiran;
  bool _isUploading = false;

  bool get _hasTitle => _titleCtrl.text.trim().isNotEmpty;
  bool get _canSave => _hasTitle && !_isUploading;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _lampiran = List<LampiranItem>.from(widget.initialLampiran);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSave) return;
    Navigator.pop(context, (
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      lampiran: _lampiran,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.headerTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Edit Judul',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
              TextField(
                controller: _titleCtrl,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 16, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: widget.titleHint,
                  errorText: _hasTitle ? null : 'Judul wajib diisi',
                  isDense: true,
                  border: const UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit Deskripsi',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
              TextField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: widget.descHint,
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: AppColors.text, height: 1),
              const SizedBox(height: 12),
              LampiranEditor(
                items: _lampiran,
                onChanged: (v) => setState(() => _lampiran = v),
                onUploadFiles: widget.onUploadFiles,
                onUploadingChanged: (uploading) {
                  if (mounted) setState(() => _isUploading = uploading);
                },
                baseUrl: widget.baseUrl,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.text,
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _canSave ? _submit : null,
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
