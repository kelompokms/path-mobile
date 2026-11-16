import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';

class LampiranItem {
  final String name;
  final String detail;
  final bool isLink;

  const LampiranItem({
    required this.name,
    required this.detail,
    this.isLink = false,
  });
}

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

  const FileCard({
    super.key,
    required this.fileName,
    required this.fileType,
    this.onTap,
    this.icon = Icons.description_outlined,
  });

  factory FileCard.fromItem(LampiranItem item, {VoidCallback? onTap}) {
    return FileCard(
      fileName: item.name,
      fileType: item.detail,
      icon: item.isLink ? Icons.link : Icons.description_outlined,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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

class LampiranEditor extends StatelessWidget {
  final List<LampiranItem> items;
  final ValueChanged<List<LampiranItem>> onChanged;

  const LampiranEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  Future<void> _addFile(BuildContext context) async {
    final name = await showAddLinkDialog(
      context,
      title: 'Tambahkan file',
      label: 'Nama file',
      buttonLabel: 'Tambah file',
    );
    if (name == null || !context.mounted) return;
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'PDF';
    onChanged([
      ...items,
      LampiranItem(name: name, detail: ext),
    ]);
  }

  Future<void> _addLink(BuildContext context) async {
    final link = await showAddLinkDialog(context);
    if (link == null || !context.mounted) return;
    onChanged([
      ...items,
      LampiranItem(name: 'Link', detail: link, isLink: true),
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
            for (var i = 0; i < items.length; i++) ...[
              Row(
                children: [
                  Expanded(child: FileCard.fromItem(items[i])),
                  IconButton(
                    tooltip: 'Hapus lampiran',
                    onPressed: () => onChanged([...items]..removeAt(i)),
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: AppTheme.softCompactButton,
                    onPressed: () => _addFile(context),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('File'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: AppTheme.softCompactButton,
                    onPressed: () => _addLink(context),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Link'),
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

Future<String?> showAddLinkDialog(
  BuildContext context, {
  String title = 'Tambahkan link',
  String label = 'Link',
  String buttonLabel = 'Tambah link',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AddLinkDialog(
      title: title,
      label: label,
      buttonLabel: buttonLabel,
    ),
  );
}

class _AddLinkDialog extends StatefulWidget {
  final String title;
  final String label;
  final String buttonLabel;

  const _AddLinkDialog({
    required this.title,
    required this.label,
    required this.buttonLabel,
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
    final canAdd = _controller.text.trim().isNotEmpty;

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
          hintText: widget.label,
          helperText: '*Wajib diisi',
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
          onPressed: canAdd
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
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
