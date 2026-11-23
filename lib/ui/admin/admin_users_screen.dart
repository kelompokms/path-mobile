import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/admin/admin_users_widgets.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

export 'admin_users_widgets.dart';

/// Admin page displaying two separate sections (Daftar Guru and Daftar Murid)
/// in a single scrollable view with search, pull-to-refresh, user creation,
/// and user deactivation.
class AdminUsersScreen extends StatefulWidget {
  final AdminController controller;

  const AdminUsersScreen({super.key, required this.controller});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        widget.controller.loadUsers();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdminUsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      Future<void>.microtask(() {
        if (mounted) {
          widget.controller.loadUsers();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await widget.controller.loadUsers();
    if (!mounted) return;
    final err = widget.controller.usersError;
    if (err != null &&
        (widget.controller.guruList.isNotEmpty ||
            widget.controller.muridList.isNotEmpty)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _openCreateUserDialog() async {
    if (_submitting) return;
    final result = await showDialog<CreateUserDialogResult>(
      context: context,
      builder: (_) => const AdminCreateUserDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _submitting = true);
    final String? err;
    try {
      err = await widget.controller.createUser(
        nama: result.nama,
        email: result.email,
        password: result.password,
        role: result.role,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
    if (!mounted) return;
    final roleLabel = result.role == 'guru' ? 'Guru' : 'Murid';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            err ??
                'User "${result.nama}" berhasil ditambahkan sebagai $roleLabel',
          ),
        ),
      );
  }

  Future<void> _confirmChangeRole(
    AdminPenggunaModel user, {
    required String targetRole,
  }) async {
    final displayName = user.nama.isNotEmpty ? user.nama : 'pengguna ini';
    final targetLabel = targetRole == 'guru' ? 'Guru' : 'Murid';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Ubah Role Pengguna',
      message: 'Apakah Anda yakin ingin menjadikan "$displayName" sebagai $targetLabel?',
    );
    if (!confirmed || !mounted) return;

    final err = await widget.controller.updateUserRole(user.id, targetRole);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Role "$displayName" berhasil diubah menjadi $targetLabel',
          ),
        ),
      );
  }

  Future<void> _confirmDeleteUser(AdminPenggunaModel user) async {
    final displayName = user.nama.isNotEmpty ? user.nama : 'pengguna ini';
    final detail = user.email.isNotEmpty ? ' (${user.email})' : '';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Pengguna',
      message:
          'Apakah Anda yakin ingin menghapus "$displayName"$detail? Akun ini akan dinonaktifkan dan tidak lagi muncul di daftar pengguna aktif.',
    );
    if (!confirmed || !mounted) return;

    final err = await widget.controller.deleteUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(err ?? 'User "$displayName" berhasil dihapus'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Admin', 'Guru & Murid'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final guruList = ctrl.filteredUsers(ctrl.guruList, _query);
          final muridList = ctrl.filteredUsers(ctrl.muridList, _query);
          final hasAnyLoaded =
              ctrl.guruList.isNotEmpty || ctrl.muridList.isNotEmpty;

          if (ctrl.isLoadingUsers && !hasAnyLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ctrl.usersError != null && !hasAnyLoaded) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctrl.usersError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: ctrl.loadUsers,
                      style: AppTheme.softCompactButton,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final hPad = responsiveHorizontalInset(
                constraints.maxWidth,
                maxWidth: 900,
              );

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Daftar Guru dan Murid',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            ElevatedButton.icon(
                              key: const Key('admin_add_user_button'),
                              onPressed: _submitting
                                  ? null
                                  : _openCreateUserDialog,
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                size: 18,
                              ),
                              label: const Text('Tambah User'),
                              style: AppTheme.softCompactButton,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Cari nama, email, atau kelas...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Hapus pencarian',
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.cardRadius,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
                        children: [
                          AdminUserSectionHeader(
                            title: 'Daftar Guru',
                            count: guruList.length,
                            color: AppColors.color1,
                          ),
                          const SizedBox(height: 8),
                          if (guruList.isEmpty)
                            AdminEmptySectionNotice(
                              message: _query.trim().isNotEmpty
                                  ? 'Tidak ada guru yang cocok dengan pencarian'
                                  : 'Belum ada guru terdaftar',
                            )
                          else
                            for (final guru in guruList)
                              AdminUserCard(
                                user: guru,
                                accentColor: AppColors.color1,
                                roleLabel: 'Guru',
                                emptyClassLabel: 'Belum mengampu kelas',
                                classPrefix: 'Mengampu: ',
                                baseUrl: ctrl.baseUrl,
                                roleActionLabel: 'Jadikan Murid',
                                roleActionIcon: Icons.person_outline,
                                onChangeRole: () => _confirmChangeRole(
                                  guru,
                                  targetRole: 'murid',
                                ),
                                onDelete: () => _confirmDeleteUser(guru),
                              ),
                          const SizedBox(height: 20),
                          AdminUserSectionHeader(
                            title: 'Daftar Murid',
                            count: muridList.length,
                            color: const Color(0xFF8E54E9),
                          ),
                          const SizedBox(height: 8),
                          if (muridList.isEmpty)
                            AdminEmptySectionNotice(
                              message: _query.trim().isNotEmpty
                                  ? 'Tidak ada murid yang cocok dengan pencarian'
                                  : 'Belum ada murid terdaftar',
                            )
                          else
                            for (final murid in muridList)
                              AdminUserCard(
                                user: murid,
                                accentColor: const Color(0xFF8E54E9),
                                roleLabel: 'Murid',
                                emptyClassLabel: 'Belum bergabung kelas',
                                classPrefix: 'Kelas: ',
                                baseUrl: ctrl.baseUrl,
                                roleActionLabel: 'Jadikan Guru',
                                roleActionIcon: Icons.school_outlined,
                                onChangeRole: () => _confirmChangeRole(
                                  murid,
                                  targetRole: 'guru',
                                ),
                                onDelete: () => _confirmDeleteUser(murid),
                              ),
                        ],
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
