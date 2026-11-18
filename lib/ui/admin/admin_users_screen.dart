import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

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
                              borderRadius: BorderRadius.circular(10),
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
                          _SectionHeader(
                            title: 'Daftar Guru',
                            count: guruList.length,
                            color: AppColors.color1,
                          ),
                          const SizedBox(height: 8),
                          if (guruList.isEmpty)
                            _EmptySectionNotice(
                              message: _query.trim().isNotEmpty
                                  ? 'Tidak ada guru yang cocok dengan pencarian'
                                  : 'Belum ada guru terdaftar',
                            )
                          else
                            for (final guru in guruList)
                              _UserCard(
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
                          _SectionHeader(
                            title: 'Daftar Murid',
                            count: muridList.length,
                            color: const Color(0xFF8E54E9),
                          ),
                          const SizedBox(height: 8),
                          if (muridList.isEmpty)
                            _EmptySectionNotice(
                              message: _query.trim().isNotEmpty
                                  ? 'Tidak ada murid yang cocok dengan pencarian'
                                  : 'Belum ada murid terdaftar',
                            )
                          else
                            for (final murid in muridList)
                              _UserCard(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySectionNotice extends StatelessWidget {
  final String message;

  const _EmptySectionNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminPenggunaModel user;
  final Color accentColor;
  final String roleLabel;
  final String emptyClassLabel;
  final String classPrefix;
  final String actionLabel;
  final VoidCallback onToggleRole;

  const _UserCard({
    required this.user,
    required this.accentColor,
    required this.roleLabel,
    required this.emptyClassLabel,
    required this.classPrefix,
    required this.actionLabel,
    required this.onToggleRole,
  });

  @override
  Widget build(BuildContext context) {
    final classSummary = user.kelas.isEmpty
        ? emptyClassLabel
        : '$classPrefix${user.kelas.join(', ')}';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accentColor,
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              user.nama.isNotEmpty ? user.nama : 'Tanpa Nama',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<int>(
                        key: Key('user_role_menu_${user.id}'),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.text,
                        ),
                        tooltip: 'Ubah role',
                        color: AppColors.background,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (_) => onToggleRole(),
                        itemBuilder: (_) => [
                          PopupMenuItem<int>(
                            value: 0,
                            child: Text(actionLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    classSummary,
                    style: const TextStyle(fontSize: 11, color: AppColors.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
