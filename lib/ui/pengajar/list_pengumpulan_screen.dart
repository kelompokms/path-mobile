import 'package:flutter/material.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';

/// Page for teachers to monitor all student submissions on a specific assignment.
class ListPengumpulanScreen extends StatefulWidget {
  final ClassItem classData;
  final int? postinganId;
  final String tugasTitle;
  final PengajarController? controller;
  final String? baseUrl;

  const ListPengumpulanScreen({
    super.key,
    required this.classData,
    required this.postinganId,
    required this.tugasTitle,
    this.controller,
    this.baseUrl,
  });

  @override
  State<ListPengumpulanScreen> createState() => _ListPengumpulanScreenState();
}

class _ListPengumpulanScreenState extends State<ListPengumpulanScreen> {
  bool _isLoading = false;
  String? _error;
  List<PengumpulanMuridModel> _items = const [];

  bool get _canFetch =>
      widget.controller != null &&
      widget.postinganId != null &&
      widget.postinganId! > 0 &&
      widget.classData.code.isNotEmpty;

  String? get _effectiveBaseUrl => widget.baseUrl ?? widget.controller?.baseUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_canFetch) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final (items, err) = await widget.controller!.listPengumpulanTugas(
      widget.classData.code,
      widget.postinganId!,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _error = err;
      if (items != null) {
        _items = items;
      }
    });

    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  String _initialFor(PengumpulanMuridModel item) {
    final trimmed = item.nama.trim();
    if (trimmed.isNotEmpty) return trimmed[0].toUpperCase();
    final email = item.email.trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'M';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 960,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: Row(
                children: [
                  const Expanded(
                    child: BackTitleRow(title: 'Daftar Pengumpulan'),
                  ),
                  if (_canFetch)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Muat ulang',
                        onPressed: _isLoading ? null : _load,
                        icon: const Icon(
                          Icons.refresh,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody(h)),
          ],
        );
      },
    );
  }

  Widget _buildBody(double horizontalPadding) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba lagi'),
                style: AppTheme.softCompactButton,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          4,
          horizontalPadding,
          24,
        ),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 14),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Belum ada murid yang mengumpulkan tugas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            )
          else
            for (final item in _items) ...[
              _buildSubmissionItemCard(item),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tugasTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.classData.title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.color1.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_items.length} Murid Mengumpulkan',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.color1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionItemCard(PengumpulanMuridModel item) {
    final attachments = item.lampiranItems;
    final displayName = item.nama.trim().isNotEmpty
        ? item.nama
        : 'Pengguna #${item.penggunaId}';

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.color1.withValues(alpha: 0.12),
                  child: Text(
                    _initialFor(item),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.color1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      if (item.email.isNotEmpty)
                        Text(
                          item.email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (item.isMarkAsDone
                            ? AppColors.info
                            : AppColors.success)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    item.isMarkAsDone
                        ? 'Ditandai Selesai'
                        : '${attachments.length} Lampiran',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.isMarkAsDone
                          ? AppColors.color3
                          : const Color(0xFF1A7F37),
                    ),
                  ),
                ),
              ],
            ),
            if (item.dibuat != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dikumpulkan pada ${formatJam(item.dibuat!)} • ${formatTanggal(item.dibuat!)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (attachments.isEmpty)
              const Text(
                'Ditandai sebagai selesai tanpa lampiran',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.secondaryText,
                ),
              )
            else
              for (var i = 0; i < attachments.length; i++) ...[
                FileCard.fromItem(attachments[i], baseUrl: _effectiveBaseUrl),
                if (i < attachments.length - 1) const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}
