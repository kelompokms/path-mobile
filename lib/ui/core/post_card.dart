import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

export 'package:path_mobile/utils/lampiran_helper.dart'
    show LampiranItem, UploadLampiranFiles;

class PostCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final DateTime date;
  final VoidCallback? onTap;
  final List<String>? menuLabels;
  final void Function(int index)? onMenuItemSelected;

  const PostCard({
    super.key,
    required this.icon,
    required this.label,
    required this.title,
    required this.date,
    this.onTap,
    this.menuLabels,
    this.onMenuItemSelected,
  });

  bool get _hasMenu => menuLabels != null && onMenuItemSelected != null;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 22, color: AppColors.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  formatTanggal(date),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_hasMenu) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: PopupMenuButton<int>(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.text,
                              ),
                              tooltip: 'Opsi',
                              color: AppColors.background,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: onMenuItemSelected!,
                              itemBuilder: (_) => [
                                for (var i = 0; i < menuLabels!.length; i++)
                                  PopupMenuItem<int>(
                                    value: i,
                                    child: Text(menuLabels![i]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.text,
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

class FileCard extends StatelessWidget {
  final String fileName;
  final String fileType;
  final VoidCallback? onTap;
  final IconData icon;
  final LampiranItem? lampiranItem;
  final String? baseUrl;

  const FileCard({
    super.key,
    required this.fileName,
    required this.fileType,
    this.onTap,
    this.icon = Icons.description_outlined,
    this.lampiranItem,
    this.baseUrl,
  });

  factory FileCard.fromItem(
    LampiranItem item, {
    Key? key,
    VoidCallback? onTap,
    String? baseUrl,
  }) {
    return FileCard(
      key: key,
      fileName: item.name,
      fileType: item.detail,
      icon: item.isLink ? Icons.link : Icons.description_outlined,
      onTap: onTap,
      lampiranItem: item,
      baseUrl: baseUrl,
    );
  }

  Future<void> _openItem(BuildContext context, LampiranItem item) async {
    final err = await openLampiranItem(item, baseUrl: baseUrl);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = lampiranItem;
    final canAutoOpen =
        item != null &&
        (item.isLink || resolveLampiranUri(item, baseUrl: baseUrl) != null);
    final effectiveOnTap =
        onTap ?? (canAutoOpen ? () => _openItem(context, item) : null);

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: effectiveOnTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          color: AppColors.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileType,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 10,
                endIndent: 10,
                color: AppColors.secondaryText.withValues(alpha: 0.3),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Icon(icon, size: 30, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LampiranPickerButtons extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onAddFile;
  final VoidCallback onAddLink;
  final double stackBreakpoint;

  const LampiranPickerButtons({
    super.key,
    required this.isUploading,
    required this.onAddFile,
    required this.onAddLink,
    this.stackBreakpoint = 230,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fileButton = ElevatedButton.icon(
          style: AppTheme.softCompactButton,
          onPressed: isUploading ? null : onAddFile,
          icon: isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(
            isUploading ? 'Mengunggah...' : 'File',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        );
        final linkButton = ElevatedButton.icon(
          style: AppTheme.softCompactButton,
          onPressed: isUploading ? null : onAddLink,
          icon: const Icon(Icons.link, size: 18),
          label: const Text(
            'Link',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12),
          ),
        );
        if (constraints.maxWidth < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fileButton,
              const SizedBox(height: 8),
              linkButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: fileButton),
            const SizedBox(width: 12),
            Expanded(child: linkButton),
          ],
        );
      },
    );
  }
}

class LampiranEditor extends StatefulWidget {
  final List<LampiranItem> items;
  final ValueChanged<List<LampiranItem>> onChanged;
  final UploadLampiranFiles? onUploadFiles;
  final ValueChanged<bool>? onUploadingChanged;
  final String? baseUrl;
  final int maxFiles;

  const LampiranEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.onUploadFiles,
    this.onUploadingChanged,
    this.baseUrl,
    this.maxFiles = maxPostinganFiles,
  });

  @override
  State<LampiranEditor> createState() => _LampiranEditorState();
}

class _LampiranEditorState extends State<LampiranEditor> {
  bool _isBusy = false;
  bool _isUploading = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addFile() async {
    if (_isBusy) return;
    if (widget.items.length >= widget.maxFiles) {
      _showMessage('Maksimal ${widget.maxFiles} lampiran');
      return;
    }

    setState(() => _isBusy = true);
    var notifiedUploading = false;
    try {
      final picked = await pickLampiranFiles();
      if (picked.isEmpty || !mounted) return;

      setState(() => _isUploading = true);
      widget.onUploadingChanged?.call(true);
      notifiedUploading = true;

      final (uploadedItems, err) = await uploadPickedLampiranFiles(
        picked,
        currentCount: widget.items.length,
        onUploadFiles: widget.onUploadFiles,
        maxFiles: widget.maxFiles,
      );
      if (!mounted) return;
      if (err != null) {
        _showMessage(err);
        return;
      }
      if (uploadedItems != null && uploadedItems.isNotEmpty) {
        widget.onChanged([...widget.items, ...uploadedItems]);
      }
    } catch (e) {
      _showMessage('Gagal memilih file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isUploading = false;
        });
        if (notifiedUploading) {
          widget.onUploadingChanged?.call(false);
        }
      }
    }
  }

  Future<void> _addLink() async {
    if (_isBusy) return;
    if (widget.items.length >= widget.maxFiles) {
      _showMessage('Maksimal ${widget.maxFiles} lampiran');
      return;
    }
    final link = await showAddLinkDialog(context, validateUrl: true);
    if (link == null || !mounted) return;
    widget.onChanged([
      ...widget.items,
      LampiranItem(name: 'Link', detail: link, isLink: true, url: link),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lampiran',
              style: TextStyle(fontSize: 11, color: AppColors.text),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < widget.items.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: FileCard.fromItem(
                      widget.items[i],
                      baseUrl: widget.baseUrl,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus lampiran',
                    onPressed: _isUploading
                        ? null
                        : () => widget.onChanged([...widget.items]..removeAt(i)),
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            LampiranPickerButtons(
              isUploading: _isUploading,
              onAddFile: _addFile,
              onAddLink: _addLink,
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showAddLinkDialog(
  BuildContext context, {
  String title = 'Tambahkan link',
  String label = 'Link',
  String buttonLabel = 'Tambah link',
  bool validateUrl = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AddLinkDialog(
      title: title,
      label: label,
      buttonLabel: buttonLabel,
      validateUrl: validateUrl,
    ),
  );
}

class _AddLinkDialog extends StatefulWidget {
  final String title;
  final String label;
  final String buttonLabel;
  final bool validateUrl;

  const _AddLinkDialog({
    required this.title,
    required this.label,
    required this.buttonLabel,
    this.validateUrl = false,
  });

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final normalized = widget.validateUrl ? normalizeLampiranLink(trimmed) : trimmed;
    final canAdd = trimmed.isNotEmpty && normalized != null;
    final errorText = widget.validateUrl && trimmed.isNotEmpty && normalized == null
        ? 'Masukkan link http(s) yang valid'
        : null;

    return AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 13, color: AppColors.text),
        decoration: InputDecoration(
          labelText: '${widget.label}*',
          hintText: widget.validateUrl ? 'https://contoh.com' : widget.label,
          helperText: '*Wajib diisi',
          errorText: errorText,
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.text),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: canAdd ? () => Navigator.pop(context, normalized) : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.color1,
            disabledForegroundColor: AppColors.secondaryText.withValues(
              alpha: 0.4,
            ),
          ),
          child: Text(widget.buttonLabel),
        ),
      ],
    );
  }
}
