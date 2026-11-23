import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';

class AdminKelasDetailScreen extends StatefulWidget {
  final AdminKelasModel kelas;
  final KelasRepository? kelasRepository;
  final Future<AdminKelasModel?> Function(AdminKelasModel kelas)?
  onChangePengampu;

  const AdminKelasDetailScreen({
    super.key,
    required this.kelas,
    this.kelasRepository,
    this.onChangePengampu,
  });

  @override
  State<AdminKelasDetailScreen> createState() => _AdminKelasDetailScreenState();
}

class _AdminKelasDetailScreenState extends State<AdminKelasDetailScreen> {
  late AdminKelasModel _kelas = widget.kelas;
  int _tabIndex = 0;
  bool _loadingPosts = false;
  String? _postsError;
  List<PostinganModel> _materi = const [];
  List<PostinganModel> _tugas = const [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final repo = widget.kelasRepository;
    if (repo == null) return;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });

    final results = await Future.wait([
      repo.getListPostingan(
        _kelas.kodeKelas,
        tipe: PostinganModel.tipeMateri,
      ),
      repo.getListPostingan(
        _kelas.kodeKelas,
        tipe: PostinganModel.tipeTugas,
      ),
    ]);
    if (!mounted) return;

    final (materiList, materiErr) = results[0];
    final (tugasList, tugasErr) = results[1];
    final firstError = materiErr ?? tugasErr;
    setState(() {
      _loadingPosts = false;
      _postsError = firstError;
      if (materiList != null) _materi = materiList;
      if (tugasList != null) _tugas = tugasList;
    });
    if (firstError != null && (_materi.isNotEmpty || _tugas.isNotEmpty)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(firstError)));
    }
  }

  Future<void> _editPengampu() async {
    final handler = widget.onChangePengampu;
    if (handler == null) return;
    final updated = await handler(_kelas);
    if (updated != null && mounted) {
      setState(() => _kelas = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kelas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackTitleRow(title: k.nama),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${k.gradeLabel} • Tahun Ajaran ${k.tahunAjaran} • Kode: ${k.kodeKelas}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    k.namaPengampu.isNotEmpty
                        ? 'Pengampu: ${k.namaPengampu}'
                        : 'Pengampu: Belum ditentukan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (widget.onChangePengampu != null)
                    TextButton.icon(
                      key: const Key('admin_detail_ubah_pengampu_button'),
                      onPressed: _editPengampu,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Ubah Pengampu'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              if (k.deskripsi.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  k.deskripsi,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Postingan'),
                selected: _tabIndex == 0,
                onSelected: (_) => setState(() => _tabIndex = 0),
              ),
              ChoiceChip(
                label: const Text('Anggota'),
                selected: _tabIndex == 1,
                onSelected: (_) => setState(() => _tabIndex = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _tabIndex == 1
              ? AnggotaKelasTab(
                  key: ValueKey('anggota_${k.kodeKelas}_${k.pengampu}'),
                  kodeKelas: k.kodeKelas,
                  horizontalPadding: 16,
                  baseUrl: widget.kelasRepository?.baseUrl,
                  currentUserId: widget.kelasRepository?.currentUserId,
                  isAdmin: true,
                  loadMembers: widget.kelasRepository != null
                      ? () => widget.kelasRepository!.getListAnggota(
                          k.kodeKelas,
                        )
                      : null,
                  onDemoteToMurid: widget.kelasRepository != null
                      ? (member) => widget.kelasRepository!.demoteToMurid(
                          k.kodeKelas,
                          member.penggunaId,
                        )
                      : null,
                )
              : _buildPostsTab(),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    if (_loadingPosts && _materi.isEmpty && _tugas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_postsError != null && _materi.isEmpty && _tugas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _postsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPosts,
                style: AppTheme.softCompactButton,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final combined = <AdminPostEntry>[
      for (final m in _materi) AdminPostEntry(post: m, isTugas: false),
      for (final t in _tugas) AdminPostEntry(post: t, isTugas: true),
    ]..sort((a, b) => b.post.dibuat.compareTo(a.post.dibuat));

    if (combined.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPosts,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Text(
                  'Belum ada postingan di kelas ini',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: combined.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final entry = combined[i];
          return PostCard(
            icon: entry.isTugas
                ? Icons.assignment_outlined
                : Icons.menu_book_outlined,
            label: entry.isTugas ? 'Tugas' : 'Materi',
            title: entry.post.judul,
            date: entry.post.dibuat,
            onTap: () => openPage(
              context,
              breadcrumb: ['Admin', 'Kelas', _kelas.nama, entry.post.judul],
              page: AdminPostDetailScreen(
                post: entry.post,
                isTugas: entry.isTugas,
                baseUrl: widget.kelasRepository?.baseUrl,
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminPostEntry {
  final PostinganModel post;
  final bool isTugas;

  const AdminPostEntry({required this.post, required this.isTugas});
}

class AdminPostDetailScreen extends StatelessWidget {
  final PostinganModel post;
  final bool isTugas;
  final String? baseUrl;

  const AdminPostDetailScreen({
    super.key,
    required this.post,
    required this.isTugas,
    this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final items = post.lampiranItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        BackTitleRow(title: post.judul),
        Text(
          '${isTugas ? 'Tugas' : 'Materi'} • ${formatTanggal(post.dibuat)}',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        if (post.deskripsi.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            post.deskripsi,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ],
        if (items.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Lampiran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            FileCard.fromItem(item, baseUrl: baseUrl),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
