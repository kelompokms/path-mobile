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
  String? _errorMessage;
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final results = await Future.wait([
      ctrl.getListMateri(widget.classData.code),
      ctrl.getListTugas(widget.classData.code),
    ]);

    if (!mounted) return;

    final (materiModels, materiErr) = results[0];
    final (tugasModels, tugasErr) = results[1];
    final author = widget.classData.teacher ?? 'Pengajar';
    final firstError = materiErr ?? tugasErr;

    setState(() {
      _isLoading = false;
      _errorMessage = firstError;
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
                    _isLoading && _materiList.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _buildMateriTab(h),
                    _isLoading && _tugasList.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _buildTugasTab(h),
                    AnggotaKelasTab(
                      kodeKelas: widget.classData.code,
                      baseUrl: widget.controller?.baseUrl,
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

  Widget _buildEmptyRefreshable(String emptyLabel) {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emptyLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadPosts,
                        style: AppTheme.softCompactButton,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMateriTab(double horizontalPadding) {
    if (_materiList.isEmpty) {
      return _buildEmptyRefreshable('Belum ada materi');
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
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
                controller: widget.controller,
                jenjang: widget.classData.grade,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTugasTab(double horizontalPadding) {
    if (_tugasList.isEmpty) {
      return _buildEmptyRefreshable('Belum ada tugas');
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
