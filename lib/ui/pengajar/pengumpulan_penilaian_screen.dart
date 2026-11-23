import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/core/user_avatar.dart';
import 'package:path_mobile/ui/pengajar/koreksi_ai_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/utils/date_time_helper.dart';

/// Unified teacher screen combining assignment submission monitoring
/// (`GET /kelas/:kode/postingan/:id/pengumpulan` + class members) with
/// manual & AI-assisted grading (`PATCH .../pengumpulan/nilai`).
class PengumpulanPenilaianScreen extends StatefulWidget {
  final ClassItem classData;
  final TugasPengajar? tugas;
  final int? postinganId;
  final String? tugasTitle;
  final PengajarController? controller;
  final String? baseUrl;

  const PengumpulanPenilaianScreen({
    super.key,
    required this.classData,
    this.tugas,
    this.postinganId,
    this.tugasTitle,
    this.controller,
    this.baseUrl,
  });

  @override
  State<PengumpulanPenilaianScreen> createState() =>
      _PengumpulanPenilaianScreenState();
}

class _PengumpulanPenilaianScreenState
    extends State<PengumpulanPenilaianScreen> {
  static const _statuses = PengumpulanStatus.all;
  static const _filters = PengumpulanStatus.filters;

  late final TugasPengajar _tugas;
  String _filter = 'Semua';
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTogglingAccept = false;
  bool _checkingAi = false;
  bool _gunakanModelGratis = false;
  String? _error;
  List<AnggotaKelasModel> _studentMembers = const [];
  List<PengumpulanItem> _items = const [];
  final Map<String, TextEditingController> _scoreControllers = {};
  final Set<String> _expandedSubmissions = {};

  int? get _postinganId => widget.postinganId ?? widget.tugas?.id;

  String get _tugasTitle =>
      widget.tugasTitle ?? widget.tugas?.title ?? 'Tugas';

  bool get _canFetch =>
      widget.controller != null &&
      _postinganId != null &&
      _postinganId! > 0 &&
      widget.classData.code.isNotEmpty;

  String? get _effectiveBaseUrl => widget.baseUrl ?? widget.controller?.baseUrl;

  int get _submittedCount => _items.where((p) => p.isSubmitted).length;

  @override
  void initState() {
    super.initState();
    _tugas =
        widget.tugas ??
        TugasPengajar(
          id: widget.postinganId,
          title: widget.tugasTitle ?? 'Tugas',
          description: '',
          postedAt: DateTime.now(),
        );
    _items = List<PengumpulanItem>.from(_tugas.pengumpulan);
    _syncScoreControllers();
    _load();
  }

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PengumpulanItem p) {
    return _scoreControllers.putIfAbsent(
      p.keyId,
      () => TextEditingController(text: p.score?.toString() ?? ''),
    );
  }

  void _syncScoreControllers() {
    for (final p in _items) {
      final ctrl = _controllerFor(p);
      final target = p.score?.toString() ?? '';
      if (ctrl.text != target) {
        ctrl.text = target;
      }
    }
  }

  List<PengumpulanItem> _mergeFromApi(
    List<PengumpulanMuridModel> submissions,
    List<AnggotaKelasModel> members,
  ) {
    final merged = <PengumpulanItem>[];
    final seenUserIds = <int>{};
    final dueDate = _tugas.dueDate;
    final now = nowGmt7();
    final isPastDue = dueDate != null && now.isAfter(dueDate);

    for (final sub in submissions) {
      if (sub.penggunaId > 0) {
        seenUserIds.add(sub.penggunaId);
      }
      final displayName = sub.nama.trim().isNotEmpty
          ? sub.nama.trim()
          : 'Pengguna #${sub.penggunaId}';
      final isLate =
          dueDate != null && sub.dibuat != null && sub.dibuat!.isAfter(dueDate);
      final status = sub.nilai != null
          ? PengumpulanStatus.sudahDinilai
          : (isLate
                ? PengumpulanStatus.terlambat
                : PengumpulanStatus.diserahkan);
      merged.add(
        PengumpulanItem(
          penggunaId: sub.penggunaId,
          studentName: displayName,
          email: sub.email,
          profilePicture: sub.profilePicture,
          lampiran: sub.lampiranItems,
          submittedAt: sub.dibuat,
          isSubmitted: true,
          isLate: isLate,
          status: status,
          score: sub.nilai,
        ),
      );
    }

    for (final member in members) {
      if (member.isGuru) continue;
      if (member.penggunaId > 0 && seenUserIds.contains(member.penggunaId)) {
        continue;
      }
      final displayName = member.nama.trim().isNotEmpty
          ? member.nama.trim()
          : 'Pengguna #${member.penggunaId}';
      merged.add(
        PengumpulanItem(
          penggunaId: member.penggunaId,
          studentName: displayName,
          email: member.email,
          profilePicture: member.profilePicture,
          isSubmitted: false,
          status: isPastDue
              ? PengumpulanStatus.tidakMengumpulkan
              : PengumpulanStatus.belumMengumpulkan,
        ),
      );
    }

    return merged;
  }

  Future<void> _load() async {
    if (!_canFetch) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      widget.controller!.listPengumpulanTugas(
        widget.classData.code,
        _postinganId!,
      ),
      widget.controller!.getListAnggota(widget.classData.code),
    ]);
    if (!mounted) return;

    final (submissions, subErr) =
        results[0] as (List<PengumpulanMuridModel>?, String?);
    final (members, membersErr) =
        results[1] as (List<AnggotaKelasModel>?, String?);

    setState(() {
      _isLoading = false;
      _error = subErr;
      if (members != null) {
        _studentMembers = members;
      }
      if (submissions != null) {
        _items = _mergeFromApi(submissions, _studentMembers);
        _tugas.pengumpulan
          ..clear()
          ..addAll(_items);
        _syncScoreControllers();
      }
    });

    final toastErr = subErr ?? membersErr;
    if (toastErr != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(toastErr)));
    }
  }

  Future<bool> _saveScores({Map<String, int>? overrideScores}) async {
    FocusScope.of(context).unfocus();
    if (_isSaving) return false;

    final payload = <int, int?>{};
    final localUpdates = <PengumpulanItem, int?>{};
    var hasInvalidInput = false;

    for (final p in _items) {
      final override = overrideScores?[p.keyId];
      final rawText = override != null
          ? '$override'
          : (_scoreControllers[p.keyId]?.text.trim() ?? '');

      if (rawText.isEmpty) {
        if (p.score != null && overrideScores == null) {
          localUpdates[p] = null;
          if (p.penggunaId != null && p.penggunaId! > 0) {
            payload[p.penggunaId!] = null;
          }
        }
        continue;
      }

      final parsed = int.tryParse(rawText);
      if (parsed == null) {
        hasInvalidInput = true;
        continue;
      }
      final clamped = parsed.clamp(0, _tugas.points);
      localUpdates[p] = clamped;
      if (p.penggunaId != null && p.penggunaId! > 0) {
        payload[p.penggunaId!] = clamped;
      }
    }

    if (hasInvalidInput && payload.isEmpty && localUpdates.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Masukkan nilai berupa angka bulat')),
        );
      return false;
    }

    if (payload.isEmpty && localUpdates.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Belum ada nilai yang diisi')),
        );
      return false;
    }

    if (_canFetch && payload.isNotEmpty) {
      setState(() => _isSaving = true);
      final (updated, err) = await widget.controller!.simpanNilaiPengumpulan(
        widget.classData.code,
        _postinganId!,
        payload,
      );
      if (!mounted) return false;

      if (err != null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(err)));
        return false;
      }

      setState(() {
        _isSaving = false;
        if (updated != null) {
          _items = _mergeFromApi(updated, _studentMembers);
          _tugas.pengumpulan
            ..clear()
            ..addAll(_items);
          _syncScoreControllers();
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nilai berhasil disimpan')),
        );
      return true;
    }

    setState(() {
      final isPastDue =
          _tugas.dueDate != null && nowGmt7().isAfter(_tugas.dueDate!);
      for (final entry in localUpdates.entries) {
        final p = entry.key;
        final val = entry.value;
        p.score = val;
        if (val != null) {
          p.status = PengumpulanStatus.sudahDinilai;
        } else if (p.isSubmitted) {
          p.status = p.isLate
              ? PengumpulanStatus.terlambat
              : PengumpulanStatus.diserahkan;
        } else {
          p.status = isPastDue
              ? PengumpulanStatus.tidakMengumpulkan
              : PengumpulanStatus.belumMengumpulkan;
        }
        _controllerFor(p).text = val?.toString() ?? '';
      }
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Nilai berhasil disimpan')));
    return true;
  }

  Future<void> _toggleAcceptSubmissions(bool nextValue) async {
    if (_isTogglingAccept) return;
    final prev = _tugas.acceptSubmissions;
    setState(() {
      _tugas.acceptSubmissions = nextValue;
      _isTogglingAccept = true;
    });

    if (!_canFetch) {
      setState(() => _isTogglingAccept = false);
      return;
    }

    final (updated, err) = await widget.controller!.editPostingan(
      widget.classData.code,
      _postinganId!,
      judul: _tugas.title,
      deskripsi: _tugas.description,
      tipe: PostinganModel.tipeTugas,
      menerimaKiriman: nextValue,
    );
    if (!mounted) return;
    setState(() {
      _isTogglingAccept = false;
      if (err != null) {
        _tugas.acceptSubmissions = prev;
      } else if (updated != null) {
        _tugas.acceptSubmissions = updated.menerimaKiriman;
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            err ??
                (nextValue
                    ? 'Pengumpulan tugas dibuka'
                    : 'Pengumpulan tugas ditutup'),
          ),
        ),
      );
  }

  String _initialFor(PengumpulanItem item) {
    final trimmed = item.studentName.trim();
    if (trimmed.isNotEmpty) return trimmed[0].toUpperCase();
    final email = item.email.trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'M';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn =
            constraints.maxWidth >= ResponsiveBreakpoints.medium;
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: isTwoColumn ? 1120 : 800,
        );

        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: Row(
                children: [
                  const Expanded(
                    child: BackTitleRow(title: 'Pengumpulan & Penilaian'),
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
            Expanded(child: _buildBody(h, isTwoColumn: isTwoColumn)),
          ],
        );
      },
    );
  }

  Widget _buildBody(double h, {required bool isTwoColumn}) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: h),
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

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 14),
        _buildControls(_items),
      ],
    );

    final statusWidgets = <Widget>[];
    if (_items.isEmpty) {
      statusWidgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Belum ada murid yang mengumpulkan tugas',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
        ),
      );
    } else {
      for (final status in _statuses) {
        if (_filter == 'Semua' || _filter == status) {
          statusWidgets.addAll(
            _buildStatusCard(
              status,
              _items.where((p) => p.status == status).toList(),
            ),
          );
        }
      }
      if (statusWidgets.isEmpty) {
        statusWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Belum ada murid pada status $_filter',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ),
          ),
        );
      }
    }

    if (isTwoColumn) {
      return Padding(
        padding: EdgeInsets.fromLTRB(h, 4, h, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: controls,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 6,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: statusWidgets,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(h, 4, h, 24),
        children: [
          controls,
          const SizedBox(height: 12),
          ...statusWidgets,
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tugasTitle,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.color1.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
              child: Text(
                '$_submittedCount Murid Mengumpulkan',
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

  Future<void> _runAiAssessmentCheck({required bool isSimilarity}) async {
    if (!_canFetch || _checkingAi) return;
    final submittedIds = [
      for (final p in _items)
        if (p.isSubmitted && p.penggunaId != null && p.penggunaId! > 0)
          p.penggunaId!,
    ];
    final minRequired = isSimilarity ? 2 : 1;
    if (submittedIds.length < minRequired) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isSimilarity
                  ? 'Minimal 2 siswa yang mengumpulkan tugas untuk cek kemiripan'
                  : 'Belum ada kiriman siswa untuk diperiksa indikasi AI',
            ),
          ),
        );
      return;
    }

    final title = isSimilarity ? 'Cek Kemiripan Jawaban' : 'Cek Indikasi AI';
    setState(() => _checkingAi = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: AppTheme.cardShape(),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSimilarity
                    ? 'AI sedang memeriksa kemiripan jawaban siswa...'
                    : 'AI sedang memeriksa indikasi penggunaan AI...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final (res, err) = isSimilarity
        ? await widget.controller!.cekKemiripanAi(
            kodeKelas: widget.classData.code,
            postinganId: _postinganId!,
            penggunaIds: submittedIds,
            gunakanModelGratis: _gunakanModelGratis,
          )
        : await widget.controller!.cekIndikasiAi(
            kodeKelas: widget.classData.code,
            postinganId: _postinganId!,
            penggunaIds: submittedIds,
            jenjang: widget.classData.grade,
            gunakanModelGratis: _gunakanModelGratis,
          );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _checkingAi = false);

    if (err != null || res == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(err ?? 'Gagal memproses analisis AI')),
        );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: AppTheme.cardShape(),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (res.rekapFile != null) ...[
                FileCard.fromItem(res.rekapFile!, baseUrl: _effectiveBaseUrl),
                const SizedBox(height: 12),
              ],
              if (res.analisa.isNotEmpty) ...[
                const Text(
                  'Ringkasan Analisa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in res.analisa)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $line',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.text,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              if (res.ringkasan.isNotEmpty) ...[
                const Text(
                  'Detail Pemeriksaan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in res.ringkasan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $line',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
              if (res.analisa.isEmpty &&
                  res.ringkasan.isEmpty &&
                  res.rekapFile == null)
                const Text(
                  'Pemeriksaan selesai tanpa catatan tambahan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow(List<PengumpulanItem> all, List<String> statuses) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.secondaryText,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Text(
                      '${all.where((p) => p.status == statuses[i]).length}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: _statusAccentColor(statuses[i]),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statuses[i],
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusAccentColor(String status) {
    switch (status) {
      case PengumpulanStatus.terlambat:
        return const Color(0xFFB45309);
      case PengumpulanStatus.tidakMengumpulkan:
        return AppColors.error;
      default:
        return AppColors.text;
    }
  }

  Widget _buildControls(List<PengumpulanItem> all) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCounterRow(all, const [
          PengumpulanStatus.diserahkan,
          PengumpulanStatus.terlambat,
          PengumpulanStatus.sudahDinilai,
        ]),
        const Divider(height: 16, thickness: 1, color: Colors.black12),
        _buildCounterRow(all, const [
          PengumpulanStatus.belumMengumpulkan,
          PengumpulanStatus.tidakMengumpulkan,
        ]),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              key: const Key('menerima_kiriman_switch'),
              value: _tugas.acceptSubmissions,
              onChanged: _isTogglingAccept ? null : _toggleAcceptSubmissions,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Menerima kiriman',
                style: TextStyle(fontSize: 11, color: AppColors.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                _tugas.pengumpulan
                  ..clear()
                  ..addAll(_items);
                openPage(
                  context,
                  breadcrumb: [
                    'Pengajar',
                    widget.classData.title,
                    _tugasTitle,
                    'Koreksi AI',
                  ],
                  page: KoreksiAiScreen(
                    classData: widget.classData,
                    tugas: _tugas,
                    controller: widget.controller,
                    onAccepted: (scores) async {
                      for (final p in _items) {
                        final s = scores[p.keyId];
                        if (s != null) {
                          _controllerFor(p).text = '$s';
                        }
                      }
                      return _saveScores(overrideScores: scores);
                    },
                  ),
                );
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Koreksi menggunakan AI',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
            if (_canFetch) ...[
              ElevatedButton.icon(
                key: const Key('cek_kemiripan_ai_button'),
                style: AppTheme.softCompactButton,
                onPressed: _checkingAi || _submittedCount < 2
                    ? null
                    : () => _runAiAssessmentCheck(isSimilarity: true),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text('Cek Kemiripan'),
              ),
              ElevatedButton.icon(
                key: const Key('cek_indikasi_ai_button'),
                style: AppTheme.softCompactButton,
                onPressed: _checkingAi || _submittedCount < 1
                    ? null
                    : () => _runAiAssessmentCheck(isSimilarity: false),
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('Cek Indikasi AI'),
              ),
            ],
          ],
        ),
        if (_canFetch) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Switch(
                key: const Key('penilaian_ai_free_model_switch'),
                value: _gunakanModelGratis,
                onChanged: _checkingAi
                    ? null
                    : (v) => setState(() => _gunakanModelGratis = v),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Gunakan model AI gratis',
                  style: TextStyle(fontSize: 11, color: AppColors.text),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: DropdownButton<String>(
                  key: const Key('pengumpulan_status_filter'),
                  value: _filter,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: AppColors.text),
                  items: [
                    for (final f in _filters)
                      DropdownMenuItem(
                        value: f,
                        child: Text(f, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? 'Semua'),
                ),
              ),
              FilledButton(
                key: const Key('simpan_nilai_button'),
                onPressed: _isSaving || _items.isEmpty ? null : _saveScores,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStatusCard(String status, List<PengumpulanItem> rows) {
    if (rows.isEmpty) return const [];
    final scoreBoxWidth = math.max(
      40.0,
      MediaQuery.textScalerOf(context).scale(11) * 3.8,
    );

    return [
      Card(
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusAccentColor(status),
                      ),
                    ),
                  ),
                  Text(
                    '${rows.length} Orang',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 1, color: AppColors.text),
              for (var i = 0; i < rows.length; i++) ...[
                _buildStudentSubmissionRow(rows[i], scoreBoxWidth),
                if (i < rows.length - 1)
                  const Divider(height: 1, thickness: 1, color: Colors.black12),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildStudentSubmissionRow(PengumpulanItem item, double scoreBoxWidth) {
    final attachments = item.lampiran;

    final String badgeText;
    final Color badgeBg;
    final Color badgeFg;
    if (!item.isSubmitted) {
      if (item.status == PengumpulanStatus.tidakMengumpulkan) {
        badgeText = PengumpulanStatus.tidakMengumpulkan;
        badgeBg = AppColors.error.withValues(alpha: 0.12);
        badgeFg = AppColors.error;
      } else {
        badgeText = PengumpulanStatus.belumMengumpulkan;
        badgeBg = AppColors.secondaryText.withValues(alpha: 0.12);
        badgeFg = AppColors.secondaryText;
      }
    } else if (item.isMarkAsDone) {
      badgeText = 'Ditandai Selesai';
      badgeBg = AppColors.info.withValues(alpha: 0.12);
      badgeFg = AppColors.color3;
    } else {
      final count = attachments.isNotEmpty ? attachments.length : 1;
      badgeText = '$count Lampiran';
      badgeBg = AppColors.success.withValues(alpha: 0.12);
      badgeFg = const Color(0xFF1A7F37);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                picturePath: item.profilePicture,
                baseUrl: _effectiveBaseUrl,
                radius: 16,
                backgroundColor: AppColors.color1.withValues(alpha: 0.12),
                fallback: Text(
                  _initialFor(item),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.color1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (item.email.isNotEmpty)
                      Text(
                        item.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: scoreBoxWidth,
                child: TextField(
                  key: ValueKey('nilai_input_${item.keyId}'),
                  controller: _controllerFor(item),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveScores(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  decoration: const InputDecoration(
                    hintText: '...',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                '/${_tugas.points}',
                style: const TextStyle(fontSize: 11, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
              if (item.isSubmitted && item.isLate)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: const Text(
                    'Terlambat',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              if (item.submittedAt != null)
                Text(
                  'Dikumpulkan pada ${formatJam(item.submittedAt!)} • ${formatTanggal(item.submittedAt!)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
          if (item.isSubmitted) ...[
            const SizedBox(height: 8),
            if (attachments.isNotEmpty || item.fileName != null) ...[
              Builder(
                builder: (context) {
                  final isExpanded = _expandedSubmissions.contains(item.keyId);
                  final count = attachments.isNotEmpty ? attachments.length : 1;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        key: ValueKey('toggle_lampiran_${item.keyId}'),
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedSubmissions.remove(item.keyId);
                            } else {
                              _expandedSubmissions.add(item.keyId);
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.color1,
                          side: BorderSide(
                            color: AppColors.color1.withValues(alpha: 0.4),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                        ),
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                        ),
                        label: Text(
                          isExpanded
                              ? 'Sembunyikan Lampiran'
                              : 'Lihat Lampiran ($count)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 8),
                        if (attachments.isNotEmpty)
                          for (var i = 0; i < attachments.length; i++) ...[
                            FileCard.fromItem(
                              attachments[i],
                              baseUrl: _effectiveBaseUrl,
                            ),
                            if (i < attachments.length - 1)
                              const SizedBox(height: 8),
                          ]
                        else if (item.fileName != null)
                          Text(
                            item.fileName!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ] else
              const Text(
                'Ditandai sebagai selesai tanpa lampiran',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.secondaryText,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
