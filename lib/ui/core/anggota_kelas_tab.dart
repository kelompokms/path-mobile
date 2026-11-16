import 'package:flutter/material.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kelas/kelas_controller.dart';

typedef AnggotaLoader =
    Future<(List<AnggotaKelasModel>?, String?)> Function();

class AnggotaKelasTab extends StatefulWidget {
  final String kodeKelas;
  final AnggotaLoader? loadMembers;
  final double horizontalPadding;

  const AnggotaKelasTab({
    super.key,
    required this.kodeKelas,
    this.loadMembers,
    required this.horizontalPadding,
  });

  @override
  State<AnggotaKelasTab> createState() => _AnggotaKelasTabState();
}

class _AnggotaKelasTabState extends State<AnggotaKelasTab> {
  bool _isLoading = false;
  String? _error;
  List<AnggotaKelasModel> _members = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnggotaKelasTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kodeKelas != widget.kodeKelas) {
      _load();
    }
  }

  Future<void> _load() async {
    final loader = widget.loadMembers;
    if (loader == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final (members, err) = await loader();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _error = err;
      if (members != null) {
        _members = members;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: AppTheme.softCompactButton,
                onPressed: _load,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final teachers = _members.where((m) => m.isGuru).toList();
    final students = _members.where((m) => !m.isGuru).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding,
          12,
          widget.horizontalPadding,
          24,
        ),
        children: [
          _AnggotaSectionCard(
            title: 'Guru',
            emptyMessage: 'Belum ada guru',
            members: teachers,
            isTeacherSection: true,
          ),
          const SizedBox(height: 12),
          _AnggotaSectionCard(
            title: 'Murid',
            emptyMessage: 'Belum ada murid',
            members: students,
            isTeacherSection: false,
          ),
        ],
      ),
    );
  }
}

class _AnggotaSectionCard extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<AnggotaKelasModel> members;
  final bool isTeacherSection;

  const _AnggotaSectionCard({
    required this.title,
    required this.emptyMessage,
    required this.members,
    required this.isTeacherSection,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isTeacherSection
                          ? AppColors.color1
                          : AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '${members.length} Orang',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            const Divider(height: 16, thickness: 1, color: AppColors.text),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              )
            else
              for (var i = 0; i < members.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isTeacherSection
                            ? AppColors.color1
                            : AppColors.color2.withValues(alpha: 0.3),
                        child: Text(
                          _initials(members[i].nama),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isTeacherSection
                                ? Colors.white
                                : AppColors.color3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              members[i].nama.isNotEmpty
                                  ? members[i].nama
                                  : 'Pengguna #${members[i].penggunaId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            if (members[i].email.isNotEmpty)
                              Text(
                                members[i].email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isTeacherSection
                              ? AppColors.color1.withValues(alpha: 0.12)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isTeacherSection ? 'Guru' : 'Murid',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isTeacherSection
                                ? AppColors.color3
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < members.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black12,
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class AnggotaKelasScreen extends StatefulWidget {
  final String kodeKelas;
  final KelasController controller;

  const AnggotaKelasScreen({
    super.key,
    required this.kodeKelas,
    required this.controller,
  });

  @override
  State<AnggotaKelasScreen> createState() => _AnggotaKelasScreenState();
}

class _AnggotaKelasScreenState extends State<AnggotaKelasScreen> {
  String? _className;

  @override
  void initState() {
    super.initState();
    _loadClassInfo();
  }

  Future<void> _loadClassInfo() async {
    final kelas = await widget.controller.getKelas(widget.kodeKelas);
    if (!mounted || kelas == null) return;
    setState(() => _className = kelas.nama);
  }

  @override
  Widget build(BuildContext context) {
    final title = _className ?? 'Anggota Kelas';
    return PageFrame(
      breadcrumb: ['Kelas', _className ?? widget.kodeKelas, 'Anggota'],
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
                child: BackTitleRow(title: title),
              ),
              Expanded(
                child: AnggotaKelasTab(
                  kodeKelas: widget.kodeKelas,
                  loadMembers: () =>
                      widget.controller.getListAnggota(widget.kodeKelas),
                  horizontalPadding: h,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
