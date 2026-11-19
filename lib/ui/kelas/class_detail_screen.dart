import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';
import 'package:path_mobile/ui/kelas/kelas_items.dart';
import 'package:path_mobile/ui/kelas/materi_detail_screen.dart';
import 'package:path_mobile/ui/kelas/tugas_detail_screen.dart';

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
  List<MateriData> _materiList = [];
  List<TugasData> _tugasList = [];

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
            .map((m) => MateriData.fromModel(m, author: author))
            .toList();
      }
      if (tugasModels != null) {
        _tugasList = tugasModels
            .map((t) => TugasData.fromModel(t, author: author))
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
              page: MateriDetailScreen(
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
                page: TugasDetailScreen(
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
