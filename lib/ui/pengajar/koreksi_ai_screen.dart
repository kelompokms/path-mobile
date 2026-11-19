import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';

class KoreksiAiScreen extends StatefulWidget {
  final ClassItem classData;
  final TugasPengajar tugas;
  final ValueChanged<Map<String, int>> onAccepted;

  const KoreksiAiScreen({
    super.key,
    required this.classData,
    required this.tugas,
    required this.onAccepted,
  });

  @override
  State<KoreksiAiScreen> createState() => _KoreksiAiScreenState();
}

class _KoreksiAiScreenState extends State<KoreksiAiScreen> {
  final _descController = TextEditingController();
  String? _keyFileName;
  Set<String> _selected = {};
  bool _confirmedStep = false;

  bool get _hasKey =>
      _keyFileName != null || _descController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickKeyFile() async {
    final name = await showAddLinkDialog(
      context,
      title: 'Upload kunci jawaban',
      label: 'Nama file kunci jawaban',
      buttonLabel: 'Pilih',
    );
    if (name == null || !mounted) return;
    setState(() => _keyFileName = name);
  }

  @override
  Widget build(BuildContext context) {
    final tugas = widget.tugas;
    final generatedScores = {
      for (final name in _selected) name: 90,
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
                    FileCard(
                      fileName: 'Rekap koreksi AI_${tugas.title}',
                      fileType: 'PDF',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () {
                                widget.onAccepted(generatedScores);
                                Navigator.of(context).popUntil(
                                  ModalRoute.withName('cek-jawaban'),
                                );
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text('Koreksi AI diterima'),
                                    ),
                                  );
                              },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text('Terima Koreksi'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PengumpulanChecklist(
                      students: tugas.pengumpulan,
                      selected: _selected,
                      scores: generatedScores,
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
                    'File',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        style: AppTheme.softCompactButton,
                        onPressed: _pickKeyFile,
                        child: const Text('Upload file'),
                      ),
                      if (_keyFileName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: Text(
                                  _keyFileName!,
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
                              onPressed: () =>
                                  setState(() => _keyFileName = null),
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
                      if (_hasKey && _selected.isNotEmpty) {
                        setState(() => _confirmedStep = true);
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
                      onPressed: _hasKey && _selected.isNotEmpty
                          ? () => setState(() => _confirmedStep = true)
                          : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: const Text('Koreksi menggunakan AI'),
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

  const PengumpulanChecklist({
    super.key,
    required this.students,
    required this.selected,
    required this.onChanged,
    this.maxScore = 100,
    this.scores = const {},
  });

  @override
  State<PengumpulanChecklist> createState() => _PengumpulanChecklistState();
}

class _PengumpulanChecklistState extends State<PengumpulanChecklist> {
  static const _statuses = ['Diserahkan', 'Ditugaskan', 'Dinilai'];
  static const _filters = ['Semua', 'Diserahkan', 'Ditugaskan', 'Dinilai'];

  String _filter = 'Semua';

  List<PengumpulanItem> get _visible => widget.students
      .where((p) => _filter == 'Semua' || p.status == _filter)
      .toList();

  bool _allSelected(List<PengumpulanItem> rows) =>
      rows.isNotEmpty &&
      rows.every((p) => widget.selected.contains(p.studentName));

  void _setMany(List<PengumpulanItem> rows, bool value) {
    final next = {...widget.selected};
    for (final p in rows) {
      if (value) {
        next.add(p.studentName);
      } else {
        next.remove(p.studentName);
      }
    }
    widget.onChanged(next);
  }

  Widget _box(bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
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
            _box(_allSelected(visible), (v) => _setMany(visible, v)),
            const SizedBox(width: 8),
            Flexible(
              child: DropdownButton<String>(
                value: _filter,
                isDense: true,
                style: const TextStyle(fontSize: 11, color: AppColors.text),
                items: [
                  for (final f in _filters)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _filter = v ?? 'Semua'),
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
                  _box(_allSelected(rows), (v) => _setMany(rows, v)),
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
                        widget.selected.contains(rows[i].studentName),
                        (v) => _setMany([rows[i]], v),
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
                            if (rows[i].fileName != null)
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
                          ],
                        ),
                      ),
                      Text(
                        '${widget.scores[rows[i].studentName] ?? rows[i].score ?? '...'}/${widget.maxScore}',
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
