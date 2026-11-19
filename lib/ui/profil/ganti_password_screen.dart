import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';

class GantiPasswordScreen extends StatefulWidget {
  final ProfilController controller;

  const GantiPasswordScreen({super.key, required this.controller});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
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
    if (!_canSend) return;
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
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
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
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
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
