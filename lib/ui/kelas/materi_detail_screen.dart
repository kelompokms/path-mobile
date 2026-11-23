import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_items.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class MateriDetailScreen extends StatefulWidget {
  final MateriData materi;
  final String? baseUrl;
  final KelasController? controller;
  final String jenjang;

  const MateriDetailScreen({
    super.key,
    required this.materi,
    this.baseUrl,
    this.controller,
    this.jenjang = '',
  });

  @override
  State<MateriDetailScreen> createState() => _MateriDetailScreenState();
}

class _MateriDetailScreenState extends State<MateriDetailScreen> {
  static const _baseModes = ['Tabel', 'Diagram', 'Ilustrasi'];
  static const _modes = ['Tabel', 'Diagram', 'Ilustrasi', 'Kombinasi'];
  static const _maxHistoryMessages = 20;

  bool _showAi = false;
  bool _loadingAi = false;
  bool _gunakanModelGratis = false;
  String _loadingLabel = 'AI sedang menyiapkan jawaban...';
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _selectedModes = {};
  final List<({String role, String content, LampiranItem? attachment})>
  _messages = [];

  bool get _usesImageMode =>
      _selectedModes.contains('Ilustrasi') ||
      _selectedModes.contains('Kombinasi');

  bool get _effectiveFreeModel => !_usesImageMode && _gunakanModelGratis;

  List<String> get _summarizableDocumentPaths {
    const supportedExts = {'pdf', 'docx', 'txt', 'csv'};
    return [
      for (final item in widget.materi.lampiran)
        if (!item.isLink &&
            item.targetUrl != null &&
            supportedExts.contains(
              extractLampiranExtension(
                item.name.isNotEmpty ? item.name : item.targetUrl!,
              ),
            ))
          item.targetUrl!,
    ];
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
      if (_usesImageMode) {
        _gunakanModelGratis = false;
      }
    });
  }

  Future<void> _ringkasDokumenAi() async {
    final ctrl = widget.controller;
    final docPaths = _summarizableDocumentPaths;
    if (ctrl == null || docPaths.isEmpty || _loadingAi) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loadingAi = true;
      _loadingLabel = 'AI sedang meringkas dokumen materi...';
      _messages.add((
        role: 'user',
        content: 'Ringkas dokumen materi "${widget.materi.title}"',
        attachment: null,
      ));
    });
    _scrollToBottom();

    final (res, err) = await ctrl.ringkasDokumenAi(
      lampiranPaths: docPaths,
      judul: widget.materi.title.trim(),
      jenjang: widget.jenjang,
      diagram: _selectedModes.contains('Diagram'),
      gunakanModelGratis: _effectiveFreeModel,
    );
    if (!mounted) return;

    if (err != null || res == null) {
      setState(() {
        _loadingAi = false;
        if (_messages.isNotEmpty && _messages.last.role == 'user') {
          _messages.removeLast();
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(err ?? 'Gagal meringkas dokumen dengan AI')),
        );
      return;
    }

    final summary = res.judul.isNotEmpty && !res.jawaban.contains(res.judul)
        ? '**${res.judul}**\n\n${res.jawaban}'
        : res.jawaban;
    setState(() {
      _loadingAi = false;
      _messages.add((
        role: 'assistant',
        content: summary,
        attachment: res.file,
      ));
    });
    _scrollToBottom();
  }

  String _normalizeChatMarkdown(String raw) {
    return raw
        .replaceAll(RegExp(r'\$\\rightarrow\$|\\rightarrow'), '→')
        .replaceAll(RegExp(r'\$\\leftarrow\$|\\leftarrow'), '←')
        .replaceAll(RegExp(r'\$\\downarrow\$|\\downarrow'), '↓')
        .replaceAll(RegExp(r'\$\\uparrow\$|\\uparrow'), '↑')
        .replaceAll(RegExp(r'\$\\leftrightarrow\$|\\leftrightarrow'), '↔')
        .replaceAll(RegExp(r'\$\\Rightarrow\$|\\Rightarrow'), '⇒');
  }

  Future<void> _sendAi({String? overridePrompt}) async {
    final typed = (overridePrompt ?? _textController.text).trim();
    final active = _selectedModes.where((m) => m != 'Kombinasi').toList();
    final useVisualExplain = active.isNotEmpty;
    final q = typed.isNotEmpty
        ? typed
        : (useVisualExplain
              ? 'Jelaskan materi "${widget.materi.title}" menggunakan ${active.join(', ')}'
              : '');
    if (q.isEmpty || _loadingAi) return;
    FocusScope.of(context).unfocus();

    final ctrl = widget.controller;
    if (ctrl == null) {
      final modeText = active.isEmpty ? 'penjelasan ringkas' : active.join(', ');
      setState(() {
        _messages.add((role: 'user', content: q, attachment: null));
        _messages.add((
          role: 'assistant',
          content: 'Ringkasan AI ($modeText) untuk pertanyaan:\n"$q"',
          attachment: null,
        ));
        _textController.clear();
      });
      _scrollToBottom();
      return;
    }

    final historySlice = _messages.length > _maxHistoryMessages
        ? _messages.sublist(_messages.length - _maxHistoryMessages)
        : _messages;
    final riwayat = [
      for (final m in historySlice) {'role': m.role, 'content': m.content},
    ];

    setState(() {
      _loadingAi = true;
      _loadingLabel = useVisualExplain
          ? 'AI sedang membuat penjelasan visual (${active.join(', ')})...'
          : 'AI sedang menyiapkan jawaban...';
      _messages.add((role: 'user', content: q, attachment: null));
      _textController.clear();
    });
    _scrollToBottom();

    final isiMateri = [
      widget.materi.title.trim(),
      widget.materi.description.trim(),
    ].where((s) => s.isNotEmpty).join('\n\n');

    if (useVisualExplain) {
      final lampiranPaths = [
        for (final item in widget.materi.lampiran)
          if (item.targetUrl != null) item.targetUrl!,
      ];
      final (res, err) = await ctrl.explainMateriAi(
        pertanyaan: q,
        deskripsiMateri: widget.materi.description.trim(),
        isiMateri: isiMateri,
        lampiranPaths: lampiranPaths,
        jenjang: widget.jenjang,
        tabel: _selectedModes.contains('Tabel'),
        diagram: _selectedModes.contains('Diagram'),
        ilustrasi: _selectedModes.contains('Ilustrasi'),
        kombinasi: _selectedModes.contains('Kombinasi'),
        gunakanModelGratis: _effectiveFreeModel,
      );
      if (!mounted) return;
      if (err != null || res == null) {
        setState(() {
          _loadingAi = false;
          if (_messages.isNotEmpty && _messages.last.role == 'user') {
            _messages.removeLast();
          }
          if (overridePrompt == null) {
            _textController.text = q;
          }
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(err ?? 'Gagal membuat penjelasan visual AI')),
          );
        return;
      }

      final summary = res.judul.isNotEmpty && !res.jawaban.contains(res.judul)
          ? '**${res.judul}**\n\n${res.jawaban}'
          : res.jawaban;
      setState(() {
        _loadingAi = false;
        _selectedModes.clear();
        _messages.add((
          role: 'assistant',
          content: summary,
          attachment: res.file,
        ));
      });
      _scrollToBottom();
      return;
    }

    final (jawaban, err) = await ctrl.chatAi(
      pesan: q,
      isiMateri: isiMateri,
      jenjang: widget.jenjang,
      modes: active,
      riwayat: riwayat,
      gunakanModelGratis: _effectiveFreeModel,
    );
    if (!mounted) return;

    if (err != null || jawaban == null) {
      setState(() {
        _loadingAi = false;
        if (_messages.isNotEmpty && _messages.last.role == 'user') {
          _messages.removeLast();
        }
        _textController.text = q;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(err ?? 'Gagal mendapatkan jawaban AI')),
        );
      return;
    }

    setState(() {
      _loadingAi = false;
      _messages.add((role: 'assistant', content: jawaban, attachment: null));
    });
    _scrollToBottom();
  }

  Future<void> _openMarkdownLink(String? href) async {
    if (href == null || href.trim().isEmpty) return;
    final uri = Uri.tryParse(href.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final base = const TextStyle(
      fontSize: 12,
      height: 1.5,
      color: AppColors.text,
    );
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: base,
      h1: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      h2: base.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      h3: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      listBullet: base,
      blockquote: base.copyWith(color: AppColors.secondaryText),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.color1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: const Border(
          left: BorderSide(color: AppColors.color1, width: 3),
        ),
      ),
      code: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 11,
        backgroundColor: Colors.black.withValues(alpha: 0.05),
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: Colors.black12),
      ),
      tableHead: base.copyWith(fontWeight: FontWeight.w600),
      tableBody: base,
      tableBorder: TableBorder.all(color: Colors.black12, width: 1),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      a: base.copyWith(
        color: AppColors.color1,
        decoration: TextDecoration.underline,
      ),
    );
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildAiSection(showDivider: false),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
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
                onPressed: _loadingAi ? null : () => _toggleMode(label),
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
        if (_selectedModes.isNotEmpty ||
            (widget.controller != null && _summarizableDocumentPaths.isNotEmpty)) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_selectedModes.isNotEmpty)
                FilledButton.icon(
                  key: const Key('ai_visual_explain_button'),
                  onPressed: _loadingAi ? null : () => _sendAi(),
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: Text(
                    'Buat Bantuan (${_selectedModes.where((m) => m != 'Kombinasi').join(', ')})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                  ),
                ),
              if (widget.controller != null &&
                  _summarizableDocumentPaths.isNotEmpty)
                ElevatedButton.icon(
                  key: const Key('ai_ringkas_dokumen_button'),
                  onPressed: _loadingAi ? null : _ringkasDokumenAi,
                  style: AppTheme.softCompactButton,
                  icon: const Icon(Icons.summarize_outlined, size: 16),
                  label: const Text(
                    'Ringkas Dokumen AI',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Switch(
              key: const Key('materi_ai_free_model_switch'),
              value: _effectiveFreeModel,
              onChanged: (_loadingAi || _usesImageMode)
                  ? null
                  : (v) => setState(() => _gunakanModelGratis = v),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _usesImageMode
                    ? 'Model AI gratis (nonaktif untuk Ilustrasi/Kombinasi)'
                    : 'Gunakan model AI gratis',
                style: TextStyle(
                  fontSize: 11,
                  color: _usesImageMode
                      ? AppColors.secondaryText
                      : AppColors.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Atau tanyakan melalui chat',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            if (_messages.isNotEmpty && !_loadingAi)
              TextButton.icon(
                key: const Key('ai_chat_reset_button'),
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _textController.clear();
                  });
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reset Chat', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final msg in _messages) ...[
          if (msg.role == 'user')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(color: AppColors.color1),
              child: Text(
                msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: _normalizeChatMarkdown(msg.content),
                    selectable: true,
                    styleSheet: _markdownStyle(context),
                    onTapLink: (_, href, _) => _openMarkdownLink(href),
                  ),
                  if (msg.attachment != null) ...[
                    const SizedBox(height: 12),
                    FileCard.fromItem(
                      msg.attachment!,
                      baseUrl: widget.baseUrl ?? widget.controller?.baseUrl,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (_loadingAi) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _loadingLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Material(
          elevation: AppTheme.cardElevation,
          shadowColor: AppTheme.shadowColor,
          color: AppColors.card,
          shape: AppTheme.cardShape(),
          clipBehavior: Clip.antiAlias,
          child: TextField(
            key: const Key('ai_chat_input'),
            controller: _textController,
            enabled: !_loadingAi,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _sendAi(),
            textInputAction: TextInputAction.send,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
            decoration: InputDecoration(
              hintText: _messages.isEmpty
                  ? 'Tanyakan sesuatu dari materi'
                  : 'Lanjutkan percakapan...',
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
                key: const Key('ai_chat_send_button'),
                onPressed: (canSend && !_loadingAi) ? _sendAi : null,
                icon: Icon(
                  Icons.send_outlined,
                  color: (canSend && !_loadingAi)
                      ? AppColors.color1
                      : AppColors.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
