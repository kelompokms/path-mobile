import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/user_avatar.dart';
import 'package:path_mobile/utils/api_error_helper.dart';

class AdminUserSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const AdminUserSectionHeader({
    super.key,
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
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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

class AdminEmptySectionNotice extends StatelessWidget {
  final String message;

  const AdminEmptySectionNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: AppTheme.cardDecoration(color: AppColors.background),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
    );
  }
}

class AdminUserCard extends StatelessWidget {
  final AdminPenggunaModel user;
  final Color accentColor;
  final String roleLabel;
  final String emptyClassLabel;
  final String classPrefix;
  final String? baseUrl;
  final String? roleActionLabel;
  final IconData? roleActionIcon;
  final VoidCallback? onChangeRole;
  final VoidCallback? onDelete;

  const AdminUserCard({
    super.key,
    required this.user,
    required this.accentColor,
    required this.roleLabel,
    required this.emptyClassLabel,
    required this.classPrefix,
    this.baseUrl,
    this.roleActionLabel,
    this.roleActionIcon,
    this.onChangeRole,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final classSummary = user.kelas.isEmpty
        ? emptyClassLabel
        : '$classPrefix${user.kelas.join(', ')}';
    final hasMenu = onChangeRole != null || onDelete != null;

    return Card(
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: AppTheme.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              picturePath: user.profilePicture,
              baseUrl: baseUrl,
              radius: 20,
              backgroundColor: accentColor,
              fallback: const Icon(
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
                  Wrap(
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
            if (hasMenu) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                key: Key('admin_user_menu_${user.id}'),
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.more_vert, color: AppColors.text),
                tooltip: 'Opsi pengguna',
                elevation: AppTheme.cardElevation,
                shadowColor: AppTheme.shadowColor,
                color: AppColors.background,
                surfaceTintColor: Colors.transparent,
                shape: AppTheme.cardShape(),
                onSelected: (value) {
                  if (value == 'change_role') {
                    onChangeRole?.call();
                  } else if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (_) => [
                  if (onChangeRole != null && roleActionLabel != null)
                    PopupMenuItem<String>(
                      value: 'change_role',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            roleActionIcon ?? Icons.swap_horiz,
                            color: AppColors.color1,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            roleActionLabel!,
                            style: const TextStyle(color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hapus Pengguna',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CreateUserDialogResult {
  final String nama;
  final String email;
  final String password;
  final String role;

  const CreateUserDialogResult({
    required this.nama,
    required this.email,
    required this.password,
    required this.role,
  });
}

class AdminCreateUserDialog extends StatefulWidget {
  const AdminCreateUserDialog({super.key});

  @override
  State<AdminCreateUserDialog> createState() => _AdminCreateUserDialogState();
}

class _AdminCreateUserDialogState extends State<AdminCreateUserDialog> {
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'murid';
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final nama = _namaCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (nama.isEmpty) {
      setState(() => _errorText = 'Nama lengkap wajib diisi');
      return;
    }
    if (!isValidEmailAddress(email)) {
      setState(() => _errorText = 'Format email tidak valid');
      return;
    }
    if (password.trim().isEmpty || password.length < 8) {
      setState(() => _errorText = 'Password minimal 8 karakter');
      return;
    }
    if (utf8.encode(password).length > 72) {
      setState(() => _errorText = 'Password maksimal 72 byte');
      return;
    }

    Navigator.pop(
      context,
      CreateUserDialogResult(
        nama: nama,
        email: email,
        password: password,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: AppTheme.cardShape(),
      title: const Text(
        'Tambah User Baru',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('admin_create_user_nama'),
                controller: _namaCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap *',
                  hintText: 'Contoh: Budi Santoso',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_create_user_email'),
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Email *',
                  hintText: 'Contoh: budi@sekolah.sch.id',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_create_user_password'),
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Minimal 8 karakter',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('admin_create_user_role'),
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'murid', child: Text('Murid')),
                  DropdownMenuItem(value: 'guru', child: Text('Guru')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedRole = value);
                },
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('admin_create_user_submit'),
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.color1),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
