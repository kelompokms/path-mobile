import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_items.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class TugasDetailScreen extends StatefulWidget {
  final String kodeKelas;
  final TugasData tugas;
  final KelasController? controller;

  const TugasDetailScreen({
    super.key,
    required this.kodeKelas,
    required this.tugas,
    this.controller,
  });

  @override
  State<TugasDetailScreen> createState() => _TugasDetailScreenState();
}

class _TugasDetailScreenState extends State<TugasDetailScreen> {
  bool _composing = false;
  bool _isBusy = false;
  bool _isUploading = false;
  bool _isLoadingPengumpulan = false;

  TugasData get _tugas => widget.tugas;
  List<LampiranItem> get _drafts => _tugas.draftLampiran;

  bool get _canSyncBackend =>
      widget.controller != null &&
      _tugas.id != null &&
      _tugas.id! > 0 &&
      widget.kodeKelas.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _composing = !_tugas.isSubmitted && _drafts.isNotEmpty;
    _loadPengumpulan();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadPengumpulan() async {
    if (!_canSyncBackend) return;

    setState(() => _isLoadingPengumpulan = true);
    try {
      final (pengumpulan, err) = await widget.controller!.getPengumpulanTugas(
        widget.kodeKelas,
        _tugas.id!,
      );
      if (!mounted) return;
      if (err != null) {
        _showMessage(err);
        return;
      }
      if (pengumpulan == null) return;

      setState(() {
        _tugas.score = pengumpulan.nilai;
        if (pengumpulan.submitted) {
          final merged = mergeLampiranWithLocal(
            pengumpulan.lampiranItems,
            [..._tugas.submissionLampiran, ..._drafts],
          );
          _tugas.submissionLampiran
            ..clear()
            ..addAll(merged);
          if (pengumpulan.nilai != null) {
            _tugas.status = 'Dinilai';
          } else {
            _tugas.status = merged.isEmpty
                ? 'Ditandai Sebagai Selesai'
                : 'Dikumpulkan';
          }
          _drafts.clear();
          _composing = false;
        } else {
          _tugas.submissionLampiran.clear();
          _tugas.status = 'Ditugaskan';
          _composing = _drafts.isNotEmpty;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingPengumpulan = false);
      }
    }
  }

  Future<void> _addFile() async {
    if (_isBusy || _isUploading || _isLoadingPengumpulan) return;
    if (_drafts.length >= maxPostinganFiles) {
      _showMessage('Maksimal $maxPostinganFiles lampiran');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final picked = await pickLampiranFiles();
      if (picked.isEmpty || !mounted) return;

      setState(() => _isUploading = true);
      final (uploadedItems, err) = await uploadPickedLampiranFiles(
        picked,
        currentCount: _drafts.length,
        onUploadFiles: widget.controller?.uploadPostinganFiles,
      );
      if (!mounted) return;
      if (err != null) {
        _showMessage(err);
        return;
      }
      if (uploadedItems != null && uploadedItems.isNotEmpty) {
        setState(() => _drafts.addAll(uploadedItems));
      }
    } catch (e) {
      _showMessage('Gagal memilih file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _addLink() async {
    if (_isBusy || _isUploading || _isLoadingPengumpulan) return;
    if (_drafts.length >= maxPostinganFiles) {
      _showMessage('Maksimal $maxPostinganFiles lampiran');
      return;
    }
    final link = await showAddLinkDialog(context, validateUrl: true);
    if (link == null || !mounted) return;
    setState(() {
      _drafts.add(
        LampiranItem(name: 'Link', detail: link, isLink: true, url: link),
      );
    });
  }

  Future<void> _submitPengumpulan({required bool isMarkDone}) async {
    if (_isBusy || _isUploading || _isLoadingPengumpulan) return;
    if (!isMarkDone && _drafts.isEmpty) return;

    final itemsToSubmit = isMarkDone
        ? const <LampiranItem>[]
        : List<LampiranItem>.from(_drafts);

    setState(() => _isBusy = true);
    try {
      List<LampiranItem> syncedItems = itemsToSubmit;
      int? syncedScore;
      if (_canSyncBackend) {
        final paths = isMarkDone
            ? const <String>[]
            : resolveLampiranItemPaths(itemsToSubmit);
        final (result, err) = await widget.controller!.submitPengumpulanTugas(
          widget.kodeKelas,
          _tugas.id!,
          paths,
        );
        if (!mounted) return;
        if (err != null) {
          _showMessage(err);
          return;
        }
        if (result != null) {
          syncedScore = result.nilai;
          syncedItems = mergeLampiranWithLocal(
            result.lampiranItems,
            itemsToSubmit,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _tugas.score = syncedScore ?? _tugas.score;
        _tugas.submissionLampiran
          ..clear()
          ..addAll(syncedItems);
        if (_tugas.score != null) {
          _tugas.status = 'Dinilai';
        } else {
          _tugas.status = syncedItems.isEmpty
              ? 'Ditandai Sebagai Selesai'
              : 'Dikumpulkan';
        }
        _drafts.clear();
        _composing = false;
      });
      _showMessage(
        syncedItems.isEmpty
            ? 'Tugas ditandai sebagai selesai'
            : 'Tugas berhasil diserahkan',
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _tarikPengumpulan() async {
    if (_isBusy || _isUploading || _isLoadingPengumpulan || !_tugas.isSubmitted) {
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Tarik Pengumpulan',
      message: 'Apakah anda yakin ingin menarik pengumpulan tugas ini?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      List<LampiranItem> restoredDrafts = List<LampiranItem>.from(
        _tugas.submissionLampiran,
      );

      if (_canSyncBackend) {
        final (returnedPaths, err) =
            await widget.controller!.tarikPengumpulanTugas(
          widget.kodeKelas,
          _tugas.id!,
        );
        if (!mounted) return;
        if (err != null) {
          _showMessage(err);
          return;
        }
        if (returnedPaths != null && returnedPaths.isNotEmpty) {
          restoredDrafts = mergeLampiranWithLocal(
            parseLampiranItems(returnedPaths),
            _tugas.submissionLampiran,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(restoredDrafts);
        _tugas.submissionLampiran.clear();
        _tugas.score = null;
        _tugas.status = 'Ditugaskan';
        _composing = _drafts.isNotEmpty;
      });
      _showMessage('Pengumpulan tugas berhasil ditarik');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        '${_tugas.author} • ${formatTanggal(_tugas.postedAt)} • ${formatJam(_tugas.postedAt)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn =
            constraints.maxWidth >= ResponsiveBreakpoints.medium;
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: isTwoColumn ? 1120 : 760,
        );

        final details = _buildTaskDetails(meta);
        final submission = _buildSubmissionCard();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: BackTitleRow(title: _tugas.title),
            ),
            Expanded(
              child: isTwoColumn
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(h, 4, h, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: details,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: submission,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          const SizedBox(height: 16),
                          submission,
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskDetails(String meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meta,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${_tugas.points} poin',
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
              _tugas.dueDate == null
                  ? 'Tanpa tenggat'
                  : 'Tenggat: ${formatTanggal(_tugas.dueDate!)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 24,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Nilai',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              '${_tugas.score ?? '...'}/${_tugas.points}',
              key: const Key('murid_nilai_text'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: _tugas.score != null
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _tugas.description,
          style: const TextStyle(fontSize: 12, color: AppColors.text),
        ),
        if (_tugas.lampiran.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final item in _tugas.lampiran) ...[
            FileCard.fromItem(item, baseUrl: widget.controller?.baseUrl),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 16),
        PostCard(
          icon: Icons.list_alt_outlined,
          label: 'Tugas Baru:',
          title: _tugas.title,
          date: _tugas.postedAt,
        ),
      ],
    );
  }

  static final ButtonStyle _primarySubmissionButtonStyle =
      ElevatedButton.styleFrom(
        backgroundColor: AppColors.color1,
        foregroundColor: Colors.white,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        side: AppTheme.thinBorderSide,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      );

  Widget _buildSubmissionCard() {
    final submissionsClosed = !_tugas.acceptSubmissions && !_tugas.isSubmitted;
    final actionsDisabled =
        _isBusy || _isUploading || _isLoadingPengumpulan || submissionsClosed;

    return Card(
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tugas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  submissionsClosed ? 'Ditutup' : _tugas.status,
                  style: TextStyle(
                    fontSize: 11,
                    color: submissionsClosed
                        ? AppColors.error
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            if (submissionsClosed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: const Text(
                  'Pengumpulan tugas sedang ditutup oleh pengajar.',
                  key: Key('submissions_closed_notice'),
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ),
            ],
            if (_isLoadingPengumpulan) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 12),
            if (_tugas.isSubmitted) ...[
              for (final item in _tugas.submissionLampiran) ...[
                FileCard.fromItem(item, baseUrl: widget.controller?.baseUrl),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: actionsDisabled ? null : _tarikPengumpulan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.color1,
                    side: const BorderSide(color: AppColors.color1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Tarik Pengumpulan',
                          style: TextStyle(fontSize: 12),
                        ),
                ),
              ),
            ] else if (_composing) ...[
              for (final draft in _drafts) ...[
                Row(
                  children: [
                    Expanded(
                      child: FileCard.fromItem(
                        draft,
                        baseUrl: widget.controller?.baseUrl,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus lampiran',
                      onPressed: actionsDisabled
                          ? null
                          : () => setState(() => _drafts.remove(draft)),
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
              const SizedBox(height: 10),
              if (_drafts.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: actionsDisabled
                        ? null
                        : () => _submitPengumpulan(isMarkDone: false),
                    style: _primarySubmissionButtonStyle,
                    child: _isBusy && !_isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Serahkan',
                            style: TextStyle(fontSize: 12),
                          ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: actionsDisabled
                        ? null
                        : () => _submitPengumpulan(isMarkDone: true),
                    style: _primarySubmissionButtonStyle,
                    child: const Text(
                      'Tandai Sebagai Selesai',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: actionsDisabled
                      ? null
                      : () => setState(() => _composing = true),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                  style: AppTheme.softCompactButton,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: actionsDisabled
                      ? null
                      : () => _submitPengumpulan(isMarkDone: true),
                  style: _primarySubmissionButtonStyle,
                  child: _isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Tandai Sebagai Selesai',
                          style: TextStyle(fontSize: 12),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
