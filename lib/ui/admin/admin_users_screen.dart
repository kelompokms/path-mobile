import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/admin/admin_users_widgets.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

export 'admin_users_widgets.dart';

/// Admin page displaying two separate sections (Daftar Guru and Daftar Murid)
/// in a single scrollable view with search, pull-to-refresh, and role switching.
class AdminUsersScreen extends StatefulWidget {
  final AdminController controller;

  const AdminUsersScreen({super.key, required this.controller});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _changeUserRole(
    AdminPenggunaModel user,
    String newRole,
  ) async {
    final targetLabel = newRole == 'guru' ? 'Guru' : 'Murid';
    final displayName = user.nama.isNotEmpty ? user.nama : 'pengguna ini';
    final yes = await showConfirmDialog(
      context,
      title: 'Ubah Role Pengguna',
      message: 'Ubah role universal $displayName menjadi $targetLabel?',
    );
    if (!yes || !mounted) return;

    final err = await widget.controller.updateUserRole(user.id, newRole);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            err ??
                '${user.nama.isNotEmpty ? user.nama : "Pengguna"} kini menjadi $targetLabel',
          ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar Guru dan Murid',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
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
                      onRefresh: ctrl.loadUsers,
                      child: ListView(
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
                                actionLabel: 'Jadikan Murid',
                                onToggleRole: () =>
                                    _changeUserRole(guru, 'murid'),
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
                                actionLabel: 'Jadikan Guru',
                                onToggleRole: () =>
                                    _changeUserRole(murid, 'guru'),
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
