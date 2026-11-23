import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/core/user_avatar.dart';
import 'package:path_mobile/ui/profil/edit_profil_screen.dart';
import 'package:path_mobile/ui/profil/ganti_password_screen.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';
import 'package:path_mobile/ui/profil/profil_widgets.dart';

export 'bantuan_screen.dart';
export 'edit_profil_screen.dart';
export 'ganti_password_screen.dart';
export 'profil_widgets.dart';

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
    Future<void>.microtask(() {
      if (mounted) {
        widget.controller.loadProfil();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfilScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      Future<void>.microtask(() {
        if (mounted) {
          widget.controller.loadProfil();
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    final yes = await showConfirmDialog(
      context,
      title: 'Keluar',
      message: 'Apakah Anda yakin ingin keluar dari akun?',
    );
    if (!yes || !mounted) return;
    widget.controller.logout();
    await widget.controller.flushPersistence();
    if (!mounted) return;
    context.go('/login');
  }

  Widget _buildAvatar(ProfilController ctrl) {
    return UserAvatar(
      picturePath: ctrl.profil?.profilePicture,
      baseUrl: ctrl.baseUrl,
      radius: 22,
      backgroundColor: AppColors.color1,
      fallback: const Icon(Icons.person_outline, color: Colors.white, size: 22),
    );
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
              final canPop =
                  (GoRouter.maybeOf(context)?.canPop() ?? false) ||
                  Navigator.of(context).canPop();
              return Column(
                children: [
                  ProfilHeader(
                    showBack: canPop,
                    onLogout: _handleLogout,
                    horizontalPadding: h,
                    controller: ctrl,
                  ),
                  Expanded(
                    child: ctrl.isLoading && profil == null
                        ? const Center(child: CircularProgressIndicator())
                        : ctrl.errorMessage != null && profil == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctrl.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: ctrl.loadProfil,
                                    style: AppTheme.softCompactButton,
                                    child: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: ctrl.loadProfil,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      _buildAvatar(ctrl),
                                      const SizedBox(width: 12),
                                      const Flexible(
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
                                ProfilInfoRow(
                                  icon: Icons.manage_accounts_outlined,
                                  label: 'Display name',
                                  value: name,
                                ),
                                _divider,
                                ProfilInfoRow(
                                  icon: Icons.mail_outline,
                                  label: 'Email',
                                  value: email,
                                ),
                                _divider,
                                ProfilInfoRow(
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
                                        page: EditProfilScreen(
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
                                            AppTheme.cardRadius,
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
                                        page: GantiPasswordScreen(
                                          controller: ctrl,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.card,
                                        foregroundColor: AppColors.text,
                                        elevation: AppTheme.cardElevation,
                                        shadowColor: AppTheme.shadowColor,
                                        side: AppTheme.thinBorderSide,
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.cardRadius,
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
