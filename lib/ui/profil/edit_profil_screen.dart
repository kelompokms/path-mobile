import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';
import 'package:path_mobile/ui/profil/profil_widgets.dart';

class EditProfilScreen extends StatefulWidget {
  final ProfilController controller;
  final String initialEmail;
  final String initialPhone;

  const EditProfilScreen({
    super.key,
    required this.controller,
    required this.initialEmail,
    required this.initialPhone,
  });

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
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
    if (!_hasChanges || _saving) return;
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
            ProfilHeader(showBack: true, horizontalPadding: h),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
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
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
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
