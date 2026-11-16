import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';

class ProfilScreen extends StatefulWidget {
  final ProfilController controller;

  const ProfilScreen({super.key, required this.controller});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  static const _divider = Divider(
    height: 1,
    thickness: 1,
    color: Colors.black26,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.loadProfil();
  }

  Future<void> _handleLogout() async {
    final yes = await showConfirmDialog(
      context,
      title: 'Keluar',
      message: 'Apakah Anda yakin ingin keluar dari akun?',
    );
    if (!yes || !mounted) return;
    widget.controller.logout();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Profil'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final profil = ctrl.profil;
          final name = (profil?.username.isNotEmpty ?? false)
              ? profil!.username
              : 'Pengguna PATH';
          final email = (profil?.email.isNotEmpty ?? false)
              ? profil!.email
              : '-';
          final phone = (profil?.phone.isNotEmpty ?? false)
              ? profil!.phone
              : '-';

          return LayoutBuilder(
            builder: (context, constraints) {
              final h = responsiveHorizontalInset(
                constraints.maxWidth,
                maxWidth: 720,
              );
              return Column(
                children: [
                  _ProfilHeader(
                    onLogout: _handleLogout,
                    horizontalPadding: h,
                  ),
                  Expanded(
                    child: ctrl.isLoading && profil == null
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: ctrl.loadProfil,
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppColors.color1,
                                        child: Icon(
                                          Icons.person_outline,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'Foto profil',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _divider,
                                _InfoRow(
                                  icon: Icons.manage_accounts_outlined,
                                  label: 'Display name',
                                  value: name,
                                ),
                                _divider,
                                _InfoRow(
                                  icon: Icons.mail_outline,
                                  label: 'Email',
                                  value: email,
                                ),
                                _divider,
                                _InfoRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone',
                                  value: phone,
                                ),
                                _divider,
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton(
                                      onPressed: () => openPage(
                                        context,
                                        breadcrumb: const [
                                          'Profil',
                                          'Edit Profil',
                                        ],
                                        page: _EditProfilScreen(
                                          controller: ctrl,
                                          initialEmail: email == '-'
                                              ? ''
                                              : email,
                                          initialPhone: phone == '-'
                                              ? ''
                                              : phone,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      child: const Text('Edit profil'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => openPage(
                                        context,
                                        breadcrumb: const [
                                          'Profil',
                                          'Ganti Password',
                                        ],
                                        page: _GantiPasswordScreen(
                                          controller: ctrl,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.card,
                                        foregroundColor: AppColors.text,
                                        elevation: 3,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      child: const Text('Ganti password'),
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
        },
      ),
    );
  }
}

class _ProfilHeader extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onLogout;
  final double horizontalPadding;

  const _ProfilHeader({
    this.showBack = false,
    this.onLogout,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final leftPad = showBack
        ? math.max(4.0, horizontalPadding - 12)
        : horizontalPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < ResponsiveBreakpoints.narrow;
        final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
        final stackActions = isNarrow && textScale >= 1.35;

        final buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.text,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 14),
          minimumSize: const Size(0, 32),
          textStyle: const TextStyle(fontSize: 11),
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => openPage(
                context,
                breadcrumb: const ['Profil', 'Bantuan'],
                page: const _BantuanScreen(),
              ),
              style: buttonStyle,
              child: const Text('Bantuan'),
            ),
            if (onLogout != null)
              ElevatedButton(
                onPressed: onLogout,
                style: buttonStyle,
                child: const Text('Keluar'),
              ),
          ],
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(leftPad, 8, horizontalPadding, 8),
          child: stackActions
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.text,
                            ),
                          ),
                        const Expanded(
                          child: Text(
                            'Profil',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.text,
                        ),
                      ),
                    const Expanded(
                      child: Text(
                        'Profil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.text),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _EditProfilScreen extends StatefulWidget {
  final ProfilController controller;
  final String initialEmail;
  final String initialPhone;

  const _EditProfilScreen({
    required this.controller,
    required this.initialEmail,
    required this.initialPhone,
  });

  @override
  State<_EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<_EditProfilScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  bool get _hasChanges =>
      _emailController.text.trim() != widget.initialEmail ||
      _phoneController.text.trim() != widget.initialPhone;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await widget.controller.updateProfil(
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profil disimpan')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 640,
        );
        return Column(
          children: [
            _ProfilHeader(showBack: true, horizontalPadding: h),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                children: [
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Pilih foto profil')),
                        );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.color1,
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Edit foto profil',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.black26),
                  _buildField(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    hint: 'Masukkan email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.black26),
                  _buildField(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    hint: 'Contoh: +628123456789',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.black26),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: (_hasChanges && !_saving) ? _save : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
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
          ],
        );
      },
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.text),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13, color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
              isDense: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _GantiPasswordScreen extends StatefulWidget {
  final ProfilController controller;

  const _GantiPasswordScreen({required this.controller});

  @override
  State<_GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<_GantiPasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  bool _saving = false;

  bool get _canSend =>
      _oldController.text.length >= 8 &&
      _newController.text.length >= 8 &&
      !_saving;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final err = await widget.controller.resetPassword(
      _oldController.text,
      _newController.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Kata sandi diperbarui')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 520,
        );
        final topPad = constraints.maxHeight < 520 ? 16.0 : 32.0;

        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Ganti Password'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(h, topPad, h, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.lock_open_outlined,
                        size: 28,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Ganti Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Masukkan kata sandi lama dan kata sandi baru minimal 8 karakter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Password Lama',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _oldController,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Masukkan password lama',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password Baru',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newController,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Minimal 8 karakter',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canSend ? _submit : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan Password'),
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

class _BantuanScreen extends StatelessWidget {
  const _BantuanScreen();

  static const _titles = ['Panduan AI', 'Etika Penggunaan AI', 'Kontak Kami'];
  static const _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
      'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim '
      'veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
      'commodo consequat.';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 720,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Bantuan'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                children: [
                  for (final title in _titles) ...[
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: AppColors.text,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      children: const [
                        Text(
                          _lorem,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
