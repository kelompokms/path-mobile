import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/koreksi_ai_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';

class CekJawabanScreen extends StatefulWidget {
  final ClassItem classData;
  final TugasPengajar tugas;

  const CekJawabanScreen({
    super.key,
    required this.classData,
    required this.tugas,
  });

  @override
  State<CekJawabanScreen> createState() => _CekJawabanScreenState();
}

class _CekJawabanScreenState extends State<CekJawabanScreen> {
  static const _statuses = ['Diserahkan', 'Ditugaskan', 'Dinilai'];
  static const _filters = ['Semua', 'Diserahkan', 'Ditugaskan', 'Dinilai'];

  String _filter = 'Semua';
  final Map<String, TextEditingController> _scoreControllers = {};

  TugasPengajar get _tugas => widget.tugas;

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PengumpulanItem p) {
    return _scoreControllers.putIfAbsent(
      p.studentName,
      () => TextEditingController(text: p.score?.toString() ?? ''),
    );
  }

  void _saveScores() {
    FocusScope.of(context).unfocus();
    setState(() {
      for (final p in _tugas.pengumpulan) {
        final val = int.tryParse(
          _scoreControllers[p.studentName]?.text.trim() ?? '',
        );
        if (val != null) {
          p.score = val.clamp(0, _tugas.points);
          p.status = 'Dinilai';
        }
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nilai berhasil disimpan')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final all = _tugas.pengumpulan;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn =
            constraints.maxWidth >= ResponsiveBreakpoints.medium;
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: isTwoColumn ? 1120 : 760,
        );

        final controls = _buildControls(all);
        final statusCards = [
          for (final status in _statuses)
            if (_filter == 'Semua' || _filter == status)
              ..._buildStatusCard(
                status,
                all.where((p) => p.status == status).toList(),
              ),
        ];

        return Column(
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
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: controls,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 6,
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 24),
                              children: statusCards,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                      children: [
                        controls,
                        const SizedBox(height: 12),
                        ...statusCards,
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(List<PengumpulanItem> all) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < _statuses.length; i++) ...[
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
                          '${all.where((p) => p.status == _statuses[i]).length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _statuses[i],
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
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Switch(
              value: _tugas.acceptSubmissions,
              onChanged: (v) => setState(() => _tugas.acceptSubmissions = v),
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
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => openPage(
              context,
              breadcrumb: [
                'Pengajar',
                widget.classData.title,
                _tugas.title,
              ],
              page: KoreksiAiScreen(
                classData: widget.classData,
                tugas: _tugas,
                onAccepted: (scores) {
                  setState(() {
                    for (final p in _tugas.pengumpulan) {
                      final s = scores[p.studentName];
                      if (s != null) {
                        p.score = s;
                        p.status = 'Dinilai';
                        _controllerFor(p).text = '$s';
                      }
                    }
                  });
                },
              ),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppTheme.cardRadius,
                ),
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
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: _filter,
                isDense: true,
                style: const TextStyle(fontSize: 11, color: AppColors.text),
                items: [
                  for (final f in _filters)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) => setState(() => _filter = v ?? 'Semua'),
              ),
              FilledButton(
                onPressed: _saveScores,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.cardRadius,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text('Simpan'),
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Column(
            children: [
              Row(
                children: [
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
              const Divider(height: 16, thickness: 1, color: AppColors.text),
              for (var i = 0; i < rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
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
                      SizedBox(
                        width: scoreBoxWidth,
                        child: TextField(
                          controller: _controllerFor(rows[i]),
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number,
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
                        style: const TextStyle(
                          fontSize: 11,
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
