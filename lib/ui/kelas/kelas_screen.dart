import 'package:flutter/material.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';

class KelasScreen extends StatelessWidget {
  final KelasController controller;

  const KelasScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Kelas'],
      child: RegisteredClassesSection(
        controller: controller,
        breadcrumbRoot: 'Kelas',
        emptyMessage: 'Anda belum bergabung kelas manapun',
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
    return [
      for (var i = 0; i < ctrl.listKelas.length; i++)
        ctrl.listKelas[i].toClassItem(coverIndex: i),
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
      return JoinClassForm(
        onCancel: () => setState(() => _isJoining = false),
        onJoined: _handleJoinClass,
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
            child: EmptyClassView(
              message: widget.emptyMessage,
              hint: widget.emptyHint,
              onJoinClass: () => setState(() => _isJoining = true),
              onAddClass: widget.onAddClass,
            ),
          ),
        ],
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        widget.listTopBar ??
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Kelas Terdaftar',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isJoining = true),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Gabung Kelas'),
                    style: AppTheme.softCompactButton,
                  ),
                ],
              ),
            ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.controller?.getListKelas(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 152,
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

  _TugasData({
    this.id,
    required this.title,
    required this.author,
    required this.postedAt,
    required this.dueDate,
    required this.description,
    List<LampiranItem>? lampiran,
  }) : lampiran = lampiran ?? [];

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

  const ClassDetailScreen({
    super.key,
    required this.classData,
    required this.breadcrumb,
    this.controller,
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

    final (materiModels, _) = results[0];
    final (tugasModels, _) = results[1];
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
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          BackTitleRow(title: widget.classData.title),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: AppColors.text,
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.secondaryText,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 13),
            dividerColor: Colors.transparent,
            padding: EdgeInsets.only(left: 8),
            tabs: [
              Tab(text: 'Materi'),
              Tab(text: 'Tugas'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _buildMateriTab(),
                      _buildTugasTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMateriTab() {
    if (_materiList.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada materi',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              page: _MateriDetailScreen(materi: m),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTugasTab() {
    if (_tugasList.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada tugas',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                page: _TugasDetailScreen(tugas: tugas),
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

  const _MateriDetailScreen({required this.materi});

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

    return Column(
      children: [
        BackTitleRow(title: materi.title),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                const SizedBox(height: 12),
                Text(
                  materi.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
                const SizedBox(height: 16),
                for (final item in materi.lampiran) ...[
                  FileCard.fromItem(item),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                if (_showAi)
                  _buildAiSection()
                else
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
                        Text('Bantuan AI', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 8),
                        Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiSection() {
    final canSend = _textController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.secondaryText.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 20),
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
  final _TugasData tugas;

  const _TugasDetailScreen({required this.tugas});

  @override
  State<_TugasDetailScreen> createState() => _TugasDetailScreenState();
}

class _TugasDetailScreenState extends State<_TugasDetailScreen> {
  bool _composing = false;
  final List<LampiranItem> _drafts = [];

  _TugasData get _tugas => widget.tugas;

  Future<void> _addFile() async {
    final name = await showAddLinkDialog(
      context,
      title: 'Tambahkan file',
      label: 'Nama file',
      buttonLabel: 'Tambah file',
    );
    if (name == null || !mounted) return;
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'PDF';
    setState(() => _drafts.add(LampiranItem(name: name, detail: ext)));
  }

  Future<void> _addLink() async {
    final link = await showAddLinkDialog(context);
    if (link == null || !mounted) return;
    setState(() {
      _drafts.add(LampiranItem(name: 'Link', detail: link, isLink: true));
    });
  }

  void _submit() {
    setState(() {
      _tugas.lampiran.addAll(_drafts);
      _tugas.status = 'Dikumpulkan';
      _drafts.clear();
      _composing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        '${_tugas.author} • ${formatTanggal(_tugas.postedAt)} • ${formatJam(_tugas.postedAt)}';

    return Column(
      children: [
        BackTitleRow(title: _tugas.title),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                const SizedBox(height: 8),
                Row(
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
                      margin: const EdgeInsets.symmetric(horizontal: 8),
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
                Row(
                  children: [
                    const Text(
                      'Nilai',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 28),
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
                const SizedBox(height: 16),
                PostCard(
                  icon: Icons.list_alt_outlined,
                  label: 'Tugas Baru:',
                  title: _tugas.title,
                  date: _tugas.postedAt,
                ),
                const SizedBox(height: 16),
                _buildSubmissionCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionCard() {
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
                if (!_composing)
                  Text(
                    _tugas.status,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _tugas.lampiran.length; i++) ...[
              Row(
                children: [
                  Expanded(child: FileCard.fromItem(_tugas.lampiran[i])),
                  IconButton(
                    tooltip: 'Hapus lampiran',
                    onPressed: () => setState(() {
                      _tugas.lampiran.removeAt(i);
                      if (_tugas.lampiran.isEmpty) {
                        _tugas.status = 'Ditugaskan';
                      }
                    }),
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_composing) ...[
              for (final draft in _drafts) ...[
                Row(
                  children: [
                    Expanded(child: FileCard.fromItem(draft)),
                    IconButton(
                      tooltip: 'Hapus lampiran',
                      onPressed: () => setState(() => _drafts.remove(draft)),
                      icon: const Icon(Icons.close, color: AppColors.text),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addFile,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('File', style: TextStyle(fontSize: 12)),
                      style: AppTheme.softCompactButton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addLink,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Link', style: TextStyle(fontSize: 12)),
                      style: AppTheme.softCompactButton,
                    ),
                  ),
                ],
              ),
              if (_drafts.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.color1,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Serahkan',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _composing = true),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                  style: AppTheme.softCompactButton,
                ),
              ),
              if (_tugas.status == 'Ditugaskan') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(
                      () => _tugas.status = 'Ditandai Sebagai Selesai',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.color1,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Tandai Sebagai Selesai',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
