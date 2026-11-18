import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_screen.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

/// Role-aware Classes screen:
/// - Universal `guru` defaults to the `Mengajar` tab with secondary `Diikuti` tab.
/// - Universal `murid` shows enrolled classes directly, and adaptively reveals
///   a `Mendampingi` tab when promoted as a class assistant (`k.guru == true`).
class KelasScreen extends StatefulWidget {
  final KelasController controller;
  final PengajarController? pengajarController;
  final bool isGuruRole;

  const KelasScreen({
    super.key,
    required this.controller,
    this.pengajarController,
    this.isGuruRole = false,
  });

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final pengajarCtrl = widget.pengajarController;
    if (pengajarCtrl != null) {
      Future<void>.microtask(() {
        if (mounted) {
          pengajarCtrl.getListKelas();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant KelasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuruRole != widget.isGuruRole) {
      setState(() => _selectedTab = 0);
      Future<void>.microtask(() {
        if (!mounted) return;
        widget.controller.getListKelas();
        widget.pengajarController?.getListKelas();
      });
    }
  }

  Widget _buildModeChip({
    required String label,
    required int tabIndex,
    required Key key,
  }) {
    final active = _selectedTab == tabIndex;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: active,
      onSelected: (_) {
        if (_selectedTab == tabIndex) return;
        setState(() => _selectedTab = tabIndex);
        if (widget.isGuruRole) {
          if (tabIndex == 0) {
            widget.pengajarController?.getListKelas();
          } else {
            widget.controller.getListKelas();
          }
        } else {
          if (tabIndex == 0) {
            widget.controller.getListKelas();
          } else {
            widget.pengajarController?.getListKelas();
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pengajarCtrl = widget.pengajarController;
    if (pengajarCtrl == null) {
      return PageFrame(
        breadcrumb: const ['Kelas'],
        child: RegisteredClassesSection(
          controller: widget.controller,
          breadcrumbRoot: 'Kelas',
          emptyMessage: 'Anda belum bergabung kelas manapun',
        ),
      );
    }

    return PageFrame(
      breadcrumb: const ['Kelas'],
      child: ListenableBuilder(
        listenable: pengajarCtrl,
        builder: (context, _) {
          final hasAssistantClasses = pengajarCtrl.listKelas.any((k) => k.guru);
          final showTeaching =
              (widget.isGuruRole && _selectedTab == 0) ||
              (!widget.isGuruRole && hasAssistantClasses && _selectedTab == 1);
          final showSwitcher = widget.isGuruRole || hasAssistantClasses;

          return Column(
            children: [
              if (showSwitcher)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final h = responsiveHorizontalInset(
                      constraints.maxWidth,
                      maxWidth: ResponsiveBreakpoints.wide,
                    );
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(h, 12, h, 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.isGuruRole
                            ? [
                                _buildModeChip(
                                  key: const Key('kelas_tab_mengajar'),
                                  label: 'Mengajar',
                                  tabIndex: 0,
                                ),
                                _buildModeChip(
                                  key: const Key('kelas_tab_diikuti'),
                                  label: 'Diikuti',
                                  tabIndex: 1,
                                ),
                              ]
                            : [
                                _buildModeChip(
                                  key: const Key('kelas_tab_diikuti'),
                                  label: 'Diikuti',
                                  tabIndex: 0,
                                ),
                                _buildModeChip(
                                  key: const Key('kelas_tab_mendampingi'),
                                  label: 'Mendampingi',
                                  tabIndex: 1,
                                ),
                              ],
                      ),
                    );
                  },
                ),
              Expanded(
                child: showTeaching
                    ? TeachingClassesSection(
                        controller: pengajarCtrl,
                        breadcrumbRoot: 'Kelas',
                        headerTitle: widget.isGuruRole
                            ? 'Kelas Mengajar'
                            : 'Kelas Didampingi',
                        fetchOnInit: false,
                        emptyMessage: widget.isGuruRole
                            ? 'Anda belum ditugaskan mengampu kelas'
                            : 'Belum ada kelas yang Anda dampingi',
                      )
                    : RegisteredClassesSection(
                        controller: widget.controller,
                        breadcrumbRoot: 'Kelas',
                        emptyMessage: 'Anda belum bergabung kelas manapun',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RegisteredClassesSection extends StatefulWidget {
  final KelasController? controller;
  final String breadcrumbRoot;
  final String emptyMessage;
  final String? emptyHint;
  final VoidCallback? onAddClass;
  final Widget? listTopBar;

  const RegisteredClassesSection({
    super.key,
    this.controller,
    required this.breadcrumbRoot,
    required this.emptyMessage,
    this.emptyHint,
    this.onAddClass,
    this.listTopBar,
  });

  @override
  State<RegisteredClassesSection> createState() =>
      _RegisteredClassesSectionState();
}

class _RegisteredClassesSectionState extends State<RegisteredClassesSection> {
  bool _isJoining = false;
  final List<ClassItem> _fallbackClasses = [];

  @override
  void initState() {
    super.initState();
    widget.controller?.getListKelas();
  }

  List<ClassItem> get _classes {
    final ctrl = widget.controller;
    if (ctrl == null) return _fallbackClasses;
    final enrolled = ctrl.listKelas.where((k) => !k.guru).toList();
    return [
      for (var i = 0; i < enrolled.length; i++)
        enrolled[i].toClassItem(coverIndex: i),
    ];
  }

  void _openClass(ClassItem data) {
    final trail = [widget.breadcrumbRoot, data.title];
    openPage(
      context,
      breadcrumb: trail,
      page: ClassDetailScreen(
        classData: data,
        breadcrumb: trail,
        controller: widget.controller,
      ),
    );
  }

  Future<void> _confirmLeave(ClassItem data) async {
    final yes = await showConfirmDialog(
      context,
      title: 'Batalkan Pendaftaran',
      message: 'Apakah anda yakin ingin membatalkan pendaftaran',
    );
    if (!yes || !mounted) return;

    final ctrl = widget.controller;
    if (ctrl != null) {
      final err = await ctrl.leaveKelas(data.code);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(err)));
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Berhasil keluar dari kelas')),
          );
      }
    } else {
      setState(() => _fallbackClasses.remove(data));
    }
  }

  Future<void> _handleJoinClass(String code) async {
    final ctrl = widget.controller;
    if (ctrl != null) {
      final err = await ctrl.joinKelas(code);
      if (!mounted) return;
      if (err != null) {
        await showInfoDialog(
          context,
          title: 'Terjadi error',
          message: err,
        );
        return;
      }
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Berhasil bergabung ke dalam kelas')),
        );
    } else {
      setState(() {
        _fallbackClasses.add(
          ClassItem(
            title: 'Kelas $code',
            grade: 'Kelas X',
            teacher: 'Pengajar',
            coverIndex: _fallbackClasses.length,
            code: code,
          ),
        );
        _isJoining = false;
      });
    }
  }

  Widget _buildBody(BuildContext context) {
    final ctrl = widget.controller;

    if (_isJoining) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: JoinClassForm(
            onCancel: () => setState(() => _isJoining = false),
            onJoined: _handleJoinClass,
          ),
        ),
      );
    }

    if (ctrl != null && ctrl.isLoading && ctrl.listKelas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final classes = _classes;

    if (classes.isEmpty) {
      return Column(
        children: [
          if (widget.listTopBar != null) widget.listTopBar!,
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: EmptyClassView(
                  message: widget.emptyMessage,
                  hint: widget.emptyHint,
                  onJoinClass: () => setState(() => _isJoining = true),
                  onAddClass: widget.onAddClass,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final h = responsiveHorizontalInset(
          width,
          maxWidth: ResponsiveBreakpoints.wide,
        );

        return Column(
          children: [
            widget.listTopBar ??
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(h, 12, h, 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Kelas Terdaftar',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isJoining = true),
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text('Gabung Kelas'),
                          style: AppTheme.softCompactButton,
                        ),
                      ],
                    ),
                  ),
                ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => widget.controller?.getListKelas(),
                child: GridView.builder(
                  padding: responsiveListPadding(
                    width,
                    maxWidth: ResponsiveBreakpoints.wide,
                    top: 0,
                    bottom: 16,
                  ),
                  gridDelegate: responsiveClassGridDelegate(
                    context,
                    width,
                    maxContentWidth: ResponsiveBreakpoints.wide,
                  ),
                  itemCount: classes.length,
                  itemBuilder: (context, index) => ClassCard(
                    data: classes[index],
                    onTap: () => _openClass(classes[index]),
                    menuLabel: 'Batalkan Pendaftaran',
                    onMenuSelected: () => _confirmLeave(classes[index]),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (ctrl == null) {
      return _buildBody(context);
    }
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => _buildBody(context),
    );
  }
}

class _MateriData {
  final int? id;
  final String title;
  final String author;
  final DateTime postedAt;
  final String description;
  final List<LampiranItem> lampiran;

  const _MateriData({
    this.id,
    required this.title,
    required this.author,
    required this.postedAt,
    required this.description,
    this.lampiran = const [],
  });

  factory _MateriData.fromModel(PostinganModel model, {String? author}) {
    return _MateriData(
      id: model.id,
      title: model.judul,
      author: author ?? 'Pengajar',
      postedAt: model.dibuat,
      description: model.deskripsi,
      lampiran: model.lampiranItems,
    );
  }
}

class _TugasData {
  final int? id;
  final String title;
  final String author;
  final DateTime postedAt;
  final DateTime dueDate;
  final int points = 100;
  final String description;
  String status = 'Ditugaskan';
  final List<LampiranItem> lampiran;
  final List<LampiranItem> submissionLampiran;
  final List<LampiranItem> draftLampiran;

  _TugasData({
    this.id,
    required this.title,
    required this.author,
    required this.postedAt,
    required this.dueDate,
    required this.description,
    List<LampiranItem>? lampiran,
    List<LampiranItem>? submissionLampiran,
    List<LampiranItem>? draftLampiran,
  }) : lampiran = lampiran ?? [],
       submissionLampiran = submissionLampiran ?? [],
       draftLampiran = draftLampiran ?? [];

  bool get isSubmitted =>
      status == 'Dikumpulkan' || status == 'Ditandai Sebagai Selesai';

  factory _TugasData.fromModel(PostinganModel model, {String? author}) {
    return _TugasData(
      id: model.id,
      title: model.judul,
      author: author ?? 'Pengajar',
      postedAt: model.dibuat,
      dueDate: model.dibuat.add(const Duration(days: 7)),
      description: model.deskripsi,
      lampiran: List<LampiranItem>.from(model.lampiranItems),
    );
  }
}

class ClassDetailScreen extends StatefulWidget {
  final ClassItem classData;
  final List<String> breadcrumb;
  final KelasController? controller;
  final int initialTab;

  const ClassDetailScreen({
    super.key,
    required this.classData,
    required this.breadcrumb,
    this.controller,
    this.initialTab = 0,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  bool _isLoading = false;
  List<_MateriData> _materiList = [];
  List<_TugasData> _tugasList = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final ctrl = widget.controller;
    if (ctrl == null) return;

    setState(() => _isLoading = true);

    final results = await Future.wait([
      ctrl.getListMateri(widget.classData.code),
      ctrl.getListTugas(widget.classData.code),
    ]);

    if (!mounted) return;

    final (materiModels, materiErr) = results[0];
    final (tugasModels, tugasErr) = results[1];
    final author = widget.classData.teacher ?? 'Pengajar';

    setState(() {
      _isLoading = false;
      if (materiModels != null) {
        _materiList = materiModels
            .map((m) => _MateriData.fromModel(m, author: author))
            .toList();
      }
      if (tugasModels != null) {
        _tugasList = tugasModels
            .map((t) => _TugasData.fromModel(t, author: author))
            .toList();
      }
    });

    final firstError = materiErr ?? tugasErr;
    if (firstError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(firstError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = responsiveHorizontalInset(
            constraints.maxWidth,
            maxWidth: 960,
          );
          return Column(
            children: [
              Padding(
                padding: alignedBackTitlePadding(h),
                child: BackTitleRow(title: widget.classData.title),
              ),
              if (widget.classData.description.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(h, 0, h, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      widget.classData.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorColor: AppColors.text,
                labelColor: AppColors.text,
                unselectedLabelColor: AppColors.secondaryText,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                dividerColor: Colors.transparent,
                padding: EdgeInsets.only(left: math.max(8.0, h - 8)),
                tabs: const [
                  Tab(text: 'Materi'),
                  Tab(text: 'Tugas'),
                  Tab(text: 'Anggota'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildMateriTab(h),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildTugasTab(h),
                    AnggotaKelasTab(
                      kodeKelas: widget.classData.code,
                      loadMembers: widget.controller == null
                          ? null
                          : () => widget.controller!.getListAnggota(
                              widget.classData.code,
                            ),
                      horizontalPadding: h,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMateriTab(double horizontalPadding) {
    if (_materiList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada materi',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          16,
        ),
        itemCount: _materiList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final m = _materiList[index];
          return PostCard(
            icon: Icons.menu_book_outlined,
            label: 'Materi Baru:',
            title: m.title,
            date: m.postedAt,
            onTap: () => openPage(
              context,
              breadcrumb: [...widget.breadcrumb, m.title],
              page: _MateriDetailScreen(
                materi: m,
                baseUrl: widget.controller?.baseUrl,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTugasTab(double horizontalPadding) {
    if (_tugasList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada tugas',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          24,
        ),
        children: [
          const Text(
            'Assigned',
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.underline,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          for (final tugas in _tugasList) ...[
            PostCard(
              icon: Icons.list_alt_outlined,
              label: 'Tugas Baru:',
              title: tugas.title,
              date: tugas.postedAt,
              onTap: () => openPage(
                context,
                breadcrumb: [...widget.breadcrumb, tugas.title],
                page: _TugasDetailScreen(
                  kodeKelas: widget.classData.code,
                  tugas: tugas,
                  controller: widget.controller,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MateriDetailScreen extends StatefulWidget {
  final _MateriData materi;
  final String? baseUrl;

  const _MateriDetailScreen({required this.materi, this.baseUrl});

  @override
  State<_MateriDetailScreen> createState() => _MateriDetailScreenState();
}

class _MateriDetailScreenState extends State<_MateriDetailScreen> {
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
                  elevation: 3,
                  shape: const StadiumBorder(),
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
                  elevation: 3,
                  shape: const StadiumBorder(),
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
            elevation: 3,
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.secondaryText.withValues(alpha: 0.25),
                  ),
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
            decoration: BoxDecoration(
              color: AppColors.color1,
              borderRadius: BorderRadius.circular(12),
            ),
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
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondaryText.withValues(alpha: 0.4),
              ),
            ),
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

class _TugasDetailScreen extends StatefulWidget {
  final String kodeKelas;
  final _TugasData tugas;
  final KelasController? controller;

  const _TugasDetailScreen({
    required this.kodeKelas,
    required this.tugas,
    this.controller,
  });

  @override
  State<_TugasDetailScreen> createState() => _TugasDetailScreenState();
}

class _TugasDetailScreenState extends State<_TugasDetailScreen> {
  bool _composing = false;
  bool _isBusy = false;
  bool _isUploading = false;
  bool _isLoadingPengumpulan = false;

  _TugasData get _tugas => widget.tugas;
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
        if (pengumpulan.submitted) {
          final merged = mergeLampiranWithLocal(
            pengumpulan.lampiranItems,
            [..._tugas.submissionLampiran, ..._drafts],
          );
          _tugas.submissionLampiran
            ..clear()
            ..addAll(merged);
          _tugas.status = merged.isEmpty
              ? 'Ditandai Sebagai Selesai'
              : 'Dikumpulkan';
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
    if (_isBusy) return;
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
    if (_isBusy) return;
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
    if (_isBusy || _isUploading) return;
    if (!isMarkDone && _drafts.isEmpty) return;

    final itemsToSubmit = isMarkDone
        ? const <LampiranItem>[]
        : List<LampiranItem>.from(_drafts);

    setState(() => _isBusy = true);
    try {
      List<LampiranItem> syncedItems = itemsToSubmit;
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
          syncedItems = mergeLampiranWithLocal(
            result.lampiranItems,
            itemsToSubmit,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _tugas.submissionLampiran
          ..clear()
          ..addAll(syncedItems);
        _tugas.status = syncedItems.isEmpty
            ? 'Ditandai Sebagai Selesai'
            : 'Dikumpulkan';
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
    if (_isBusy || _isUploading || !_tugas.isSubmitted) return;

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
              'Tenggat: ${formatTanggal(_tugas.dueDate)}',
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
              '.../${_tugas.points}',
              style: const TextStyle(
                fontSize: 12,
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
        elevation: 3,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 12),
      );

  Widget _buildSubmissionCard() {
    final actionsDisabled = _isBusy || _isUploading;

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  _tugas.status,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
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
                    shape: const StadiumBorder(),
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
