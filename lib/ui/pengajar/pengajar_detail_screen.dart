import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/pengajar/buat_materi_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/ui/pengajar/pengajar_items.dart';
import 'package:path_mobile/ui/pengajar/pengajar_materi_detail_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_tugas_detail_screen.dart';
import 'package:path_mobile/ui/pengajar/pengajar_widgets.dart';
import 'package:path_mobile/ui/pengajar/tugas_form_screen.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class PengajarDetailScreen extends StatefulWidget {
  final ClassItem classData;
  final PengajarController? controller;
  final String breadcrumbRoot;
  final int initialTab;

  const PengajarDetailScreen({
    super.key,
    required this.classData,
    this.controller,
    this.breadcrumbRoot = 'Pengajar',
    this.initialTab = 0,
  });

  @override
  State<PengajarDetailScreen> createState() => _PengajarDetailScreenState();
}

class _PengajarDetailScreenState extends State<PengajarDetailScreen> {
  late ClassItem _class;
  bool get _isGuru => _class.isGuru;

  bool _isLoading = false;
  List<MateriPengajar> _materiList = [];
  List<TugasPengajar> _tugasList = [];

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
        _materiList = materiModels.map(MateriPengajar.fromModel).toList();
      }
      if (tugasModels != null) {
        _tugasList = tugasModels.map(TugasPengajar.fromModel).toList();
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

  Future<void> _handleMateriCreated(MateriPengajar materi) async {
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
        final createdMateri = MateriPengajar.fromModel(created)
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

  Future<bool> _handleTugasCreated(TugasPengajar tugas) async {
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
          ..postedAt = created.dibuat
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
    TugasPengajar target,
    TugasPengajar draft,
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

  Future<bool> _editMateri(MateriPengajar m) async {
    if (!_isGuru) return false;
    final result =
        await showDialog<
          ({String title, String description, List<LampiranItem> lampiran})
        >(
          context: context,
          builder: (_) => EditPostinganDialog(
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
                          : () =>
                                widget.controller!.getListAnggota(_class.code),
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
                  ClassCodeCard(classData: _class),
                  ElevatedButton.icon(
                    style: AppTheme.softCompactButton,
                    onPressed: () => openPage(
                      context,
                      breadcrumb: [
                        widget.breadcrumbRoot,
                        _class.title,
                        'Buat Materi',
                      ],
                      page: BuatMateriScreen(
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
                          page: PengajarMateriDetailScreen(
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
                  page: TugasFormScreen(
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
                          page: PengajarTugasDetailScreen(
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
                                page: TugasFormScreen(
                                  classData: _class,
                                  existing: t,
                                  controller: widget.controller,
                                  onSaved: (draft) =>
                                      _handleTugasEdited(t, draft),
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
