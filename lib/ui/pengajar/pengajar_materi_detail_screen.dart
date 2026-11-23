import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';

class PengajarMateriDetailScreen extends StatefulWidget {
  final MateriPengajar materi;
  final bool isGuru;
  final String? baseUrl;
  final Future<bool> Function()? onEdit;
  final Future<bool> Function()? onDelete;

  const PengajarMateriDetailScreen({
    super.key,
    required this.materi,
    this.isGuru = false,
    this.baseUrl,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<PengajarMateriDetailScreen> createState() =>
      _PengajarMateriDetailScreenState();
}

class _PengajarMateriDetailScreenState
    extends State<PengajarMateriDetailScreen> {
  Future<void> _handleEdit() async {
    final onEdit = widget.onEdit;
    if (onEdit == null) return;
    final edited = await onEdit();
    if (edited && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleDelete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    final deleted = await onDelete();
    if (deleted && mounted) {
      Navigator.of(context).pop();
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
              child: Row(
                children: [
                  Expanded(child: BackTitleRow(title: materi.title)),
                  if (widget.isGuru && widget.onEdit != null)
                    IconButton(
                      tooltip: 'Edit materi',
                      onPressed: _handleEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.text,
                      ),
                    ),
                  if (widget.isGuru && widget.onDelete != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Hapus materi',
                        onPressed: _handleDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade600,
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
                    if (materi.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        materi.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final item in materi.lampiran) ...[
                      FileCard.fromItem(item, baseUrl: widget.baseUrl),
                      const SizedBox(height: 12),
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
