import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_items.dart';

class MateriDetailScreen extends StatefulWidget {
  final MateriData materi;
  final String? baseUrl;

  const MateriDetailScreen({super.key, required this.materi, this.baseUrl});

  @override
  State<MateriDetailScreen> createState() => _MateriDetailScreenState();
}

class _MateriDetailScreenState extends State<MateriDetailScreen> {
  static const _baseModes = ['Tabel', 'Diagram', 'Ilustrasi'];
  static const _modes = ['Tabel', 'Diagram', 'Ilustrasi', 'Kombinasi'];

  bool _showAi = false;
  final _textController = TextEditingController();
  final Set<String> _selectedModes = {};
  String? _question;
  String? _answer;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleMode(String label) {
    setState(() {
      if (label == 'Kombinasi') {
        if (_selectedModes.contains('Kombinasi')) {
          _selectedModes.clear();
        } else {
          _selectedModes.addAll(_modes);
        }
      } else {
        if (_selectedModes.contains(label)) {
          _selectedModes.remove(label);
          _selectedModes.remove('Kombinasi');
        } else {
          _selectedModes.add(label);
          if (_baseModes.every(_selectedModes.contains)) {
            _selectedModes.add('Kombinasi');
          }
        }
      }
    });
  }

  void _sendAi() {
    final q = _textController.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final active = _selectedModes.where((m) => m != 'Kombinasi').toList();
    final modeText = active.isEmpty ? 'penjelasan ringkas' : active.join(', ');
    setState(() {
      _question = q;
      _answer = 'Ringkasan AI ($modeText) untuk pertanyaan:\n"$q"';
    });
  }

  @override
  Widget build(BuildContext context) {
    final materi = widget.materi;
    final meta =
        '${materi.author} • ${formatTanggal(materi.postedAt)} • ${formatJam(materi.postedAt)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn =
            constraints.maxWidth >= ResponsiveBreakpoints.medium && _showAi;
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: isTwoColumn ? 1120 : 800,
        );

        final detailColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              materi.description,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            for (final item in materi.lampiran) ...[
              FileCard.fromItem(item, baseUrl: widget.baseUrl),
              const SizedBox(height: 10),
            ],
            if (!_showAi) ...[
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () => setState(() => _showAi = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.color1,
                  foregroundColor: Colors.white,
                  elevation: AppTheme.cardElevation,
                  shadowColor: AppTheme.shadowColor,
                  side: AppTheme.thinBorderSide,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 12, 14, 12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text('Bantuan AI', style: TextStyle(fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ],
          ],
        );

        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: BackTitleRow(title: materi.title),
            ),
            Expanded(
              child: isTwoColumn
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(h, 4, h, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: detailColumn,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildAiSection(showDivider: false),
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
                          detailColumn,
                          if (_showAi) ...[
                            const SizedBox(height: 6),
                            _buildAiSection(),
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

  Widget _buildAiSection({bool showDivider = true}) {
    final canSend = _textController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.secondaryText.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'Bantuan AI',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Apakah anda kebingungan?\nPilih bantuan yang diinginkan',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in _modes)
              ElevatedButton(
                onPressed: () => _toggleMode(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedModes.contains(label)
                      ? AppColors.color1
                      : AppColors.card,
                  foregroundColor: _selectedModes.contains(label)
                      ? Colors.white
                      : AppColors.text,
                  elevation: AppTheme.cardElevation,
                  shadowColor: AppTheme.shadowColor,
                  side: AppTheme.thinBorderSide,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 34),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: Text(label),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Atau tanyakan melalui chat',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        if (_question == null)
          Material(
            elevation: AppTheme.cardElevation,
            shadowColor: AppTheme.shadowColor,
            color: AppColors.card,
            shape: AppTheme.cardShape(),
            clipBehavior: Clip.antiAlias,
            child: TextField(
              controller: _textController,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendAi(),
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Tanyakan sesuatu dari materi',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  borderSide: AppTheme.thinBorderSide,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  borderSide: AppTheme.thinBorderSide,
                ),
                suffixIcon: IconButton(
                  onPressed: canSend ? _sendAi : null,
                  icon: Icon(
                    Icons.send_outlined,
                    color: canSend ? AppColors.color1 : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(color: AppColors.color1),
            child: Text(
              _question!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(),
            child: Text(
              _answer ?? '',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
