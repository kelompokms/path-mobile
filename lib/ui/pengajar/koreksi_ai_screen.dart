import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

typedef KoreksiAcceptedCallback = FutureOr<bool> Function(
  Map<String, int> scores,
);

/// Document extensions supported by ai.pathclass.app & path-api for AI answer-key upload.
const List<String> allowedAnswerKeyExtensions = [
  'pdf',
  'docx',
  'txt',
  'csv',
];

class KoreksiAiScreen extends StatefulWidget {
  final ClassItem classData;
  final TugasPengajar tugas;
  final PengajarController? controller;
  final KoreksiAcceptedCallback onAccepted;
  final Future<PickedLampiranFile?> Function()? onPickKeyFile;

  const KoreksiAiScreen({
    super.key,
    required this.classData,
    required this.tugas,
    this.controller,
    required this.onAccepted,
    this.onPickKeyFile,
  });

  @override
  State<KoreksiAiScreen> createState() => _KoreksiAiScreenState();
}

class _KoreksiAiScreenState extends State<KoreksiAiScreen> {
  final _descController = TextEditingController();
  String? _keyFileName;
  Uint8List? _keyFileBytes;
  bool _pickingFile = false;
  bool _grading = false;
  Set<String> _selected = {};
  Map<String, int>? _aiScores;
  Map<String, String> _aiLabels = const {};
  Map<String, String> _aiFeedback = const {};
  LampiranItem? _rekapFile;
  List<String> _analisa = const [];
  bool _confirmedStep = false;
  bool _submitting = false;

  bool get _hasKey =>
      _keyFileName != null || _descController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<PickedLampiranFile?> _defaultPickKeyFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedAnswerKeyExtensions,
    );
    if (file == null) return null;
    return PickedLampiranFile(
      name: file.name,
      size: file.lengthSync(),
      readBytes: file.readAsBytes,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickKeyFile() async {
    if (_pickingFile) return;
    setState(() => _pickingFile = true);
    try {
      final picked = await (widget.onPickKeyFile ?? _defaultPickKeyFile)();
      if (picked == null || !mounted) return;

      final fileName = picked.name.trim();
      final ext = extractLampiranExtension(fileName);
      if (ext.isEmpty || !allowedAnswerKeyExtensions.contains(ext)) {
        _showSnack(
          'Format kunci jawaban tidak didukung. Gunakan file PDF, DOCX, TXT, atau CSV.',
        );
        return;
      }

      final knownSize = picked.size;
      if (knownSize != null && knownSize > maxPostinganFileSizeBytes) {
        _showSnack('Ukuran file kunci jawaban terlalu besar (maks. 10 MB)');
        return;
      }

      final bytes = await picked.readBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        _showSnack('File kunci jawaban kosong');
        return;
      }
      if (bytes.length > maxPostinganFileSizeBytes) {
        _showSnack('Ukuran file kunci jawaban terlalu besar (maks. 10 MB)');
        return;
      }

      setState(() {
        _keyFileName = fileName;
        _keyFileBytes = bytes;
      });
    } catch (e) {
      _showSnack('Gagal memilih file kunci jawaban: $e');
    } finally {
      if (mounted) {
        setState(() => _pickingFile = false);
      }
    }
  }

  Future<void> _runKoreksiAi() async {
    if (!_hasKey || _selected.isEmpty || _grading) return;
    final ctrl = widget.controller;
    final postinganId = widget.tugas.id;
    final kodeKelas = widget.classData.code;

    if (ctrl == null || postinganId == null || postinganId <= 0 || kodeKelas.isEmpty) {
      setState(() {
        _aiScores = {for (final key in _selected) key: 90};
        _confirmedStep = true;
      });
      return;
    }

    final selectedItems = widget.tugas.pengumpulan
        .where((p) => _selected.contains(p.keyId) && p.penggunaId != null)
        .toList();
    final penggunaIds = selectedItems.map((p) => p.penggunaId!).toList();
    if (penggunaIds.isEmpty) {
      _showSnack('Pilih minimal satu siswa yang sudah mengumpulkan tugas');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _grading = true);
    final (result, err) = await ctrl.koreksiTugasAi(
      kodeKelas: kodeKelas,
      postinganId: postinganId,
      penggunaIds: penggunaIds,
      deskripsiKunci: _descController.text.trim(),
      keyFileName: _keyFileName,
      keyFileBytes: _keyFileBytes,
    );
    if (!mounted) return;
    setState(() => _grading = false);

    if (err != null || result == null) {
      _showSnack(err ?? 'Gagal melakukan koreksi AI');
      return;
    }

    final mappedScores = <String, int>{};
    final mappedLabels = <String, String>{};
    final mappedFeedback = <String, String>{};
    for (final p in selectedItems) {
      final uid = p.penggunaId!;
      final score = result.scoresByPenggunaId[uid];
      if (score != null) {
        mappedScores[p.keyId] = score;
      }
      final label = result.labelsByPenggunaId[uid];
      if (label != null && label.isNotEmpty) {
        mappedLabels[p.keyId] = label;
      }
      final fb = result.feedbackByPenggunaId[uid];
      if (fb != null && fb.isNotEmpty) {
        mappedFeedback[p.keyId] = fb;
      }
    }
    if (mappedScores.isEmpty) {
      _showSnack('AI tidak mengembalikan nilai untuk siswa terpilih');
      return;
    }

    setState(() {
      _aiScores = mappedScores;
      _aiLabels = mappedLabels;
      _aiFeedback = mappedFeedback;
      _rekapFile = result.rekapFile;
      _analisa = result.analisa;
      _confirmedStep = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tugas = widget.tugas;
    final generatedScores = <String, int>{
      for (final key in _selected)
        if (_aiScores?.containsKey(key) == true)
          key: _aiScores![key]!
        else if (_aiScores == null)
          key: 90,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 840,
        );

        if (_confirmedStep) {
          return Column(
            children: [
              Padding(
                padding: alignedBackTitlePadding(h),
                child: const BackTitleRow(title: 'Koreksi Menggunakan AI'),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                  children: [
                    Text(
                      tugas.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_rekapFile != null)
                      FileCard.fromItem(
                        _rekapFile!,
                        baseUrl: widget.controller?.baseUrl,
                      )
                    else
                      FileCard(
                        fileName: 'Rekap koreksi AI_${tugas.title}',
                        fileType: 'XLSX',
                      ),
                    if (_analisa.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ringkasan Analisa AI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final line in _analisa)
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
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _selected.isEmpty || _submitting
                            ? null
                            : () async {
                                setState(() => _submitting = true);
                                try {
                                  final ok = await widget.onAccepted(
                                    generatedScores,
                                  );
                                  if (!context.mounted) return;
                                  if (ok) {
                                    Navigator.of(context).pop();
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _submitting = false);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Terima Koreksi'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PengumpulanChecklist(
                      students: tugas.pengumpulan,
                      selected: _selected,
                      scores: generatedScores,
                      labels: _aiLabels,
                      feedbacks: _aiFeedback,
                      maxScore: tugas.points,
                      onChanged: (v) => setState(() => _selected = v),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Koreksi Menggunakan AI'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                children: [
                  Text(
                    tugas.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.info,
                          size: 12,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'AI akan membantu mengoreksi pekerjaan siswa menggunakan '
                          'lampiran file kunci jawaban yang sudah diunggah atau buat '
                          'sendiri kunci jawaban menggunakan AI',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kunci jawaban',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'File (PDF, DOCX, TXT, CSV • maks. 10 MB)',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        key: const Key('koreksi_ai_upload_key_button'),
                        style: AppTheme.softCompactButton,
                        onPressed: _pickingFile ? null : _pickKeyFile,
                        icon: _pickingFile
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined, size: 16),
                        label: Text(
                          _pickingFile ? 'Memilih...' : 'Upload file',
                        ),
                      ),
                      if (_keyFileName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: AppColors.color1,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  _keyFileBytes != null
                                      ? '$_keyFileName (${_formatFileSize(_keyFileBytes!.length)})'
                                      : _keyFileName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Hapus file kunci jawaban',
                              onPressed: () => setState(() {
                                _keyFileName = null;
                                _keyFileBytes = null;
                              }),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Atau buat kunci jawaban menggunakan AI',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  TextField(
                    controller: _descController,
                    onChanged: (_) => setState(() {}),
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_hasKey && _selected.isNotEmpty && !_grading) {
                        _runKoreksiAi();
                      }
                    },
                    style: const TextStyle(fontSize: 11, color: AppColors.text),
                    decoration: const InputDecoration(
                      hintText: 'Deskripsi kunci jawaban yang akan dibuat AI',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _hasKey && _selected.isNotEmpty && !_grading
                          ? _runKoreksiAi
                          : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: _grading
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
                                Text('Mengoreksi dengan AI...'),
                              ],
                            )
                          : const Text('Koreksi menggunakan AI'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PengumpulanChecklist(
                    students: tugas.pengumpulan,
                    selected: _selected,
                    maxScore: tugas.points,
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class PengumpulanChecklist extends StatefulWidget {
  final List<PengumpulanItem> students;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int maxScore;
  final Map<String, int> scores;
  final Map<String, String> labels;
  final Map<String, String> feedbacks;

  const PengumpulanChecklist({
    super.key,
    required this.students,
    required this.selected,
    required this.onChanged,
    this.maxScore = 100,
    this.scores = const {},
    this.labels = const {},
    this.feedbacks = const {},
  });

  @override
  State<PengumpulanChecklist> createState() => _PengumpulanChecklistState();
}

class _PengumpulanChecklistState extends State<PengumpulanChecklist> {
  static const _statuses = PengumpulanStatus.all;
  static const _filters = PengumpulanStatus.filters;

  String _filter = 'Semua';

  List<PengumpulanItem> get _visible => widget.students
      .where((p) => _filter == 'Semua' || p.status == _filter)
      .toList();

  List<PengumpulanItem> _selectable(List<PengumpulanItem> rows) =>
      rows.where((p) => p.isSubmitted).toList();

  bool _allSelected(List<PengumpulanItem> rows) {
    final eligible = _selectable(rows);
    return eligible.isNotEmpty &&
        eligible.every((p) => widget.selected.contains(p.keyId));
  }

  void _setMany(List<PengumpulanItem> rows, bool value) {
    final next = {...widget.selected};
    for (final p in _selectable(rows)) {
      if (value) {
        next.add(p.keyId);
      } else {
        next.remove(p.keyId);
      }
    }
    widget.onChanged(next);
  }

  Widget _box(bool value, ValueChanged<bool>? onChanged) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Checkbox(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
        activeColor: AppColors.text,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _box(
              _allSelected(visible),
              _selectable(visible).isEmpty
                  ? null
                  : (v) => _setMany(visible, v),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: DropdownButton<String>(
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
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final status in _statuses)
          ..._buildGroup(
            status,
            visible.where((p) => p.status == status).toList(),
          ),
      ],
    );
  }

  List<Widget> _buildGroup(String status, List<PengumpulanItem> rows) {
    if (rows.isEmpty) return const [];

    return [
      Card(
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: AppTheme.cardShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 4),
          child: Column(
            children: [
              Row(
                children: [
                  _box(
                    _allSelected(rows),
                    _selectable(rows).isEmpty
                        ? null
                        : (v) => _setMany(rows, v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
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
              const Divider(height: 14, thickness: 1, color: AppColors.text),
              for (var i = 0; i < rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      _box(
                        widget.selected.contains(rows[i].keyId),
                        rows[i].isSubmitted
                            ? (v) => _setMany([rows[i]], v)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].studentName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            if (rows[i].lampiran.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  rows[i].lampiran
                                      .map((a) => a.name)
                                      .join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.secondaryText,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              )
                            else if (rows[i].fileName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  rows[i].fileName!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.secondaryText,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            if (widget.labels[rows[i].keyId] != null ||
                                widget.feedbacks[rows[i].keyId] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  [
                                    if (widget.labels[rows[i].keyId] != null)
                                      '[${widget.labels[rows[i].keyId]}]',
                                    if (widget.feedbacks[rows[i].keyId] != null)
                                      widget.feedbacks[rows[i].keyId]!,
                                  ].join(' '),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.secondaryText,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.scores[rows[i].keyId] ?? rows[i].score ?? '...'}/${widget.maxScore}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < rows.length - 1)
                  const Divider(height: 1, thickness: 1, color: Colors.black12),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
