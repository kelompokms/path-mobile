import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/list_pengumpulan_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

void _copyText(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<ClassItem?> editKelasWithDialog(
  BuildContext context,
  ClassItem classData,
  PengajarController? controller,
) async {
  final result = await showEditKelasDialog(
    context,
    initialNama: classData.title,
    initialDeskripsi: classData.description,
  );
  if (result == null || !context.mounted) return null;

  if (controller != null) {
    final (updated, err) = await controller.editKelas(
      classData.code,
      nama: result.nama,
      deskripsi: result.deskripsi,
    );
    if (!context.mounted) return null;
    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return null;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Kelas berhasil diperbarui')));
    if (updated != null) {
      return updated.toClassItem(
        teacher: classData.teacher,
        coverIndex: classData.coverIndex,
      );
    }
  }

  return classData.copyWith(
    title: result.nama,
    description: result.deskripsi,
  );
}

class PengajarScreen extends StatefulWidget {
  final PengajarController controller;

  const PengajarScreen({super.key, required this.controller});

  @override
  State<PengajarScreen> createState() => _PengajarScreenState();
}

class _PengajarScreenState extends State<PengajarScreen> {
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    widget.controller.getListKelas();
  }

  List<ClassItem> get _classes {
    final teaching = widget.controller.listKelas.where((k) => k.guru).toList();
    return [
      for (var i = 0; i < teaching.length; i++)
        teaching[i].toClassItem(coverIndex: i),
    ];
  }

  Future<void> _createClass(
    String name,
    String description,
    String grade,
    String tahunAjaran,
  ) async {
    final err = await widget.controller.createKelas(
      nama: name,
      deskripsi: description,
      gradeInput: grade,
      tahunAjaran: tahunAjaran,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _showForm = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Kelas berhasil dibuat')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PageFrame(
      breadcrumb: const ['Pengajar'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final classes = _classes;
          if (_showForm) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _CreateClassForm(
                  onCreate: _createClass,
                  onCancel: () => setState(() => _showForm = false),
                ),
              ),
            );
          }
          if (widget.controller.isLoading && classes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (classes.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: EmptyClassView(
                  message: 'Anda belum membuat kelas',
                  joinLabel: 'Buat Kelas',
                  onJoinClass: () => setState(() => _showForm = true),
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final h = responsiveHorizontalInset(
                width,
                maxWidth: ResponsiveBreakpoints.wide,
              );

              return Column(
                children: [
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
                            'Kelas',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: AppTheme.softCompactButton,
                            onPressed: () => setState(() => _showForm = true),
                            icon: const Icon(Icons.add_box_outlined, size: 18),
                            label: const Text('Buat Kelas'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: widget.controller.getListKelas,
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
                        itemBuilder: (context, i) {
                          final item = classes[i];
                          return ClassCard(
                            data: item,
                            onTap: () => openPage(
                              context,
                              breadcrumb: ['Pengajar', item.title],
                              page: PengajarDetailScreen(
                                classData: item,
                                controller: widget.controller,
                              ),
                              routeName: 'pengajar-detail',
                            ),
                            menuItems: [
                              (
                                label: 'Edit kelas',
                                onSelected: () => editKelasWithDialog(
                                  context,
                                  item,
                                  widget.controller,
                                ),
                              ),
                              (
                                label: 'Salin link undangan kelas',
                                onSelected: () => _copyText(
                                  context,
                                  item.inviteLink,
                                  'Link undangan kelas disalin',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateClassForm extends StatefulWidget {
  final void Function(
    String name,
    String description,
    String grade,
    String tahunAjaran,
  )
  onCreate;
  final VoidCallback onCancel;

  const _CreateClassForm({required this.onCreate, required this.onCancel});

  @override
  State<_CreateClassForm> createState() => _CreateClassFormState();
}

class _CreateClassFormState extends State<_CreateClassForm> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _gradeController = TextEditingController();
  late final TextEditingController _tahunAjaranController;

  bool get _hasName => _nameController.text.trim().isNotEmpty;
  bool get _hasTahunAjaran => _tahunAjaranController.text.trim().isNotEmpty;
  bool get _canCreate => _hasName && _hasTahunAjaran;

  @override
  void initState() {
    super.initState();
    _tahunAjaranController = TextEditingController(
      text: PengajarController.defaultTahunAjaran(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _gradeController.dispose();
    _tahunAjaranController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = responsiveHorizontalPadding(constraints.maxWidth);
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buat Kelas',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 3,
                  color: AppColors.card,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.co_present,
                              size: 28,
                              color: AppColors.text,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Nama Kelas',
                                  isDense: true,
                                  border: UnderlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_hasName)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '*Wajib diisi',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _gradeController,
                          decoration: const InputDecoration(
                            hintText: 'Kelas',
                            isDense: true,
                            border: UnderlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tahunAjaranController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Tahun Ajaran',
                            hintText: 'Contoh: 2026/2027',
                            isDense: true,
                            border: UnderlineInputBorder(),
                          ),
                        ),
                        if (!_hasTahunAjaran)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '*Wajib diisi',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descController,
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: 'Deskripsi Kelas (opsional)',
                            isDense: true,
                            border: UnderlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.text,
                      ),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: AppTheme.softCompactButton,
                      onPressed: _canCreate
                          ? () => widget.onCreate(
                              _nameController.text.trim(),
                              _descController.text.trim(),
                              _gradeController.text.trim(),
                              _tahunAjaranController.text.trim(),
                            )
                          : null,
                      child: const Text('Buat'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MateriPengajar {
  int? id;
  String title;
  String description;
  final DateTime postedAt;
  List<LampiranItem> lampiran;

  _MateriPengajar({
    this.id,
    required this.title,
    required this.description,
    required this.postedAt,
    List<LampiranItem>? lampiran,
  }) : lampiran = lampiran ?? [];

  factory _MateriPengajar.fromModel(PostinganModel model) {
    return _MateriPengajar(
      id: model.id,
      title: model.judul,
      description: model.deskripsi,
      postedAt: model.dibuat,
      lampiran: List<LampiranItem>.from(model.lampiranItems),
    );
  }
}

class _TugasPengajar {
  int? id;
  String title;
  String description;
  final DateTime postedAt;
  DateTime? dueDate;
  final int points = 100;
  bool acceptSubmissions = true;
  List<LampiranItem> lampiran;
  final List<_PengumpulanItem> pengumpulan;

  _TugasPengajar({
    this.id,
    required this.title,
    required this.description,
    required this.postedAt,
    this.dueDate,
    List<LampiranItem>? lampiran,
    List<_PengumpulanItem>? pengumpulan,
  }) : lampiran = lampiran ?? [],
       pengumpulan =
           pengumpulan ??
           [
             _PengumpulanItem(
               studentName: 'Budi Santoso',
               fileName: 'Jawaban_Budi.pdf',
               status: 'Diserahkan',
             ),
             _PengumpulanItem(
               studentName: 'Siti Aminah',
               status: 'Ditugaskan',
             ),
           ];

  factory _TugasPengajar.fromModel(PostinganModel model) {
    return _TugasPengajar(
      id: model.id,
      title: model.judul,
      description: model.deskripsi,
      postedAt: model.dibuat,
      dueDate: model.dibuat.add(const Duration(days: 7)),
      lampiran: List<LampiranItem>.from(model.lampiranItems),
    );
  }
}

class _PengumpulanItem {
  final String studentName;
  final String? fileName;
  String status;
  int? score;

  _PengumpulanItem({
    required this.studentName,
    this.fileName,
    required this.status,
  });
}

class PengajarDetailScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final String breadcrumbRoot;

  const PengajarDetailScreen({
    super.key,
    required this.classData,
    this.controller,
    this.breadcrumbRoot = 'Pengajar',
  });

  @override
  State<PengajarDetailScreen> createState() => _PengajarDetailScreenState();
}

class _PengajarDetailScreenState extends State<PengajarDetailScreen> {
  late ClassItem _class;
  bool get _isGuru => _class.isGuru;

  bool _isLoading = false;
  List<_MateriPengajar> _materiList = [];
  List<_TugasPengajar> _tugasList = [];

  @override
  void initState() {
    super.initState();
    _class = widget.classData;
    _loadPosts();
  }

  @override
  void didUpdateWidget(covariant PengajarDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classData != widget.classData) {
      _class = widget.classData;
    }
  }

  Future<void> _editKelas() async {
    if (!_isGuru) return;
    final updated = await editKelasWithDialog(
      context,
      _class,
      widget.controller,
    );
    if (updated != null && mounted) {
      setState(() => _class = updated);
    }
  }

  Future<void> _loadPosts() async {
    final ctrl = widget.controller;
    if (ctrl == null) return;

    setState(() => _isLoading = true);

    final results = await Future.wait([
      ctrl.getListMateri(_class.code),
      ctrl.getListTugas(_class.code),
    ]);

    if (!mounted) return;

    final (materiModels, materiErr) = results[0];
    final (tugasModels, tugasErr) = results[1];

    setState(() {
      _isLoading = false;
      if (materiModels != null) {
        _materiList = materiModels.map(_MateriPengajar.fromModel).toList();
      }
      if (tugasModels != null) {
        _tugasList = tugasModels.map(_TugasPengajar.fromModel).toList();
      }
    });

    final firstError = materiErr ?? tugasErr;
    if (firstError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(firstError)));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleMateriCreated(_MateriPengajar materi) async {
    if (!_isGuru) return;
    final ctrl = widget.controller;
    if (ctrl != null) {
      final (created, err) = await ctrl.createMateri(
        _class.code,
        judul: materi.title,
        deskripsi: materi.description,
        lampiran: materi.lampiran,
      );
      if (!mounted) return;
      if (err != null) {
        _showSnackBar(err);
        return;
      }
      if (created != null) {
        final createdMateri = _MateriPengajar.fromModel(created)
          ..lampiran = mergeLampiranWithLocal(
            created.lampiranItems,
            materi.lampiran,
          );
        setState(() {
          _materiList.insert(0, createdMateri);
        });
        return;
      }
    }
    setState(() {
      _materiList.insert(0, materi);
    });
  }

  Future<bool> _handleTugasCreated(_TugasPengajar tugas) async {
    if (!_isGuru) return false;
    final ctrl = widget.controller;
    if (ctrl != null) {
      final (created, err) = await ctrl.createTugas(
        _class.code,
        judul: tugas.title,
        deskripsi: tugas.description,
        lampiran: tugas.lampiran,
      );
      if (!mounted) return false;
      if (err != null) {
        _showSnackBar(err);
        return false;
      }
      if (created != null) {
        tugas
          ..id = created.id
          ..title = created.judul
          ..description = created.deskripsi
          ..lampiran = mergeLampiranWithLocal(
            created.lampiranItems,
            tugas.lampiran,
          );
      }
    }
    setState(() {
      _tugasList.insert(0, tugas);
    });
    return true;
  }

  Future<bool> _handleTugasEdited(
    _TugasPengajar target,
    _TugasPengajar draft,
  ) async {
    if (!_isGuru) return false;
    final ctrl = widget.controller;
    PostinganModel? savedModel;
    if (ctrl != null) {
      if (target.id == null) {
        _showSnackBar('ID postingan tidak ditemukan');
        return false;
      }
      final (updated, err) = await ctrl.editPostingan(
        _class.code,
        target.id!,
        judul: draft.title,
        deskripsi: draft.description,
        lampiran: draft.lampiran,
        tipe: PostinganModel.tipeTugas,
      );
      if (!mounted) return false;
      if (err != null) {
        _showSnackBar(err);
        return false;
      }
      savedModel = updated;
    }
    setState(() {
      target
        ..title = savedModel?.judul ?? draft.title
        ..description = savedModel?.deskripsi ?? draft.description
        ..dueDate = draft.dueDate
        ..acceptSubmissions = draft.acceptSubmissions
        ..lampiran = savedModel != null
            ? mergeLampiranWithLocal(savedModel.lampiranItems, draft.lampiran)
            : List<LampiranItem>.from(draft.lampiran);
    });
    _showSnackBar('Tugas berhasil diperbarui');
    return true;
  }

  Future<bool> _editMateri(_MateriPengajar m) async {
    if (!_isGuru) return false;
    final result = await showDialog<
      ({String title, String description, List<LampiranItem> lampiran})
    >(
      context: context,
      builder: (_) => _EditPostinganDialog(
        headerTitle: 'Edit Materi',
        initialTitle: m.title,
        initialDescription: m.description,
        initialLampiran: m.lampiran,
        onUploadFiles: widget.controller?.uploadPostinganFiles,
        baseUrl: widget.controller?.baseUrl,
        titleHint: 'Edit judul materi disini',
        descHint: 'Edit deskripsi materi disini',
      ),
    );
    if (result == null || !mounted) return false;

    final ctrl = widget.controller;
    PostinganModel? savedModel;
    if (ctrl != null) {
      if (m.id == null) {
        _showSnackBar('ID postingan tidak ditemukan');
        return false;
      }
      final (updated, err) = await ctrl.editPostingan(
        _class.code,
        m.id!,
        judul: result.title,
        deskripsi: result.description,
        lampiran: result.lampiran,
        tipe: PostinganModel.tipeMateri,
      );
      if (!mounted) return false;
      if (err != null) {
        _showSnackBar(err);
        return false;
      }
      savedModel = updated;
    }

    setState(() {
      m
        ..title = savedModel?.judul ?? result.title
        ..description = savedModel?.deskripsi ?? result.description
        ..lampiran = savedModel != null
            ? mergeLampiranWithLocal(savedModel.lampiranItems, result.lampiran)
            : List<LampiranItem>.from(result.lampiran);
    });
    _showSnackBar('Materi berhasil diperbarui');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                child: Row(
                  children: [
                    Expanded(child: BackTitleRow(title: _class.title)),
                    if (_isGuru)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          tooltip: 'Edit kelas',
                          onPressed: _editKelas,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_class.description.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(h, 0, h, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      _class.description,
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
                      kodeKelas: _class.code,
                      loadMembers: widget.controller == null
                          ? null
                          : () => widget.controller!.getListAnggota(_class.code),
                      onPromoteToGuru: _isGuru && widget.controller != null
                          ? (member) => widget.controller!.promoteToGuru(
                              _class.code,
                              member.penggunaId,
                            )
                          : null,
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
    return Column(
      children: [
        if (_isGuru)
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                12,
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ClassCodeCard(classData: _class),
                  ElevatedButton.icon(
                    style: AppTheme.softCompactButton,
                    onPressed: () => openPage(
                      context,
                      breadcrumb: [
                        widget.breadcrumbRoot,
                        _class.title,
                        'Buat Materi',
                      ],
                      page: _BuatMateriScreen(
                        classData: _class,
                        controller: widget.controller,
                        onCreated: _handleMateriCreated,
                      ),
                    ),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Buat Materi'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _materiList.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada materi',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      _isGuru ? 0 : 12,
                      horizontalPadding,
                      16,
                    ),
                    itemCount: _materiList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final m = _materiList[i];
                      return PostCard(
                        icon: Icons.menu_book_outlined,
                        label: 'Materi Baru:',
                        title: m.title,
                        date: m.postedAt,
                        onTap: () => openPage(
                          context,
                          breadcrumb: [
                            widget.breadcrumbRoot,
                            _class.title,
                            m.title,
                          ],
                          page: _PengajarMateriDetailScreen(
                            materi: m,
                            isGuru: _isGuru,
                            baseUrl: widget.controller?.baseUrl,
                            onEdit: _isGuru ? () => _editMateri(m) : null,
                          ),
                        ),
                        menuLabels: _isGuru ? const ['Edit'] : null,
                        onMenuItemSelected: _isGuru
                            ? (_) => _editMateri(m)
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTugasTab(double horizontalPadding) {
    return Column(
      children: [
        if (_isGuru)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              12,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: AppTheme.softCompactButton,
                onPressed: () => openPage(
                  context,
                  breadcrumb: [
                    widget.breadcrumbRoot,
                    _class.title,
                    'Tugas',
                    'Buat Tugas',
                  ],
                  page: _TugasFormScreen(
                    classData: _class,
                    controller: widget.controller,
                    onSaved: _handleTugasCreated,
                    onEditedCreated: _handleTugasEdited,
                  ),
                ),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Tambah Tugas'),
              ),
            ),
          ),
        Expanded(
          child: _tugasList.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada tugas',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      _isGuru ? 0 : 12,
                      horizontalPadding,
                      16,
                    ),
                    itemCount: _tugasList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = _tugasList[i];
                      return PostCard(
                        icon: Icons.list_alt_outlined,
                        label: 'Tugas Baru:',
                        title: t.title,
                        date: t.postedAt,
                        onTap: () => openPage(
                          context,
                          breadcrumb: [
                            widget.breadcrumbRoot,
                            _class.title,
                            t.title,
                          ],
                          page: _PengajarTugasDetailScreen(
                            classData: _class,
                            tugas: t,
                            isGuru: _isGuru,
                            controller: widget.controller,
                            baseUrl: widget.controller?.baseUrl,
                            onEdited: _isGuru
                                ? (draft) => _handleTugasEdited(t, draft)
                                : null,
                          ),
                        ),
                        menuLabels: _isGuru ? const ['Edit'] : null,
                        onMenuItemSelected: _isGuru
                            ? (_) => openPage(
                                context,
                                breadcrumb: [
                                  widget.breadcrumbRoot,
                                  _class.title,
                                  'Tugas',
                                  'Edit Tugas',
                                ],
                                page: _TugasFormScreen(
                                  classData: _class,
                                  existing: t,
                                  controller: widget.controller,
                                  onSaved: (draft) => _handleTugasEdited(t, draft),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ClassCodeCard extends StatelessWidget {
  final ClassItem classData;

  const _ClassCodeCard({required this.classData});

  void _showBigCode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kode kelas',
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.text),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      classData.code,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  classData.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kode kelas',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: PopupMenuButton<int>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.more_vert, color: AppColors.text),
                    color: AppColors.background,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (i) {
                      if (i == 0) {
                        _copyText(
                          context,
                          classData.inviteLink,
                          'Link undangan kelas disalin',
                        );
                      } else {
                        _copyText(
                          context,
                          classData.code,
                          'Kode kelas disalin',
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 0,
                        child: Text('Salin link undangan kelas'),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Text('Menyalin kode kelas'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      classData.code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showBigCode(context),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 16,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPostinganDialog extends StatefulWidget {
  final String headerTitle;
  final String initialTitle;
  final String initialDescription;
  final List<LampiranItem> initialLampiran;
  final UploadLampiranFiles? onUploadFiles;
  final String? baseUrl;
  final String titleHint;
  final String descHint;

  const _EditPostinganDialog({
    required this.headerTitle,
    required this.initialTitle,
    required this.initialDescription,
    this.initialLampiran = const [],
    this.onUploadFiles,
    this.baseUrl,
    required this.titleHint,
    required this.descHint,
  });

  @override
  State<_EditPostinganDialog> createState() => _EditPostinganDialogState();
}

class _EditPostinganDialogState extends State<_EditPostinganDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late List<LampiranItem> _lampiran;
  bool _isUploading = false;

  bool get _hasTitle => _titleCtrl.text.trim().isNotEmpty;
  bool get _canSave => _hasTitle && !_isUploading;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _lampiran = List<LampiranItem>.from(widget.initialLampiran);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.headerTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Edit Judul',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
              TextField(
                controller: _titleCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 16, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: widget.titleHint,
                  errorText: _hasTitle ? null : 'Judul wajib diisi',
                  isDense: true,
                  border: const UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit Deskripsi',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
              TextField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: widget.descHint,
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: AppColors.text, height: 1),
              const SizedBox(height: 12),
              LampiranEditor(
                items: _lampiran,
                onChanged: (v) => setState(() => _lampiran = v),
                onUploadFiles: widget.onUploadFiles,
                onUploadingChanged: (uploading) {
                  if (mounted) setState(() => _isUploading = uploading);
                },
                baseUrl: widget.baseUrl,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.text,
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _canSave
                          ? () => Navigator.pop(context, (
                              title: _titleCtrl.text.trim(),
                              description: _descCtrl.text.trim(),
                              lampiran: _lampiran,
                            ))
                          : null,
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PengajarMateriDetailScreen extends StatefulWidget {
  final _MateriPengajar materi;
  final bool isGuru;
  final String? baseUrl;
  final Future<bool> Function()? onEdit;

  const _PengajarMateriDetailScreen({
    required this.materi,
    this.isGuru = false,
    this.baseUrl,
    this.onEdit,
  });

  @override
  State<_PengajarMateriDetailScreen> createState() =>
      _PengajarMateriDetailScreenState();
}

class _PengajarMateriDetailScreenState
    extends State<_PengajarMateriDetailScreen> {
  Future<void> _handleEdit() async {
    final onEdit = widget.onEdit;
    if (onEdit == null) return;
    final edited = await onEdit();
    if (edited && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final materi = widget.materi;
    final meta =
        'Pengajar • ${formatTanggal(materi.postedAt)} • ${formatJam(materi.postedAt)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 800,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: Row(
                children: [
                  Expanded(child: BackTitleRow(title: materi.title)),
                  if (widget.isGuru && widget.onEdit != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Edit materi',
                        onPressed: _handleEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
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
                    if (materi.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        materi.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final item in materi.lampiran) ...[
                      FileCard.fromItem(item, baseUrl: widget.baseUrl),
                      const SizedBox(height: 12),
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
}

class _BuatMateriScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final ValueChanged<_MateriPengajar> onCreated;
  final String initialTitle;
  final String initialDescription;
  final List<LampiranItem> initialLampiran;

  const _BuatMateriScreen({
    required this.classData,
    this.controller,
    required this.onCreated,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialLampiran = const [],
  });

  @override
  State<_BuatMateriScreen> createState() => _BuatMateriScreenState();
}

class _BuatMateriScreenState extends State<_BuatMateriScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late List<LampiranItem> _lampiran;
  bool _isUploading = false;

  bool get _canSave => _titleController.text.trim().isNotEmpty && !_isUploading;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDescription);
    _lampiran = List.of(widget.initialLampiran);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onCreated(
      _MateriPengajar(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        postedAt: DateTime.now(),
        lampiran: _lampiran,
      ),
    );
    Navigator.of(context).popUntil(ModalRoute.withName('pengajar-detail'));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 760,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Buat Materi'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ketikkan judul materi',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    if (!_canSave)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Isian wajib diisi',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Deskripsi materi (opsional)',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LampiranEditor(
                      items: _lampiran,
                      onChanged: (v) => setState(() => _lampiran = v),
                      onUploadFiles: widget.controller?.uploadPostinganFiles,
                      onUploadingChanged: (uploading) {
                        if (mounted) setState(() => _isUploading = uploading);
                      },
                      baseUrl: widget.controller?.baseUrl,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Atau buat otomatis menggunakan AI',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => openPage(
                        context,
                        breadcrumb: [
                          'Pengajar',
                          widget.classData.title,
                          'Buat Materi',
                        ],
                        page: _BuatMateriAiScreen(
                          classData: widget.classData,
                          controller: widget.controller,
                          onCreated: widget.onCreated,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Buat materi dengan AI',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BuatMateriAiScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final ValueChanged<_MateriPengajar> onCreated;

  const _BuatMateriAiScreen({
    required this.classData,
    this.controller,
    required this.onCreated,
  });

  @override
  State<_BuatMateriAiScreen> createState() => _BuatMateriAiScreenState();
}

class _BuatMateriAiScreenState extends State<_BuatMateriAiScreen> {
  static const _baseModes = ['Tabel', 'Diagram', 'Ilustrasi'];
  static const _modes = ['Tabel', 'Diagram', 'Ilustrasi', 'Kombinasi'];

  final _titleController = TextEditingController();
  final _promptController = TextEditingController();
  final Set<String> _selectedModes = {};

  bool get _canCreate =>
      _titleController.text.trim().isNotEmpty &&
      _promptController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
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

  void _generate() {
    final title = _titleController.text.trim();
    final prompt = _promptController.text.trim();
    final generated = _MateriPengajar(
      title: title,
      description: 'Materi hasil AI untuk topik "$prompt".',
      postedAt: DateTime.now(),
      lampiran: [
        LampiranItem(name: 'Materi_AI_$title.pdf', detail: 'PDF'),
      ],
    );

    openPage(
      context,
      breadcrumb: ['Pengajar', widget.classData.title, 'Buat Materi'],
      page: _KonfirmasiMateriAiScreen(
        classData: widget.classData,
        controller: widget.controller,
        materi: generated,
        onCreated: widget.onCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 760,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Buat materi dengan AI'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ketikkan judul materi',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptController,
                      onChanged: (_) => setState(() {}),
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Apa materi yang ingin anda buat?',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tambahkan elemen pendukung',
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minimumSize: const Size(0, 32),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: Text(label),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _canCreate ? _generate : null,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Buat materi'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KonfirmasiMateriAiScreen extends StatelessWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final _MateriPengajar materi;
  final ValueChanged<_MateriPengajar> onCreated;

  const _KonfirmasiMateriAiScreen({
    required this.classData,
    this.controller,
    required this.materi,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 800,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: BackTitleRow(title: materi.title),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materi.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in materi.lampiran) ...[
                      FileCard.fromItem(item, baseUrl: controller?.baseUrl),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Apakah anda ingin menggunakan materi ini ?',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: () {
                            onCreated(materi);
                            Navigator.of(context).popUntil(
                              ModalRoute.withName('pengajar-detail'),
                            );
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Materi berhasil dibuat'),
                                ),
                              );
                          },
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: const Text('Gunakan materi'),
                        ),
                        ElevatedButton(
                          style: AppTheme.softCompactButton,
                          onPressed: () => replacePage(
                            context,
                            breadcrumb: [
                              'Pengajar',
                              classData.title,
                              'Buat Materi',
                            ],
                            page: _BuatMateriScreen(
                              classData: classData,
                              controller: controller,
                              onCreated: onCreated,
                              initialTitle: materi.title,
                              initialDescription: materi.description,
                              initialLampiran: materi.lampiran,
                            ),
                          ),
                          child: const Text('Sesuaikan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PengajarTugasDetailScreen extends StatefulWidget {
  final ClassItem classData;
  final _TugasPengajar tugas;
  final bool isGuru;
  final PengajarController? controller;
  final String? baseUrl;
  final Future<bool> Function(_TugasPengajar draft)? onEdited;

  const _PengajarTugasDetailScreen({
    required this.classData,
    required this.tugas,
    this.isGuru = true,
    this.controller,
    this.baseUrl,
    this.onEdited,
  });

  @override
  State<_PengajarTugasDetailScreen> createState() =>
      _PengajarTugasDetailScreenState();
}

class _PengajarTugasDetailScreenState
    extends State<_PengajarTugasDetailScreen> {
  Future<void> _handleEdit() async {
    final onEdited = widget.onEdited;
    if (onEdited == null) return;
    final saved = await openPage<bool>(
      context,
      breadcrumb: [
        'Pengajar',
        widget.classData.title,
        'Tugas',
        'Edit Tugas',
      ],
      page: _TugasFormScreen(
        classData: widget.classData,
        existing: widget.tugas,
        controller: widget.controller,
        onSaved: onEdited,
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final classData = widget.classData;
    final tugas = widget.tugas;
    final isGuru = widget.isGuru;
    final baseUrl = widget.baseUrl;
    final meta =
        'Pengajar • ${formatJam(tugas.postedAt)} • ${formatTanggal(tugas.postedAt)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 800,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: Row(
                children: [
                  Expanded(child: BackTitleRow(title: tugas.title)),
                  if (isGuru && widget.onEdited != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Edit tugas',
                        onPressed: _handleEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${tugas.points} poin',
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
                          tugas.dueDate == null
                              ? 'Tanpa tenggat'
                              : 'Tenggat: ${formatTanggal(tugas.dueDate!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    if (tugas.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        tugas.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final item in tugas.lampiran) ...[
                      FileCard.fromItem(item, baseUrl: baseUrl),
                      const SizedBox(height: 12),
                    ],
                    if (isGuru) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'AI bisa membantu guru dalam mengecek jawaban siswa',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () => openPage(
                              context,
                              breadcrumb: [
                                'Pengajar',
                                classData.title,
                                tugas.title,
                              ],
                              page: _CekJawabanScreen(
                                classData: classData,
                                tugas: tugas,
                              ),
                              routeName: 'cek-jawaban',
                            ),
                            style: FilledButton.styleFrom(
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                            ),
                            child: const Text('Cek jawaban'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => openPage(
                              context,
                              breadcrumb: [
                                'Pengajar',
                                classData.title,
                                tugas.title,
                                'Daftar Pengumpulan',
                              ],
                              page: ListPengumpulanScreen(
                                classData: classData,
                                postinganId: tugas.id,
                                tugasTitle: tugas.title,
                                controller: widget.controller,
                                baseUrl: baseUrl,
                              ),
                              routeName: 'list-pengumpulan',
                            ),
                            icon: const Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 18,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.color1,
                              side: const BorderSide(color: AppColors.color1),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            label: const Text('Daftar pengumpulan'),
                          ),
                        ],
                      ),
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
}

class _TugasFormScreen extends StatefulWidget {
  final ClassItem classData;
  final _TugasPengajar? existing;
  final PengajarController? controller;
  final Future<bool> Function(_TugasPengajar tugas) onSaved;
  final Future<bool> Function(_TugasPengajar target, _TugasPengajar draft)?
  onEditedCreated;

  const _TugasFormScreen({
    required this.classData,
    this.existing,
    this.controller,
    required this.onSaved,
    this.onEditedCreated,
  });

  @override
  State<_TugasFormScreen> createState() => _TugasFormScreenState();
}

class _TugasFormScreenState extends State<_TugasFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  DateTime? _dueDate;
  bool _accept = true;
  late List<LampiranItem> _lampiran;
  bool _isUploading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;
  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _canSave => _hasTitle && !_isUploading && !_isSaving;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _dueDate = t?.dueDate;
    _accept = t?.acceptSubmissions ?? true;
    _lampiran = List.of(t?.lampiran ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final existing = widget.existing;
    try {
      if (existing == null) {
        final created = _TugasPengajar(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          postedAt: DateTime.now(),
          dueDate: _dueDate,
          lampiran: List<LampiranItem>.from(_lampiran),
        );
        final ok = await widget.onSaved(created);
        if (!mounted || !ok) return;
        replacePage(
          context,
          breadcrumb: ['Pengajar', widget.classData.title, created.title],
          page: _PengajarTugasDetailScreen(
            classData: widget.classData,
            tugas: created,
            controller: widget.controller,
            baseUrl: widget.controller?.baseUrl,
            onEdited: widget.onEditedCreated == null
                ? null
                : (draft) => widget.onEditedCreated!(created, draft),
          ),
        );
      } else {
        final draft = _TugasPengajar(
          id: existing.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          postedAt: existing.postedAt,
          dueDate: _dueDate,
          lampiran: List<LampiranItem>.from(_lampiran),
          pengumpulan: existing.pengumpulan,
        )..acceptSubmissions = _accept;
        final ok = await widget.onSaved(draft);
        if (!mounted || !ok) return;
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = _isEdit
        ? 'Edit Tenggat Waktu (opsional)'
        : 'Tenggat Waktu (opsional)';
    final dueLabel = _dueDate == null
        ? hint
        : '${formatTanggal(_dueDate!)}, ${formatJam(_dueDate!)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 760,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: BackTitleRow(
                title: _isEdit ? 'Edit Tugas' : 'Tambah Tugas',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, 4, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEdit)
                      const Text(
                        'Edit Judul',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ketikkan judul tugas',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    if (!_hasTitle)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Isian wajib diisi',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_isEdit)
                      const Text(
                        'Edit Deskripsi',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    TextField(
                      controller: _descController,
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Deskripsi petunjuk (opsional)',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Switch(
                            value: _accept,
                            onChanged: (v) => setState(() => _accept = v),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Menerima kiriman',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Tenggat waktu',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: InkWell(
                            onTap: _pickDueDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      dueLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            tooltip: 'Hapus tenggat',
                            onPressed: () => setState(() => _dueDate = null),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LampiranEditor(
                      items: _lampiran,
                      onChanged: (v) => setState(() => _lampiran = v),
                      onUploadFiles: widget.controller?.uploadPostinganFiles,
                      onUploadingChanged: (uploading) {
                        if (mounted) setState(() => _isUploading = uploading);
                      },
                      baseUrl: widget.controller?.baseUrl,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: const StadiumBorder(),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CekJawabanScreen extends StatefulWidget {
  final ClassItem classData;
  final _TugasPengajar tugas;

  const _CekJawabanScreen({required this.classData, required this.tugas});

  @override
  State<_CekJawabanScreen> createState() => _CekJawabanScreenState();
}

class _CekJawabanScreenState extends State<_CekJawabanScreen> {
  static const _statuses = ['Diserahkan', 'Ditugaskan', 'Dinilai'];
  static const _filters = ['Semua', 'Diserahkan', 'Ditugaskan', 'Dinilai'];

  String _filter = 'Semua';
  final Map<String, TextEditingController> _scoreControllers = {};

  _TugasPengajar get _tugas => widget.tugas;

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(_PengumpulanItem p) {
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

  Widget _buildControls(List<_PengumpulanItem> all) {
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
              page: _KoreksiAiScreen(
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
              shape: const StadiumBorder(),
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
                  shape: const StadiumBorder(),
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

  List<Widget> _buildStatusCard(String status, List<_PengumpulanItem> rows) {
    if (rows.isEmpty) return const [];
    final scoreBoxWidth = math.max(
      40.0,
      MediaQuery.textScalerOf(context).scale(11) * 3.8,
    );

    return [
      Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _KoreksiAiScreen extends StatefulWidget {
  final ClassItem classData;
  final _TugasPengajar tugas;
  final ValueChanged<Map<String, int>> onAccepted;

  const _KoreksiAiScreen({
    required this.classData,
    required this.tugas,
    required this.onAccepted,
  });

  @override
  State<_KoreksiAiScreen> createState() => _KoreksiAiScreenState();
}

class _KoreksiAiScreenState extends State<_KoreksiAiScreen> {
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
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text('Terima Koreksi'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PengumpulanChecklist(
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
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: const Text('Koreksi menggunakan AI'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PengumpulanChecklist(
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

class _PengumpulanChecklist extends StatefulWidget {
  final List<_PengumpulanItem> students;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int maxScore;
  final Map<String, int> scores;

  const _PengumpulanChecklist({
    required this.students,
    required this.selected,
    required this.onChanged,
    this.maxScore = 100,
    this.scores = const {},
  });

  @override
  State<_PengumpulanChecklist> createState() => _PengumpulanChecklistState();
}

class _PengumpulanChecklistState extends State<_PengumpulanChecklist> {
  static const _statuses = ['Diserahkan', 'Ditugaskan', 'Dinilai'];
  static const _filters = ['Semua', 'Diserahkan', 'Ditugaskan', 'Dinilai'];

  String _filter = 'Semua';

  List<_PengumpulanItem> get _visible => widget.students
      .where((p) => _filter == 'Semua' || p.status == _filter)
      .toList();

  bool _allSelected(List<_PengumpulanItem> rows) =>
      rows.isNotEmpty &&
      rows.every((p) => widget.selected.contains(p.studentName));

  void _setMany(List<_PengumpulanItem> rows, bool value) {
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

  List<Widget> _buildGroup(String status, List<_PengumpulanItem> rows) {
    if (rows.isEmpty) return const [];

    return [
      Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      _box(
                        widget.selected.contains(rows[i].studentName),
                        (v) => _setMany([rows[i]], v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rows[i].studentName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        '${(widget.scores[rows[i].studentName] ?? rows[i].score)?.toString() ?? '...'}/${widget.maxScore}',
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
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.secondaryText.withValues(alpha: 0.2),
                  ),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
