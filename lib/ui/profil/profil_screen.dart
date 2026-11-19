import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
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
              final canPop =
                  (GoRouter.maybeOf(context)?.canPop() ?? false) ||
                  Navigator.of(context).canPop();
              return Column(
                children: [
                  ProfilHeader(
                    showBack: canPop,
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
