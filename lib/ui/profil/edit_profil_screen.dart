import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/core/user_avatar.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';
import 'package:path_mobile/ui/profil/profil_widgets.dart';
import 'package:path_mobile/ui/profil/profile_photo_crop_dialog.dart';
import 'package:path_mobile/utils/api_error_helper.dart';

/// Maximum allowed profile photo size (2 MB).
const int maxProfilePhotoBytes = 2 * 1024 * 1024;

/// Decodes an image file (JPG, PNG, WEBP, GIF, BMP, etc.), center-crops it to a
/// 1:1 square (up to [maxDimension]px), and encodes it as PNG so it matches
/// circular profile avatar framing reliably.
Future<Uint8List?> normalizeProfilePhotoToSquarePng(
  Uint8List rawBytes, {
  int maxDimension = 512,
}) async {
  ui.Codec? codec;
  ui.Image? srcImage;
  ui.Image? outImage;
  try {
    codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    srcImage = frame.image;
    final srcW = srcImage.width;
    final srcH = srcImage.height;
    if (srcW <= 0 || srcH <= 0) return null;

    final cropSize = srcW < srcH ? srcW : srcH;
    final srcLeft = (srcW - cropSize) / 2.0;
    final srcTop = (srcH - cropSize) / 2.0;
    final targetDim = cropSize < maxDimension ? cropSize : maxDimension;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(
      srcImage,
      ui.Rect.fromLTWH(
        srcLeft,
        srcTop,
        cropSize.toDouble(),
        cropSize.toDouble(),
      ),
      ui.Rect.fromLTWH(0, 0, targetDim.toDouble(), targetDim.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    outImage = await picture.toImage(targetDim, targetDim);
    picture.dispose();
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    outImage?.dispose();
    srcImage?.dispose();
    codec?.dispose();
  }
}

class EditProfilScreen extends StatefulWidget {
  final ProfilController controller;
  final String initialEmail;
  final String initialPhone;
  final Future<Uint8List?> Function()? onPickPhotoBytes;

  const EditProfilScreen({
    super.key,
    required this.controller,
    required this.initialEmail,
    required this.initialPhone,
    this.onPickPhotoBytes,
  });

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  Uint8List? _pendingPhotoBytes;
  bool _saving = false;
  bool _pickingPhoto = false;

  bool get _isBusy => _saving || _pickingPhoto;

  bool get _hasChanges =>
      _phoneController.text.trim() != widget.initialPhone ||
      _pendingPhotoBytes != null;

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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<({int width, int height})?> _decodeImageSize(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? img;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      img = frame.image;
      if (img.width <= 0 || img.height <= 0) return null;
      return (width: img.width, height: img.height);
    } catch (_) {
      return null;
    } finally {
      img?.dispose();
      codec?.dispose();
    }
  }

  Future<void> _pickAndStagePhoto() async {
    if (_isBusy) return;
    setState(() => _pickingPhoto = true);
    try {
      Uint8List? bytes;
      if (widget.onPickPhotoBytes != null) {
        bytes = await widget.onPickPhotoBytes!();
      } else {
        final file = await FilePicker.pickFile(type: FileType.image);
        if (file == null || !mounted) return;
        final knownSize = file.lengthSync();
        if (knownSize != null && knownSize > maxProfilePhotoBytes) {
          _showSnack('Ukuran foto profil terlalu besar (maks. 2 MB)');
          return;
        }
        bytes = await file.readAsBytes();
      }
      if (bytes == null || !mounted) return;
      if (bytes.isEmpty) {
        _showSnack('File foto profil kosong');
        return;
      }
      if (bytes.length > maxProfilePhotoBytes) {
        _showSnack('Ukuran foto profil terlalu besar (maks. 2 MB)');
        return;
      }

      final dims = await _decodeImageSize(bytes);
      if (!mounted) return;
      if (dims == null) {
        _showSnack(
          'Format file tidak didukung. Pilih file gambar (JPG, PNG, WEBP, dll.)',
        );
        return;
      }

      setState(() => _pickingPhoto = false);
      final cropped = await showDialog<Uint8List?>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProfilePhotoCropDialog(
          imageBytes: bytes!,
          imageWidth: dims.width,
          imageHeight: dims.height,
          maxOutputBytes: maxProfilePhotoBytes,
        ),
      );
      if (!mounted || cropped == null || cropped.isEmpty) return;

      if (cropped.length > maxProfilePhotoBytes) {
        _showSnack('Ukuran foto profil terlalu besar (maks. 2 MB)');
        return;
      }

      setState(() {
        _pendingPhotoBytes = cropped;
      });
    } catch (e) {
      _showSnack('Gagal memilih foto profil: $e');
    } finally {
      if (mounted && _pickingPhoto) {
        setState(() => _pickingPhoto = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_hasChanges || _isBusy) return;
    final phone = _phoneController.text.trim();
    final phoneChanged = phone != widget.initialPhone;
    final photoChanged = _pendingPhotoBytes != null;

    if (phoneChanged && phone.isEmpty) {
      _showSnack('Nomor HP tidak boleh kosong');
      return;
    }
    if (phoneChanged && !isValidE164Phone(phone)) {
      _showSnack(
        'Format nomor HP harus standar internasional (contoh: +628123456789)',
      );
      return;
    }

    setState(() => _saving = true);

    if (photoChanged) {
      final multipart = http.MultipartFile.fromBytes(
        'profile_picture',
        _pendingPhotoBytes!,
        filename: 'profile_picture.png',
      );
      final photoErr = await widget.controller.updateProfilePicture(multipart);
      if (!mounted) return;
      if (photoErr != null) {
        setState(() => _saving = false);
        _showSnack(photoErr);
        return;
      }
      _pendingPhotoBytes = null;
    }

    if (phoneChanged) {
      final phoneErr = await widget.controller.updateProfil(phone: phone);
      if (!mounted) return;
      if (phoneErr != null) {
        setState(() => _saving = false);
        _showSnack(phoneErr);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profil disimpan')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final h = responsiveHorizontalInset(
              constraints.maxWidth,
              maxWidth: 640,
            );
            return Column(
              children: [
                ProfilHeader(
                  showBack: true,
                  horizontalPadding: h,
                  controller: widget.controller,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                    children: [
                      InkWell(
                        key: const Key('edit_profile_photo_button'),
                        onTap: _isBusy ? null : _pickAndStagePhoto,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              _pickingPhoto
                                  ? const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : UserAvatar(
                                      picturePath: widget
                                          .controller
                                          .profil
                                          ?.profilePicture,
                                      baseUrl: widget.controller.baseUrl,
                                      previewBytes: _pendingPhotoBytes,
                                      radius: 22,
                                      backgroundColor: AppColors.color1,
                                      fallback: const Icon(
                                        Icons.person_outline,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickingPhoto
                                          ? 'Memuat gambar...'
                                          : (_pendingPhotoBytes != null
                                                ? 'Foto baru dipilih (tekan Simpan)'
                                                : 'Edit foto profil'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _pendingPhotoBytes != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _pendingPhotoBytes != null
                                            ? AppColors.color1
                                            : AppColors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Rasio bebas (crop lingkaran), maks. 2 MB',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_pendingPhotoBytes != null && !_isBusy)
                                IconButton(
                                  tooltip: 'Batalkan foto baru',
                                  onPressed: () => setState(
                                    () => _pendingPhotoBytes = null,
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black26,
                      ),
                      _buildField(
                        icon: Icons.mail_outline,
                        label: 'Email',
                        hint: 'Email akun',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: true,
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black26,
                      ),
                      _buildField(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        hint: 'Contoh: +628123456789',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          key: const Key('edit_profil_save_button'),
                          onPressed: (_hasChanges && !_isBusy) ? _save : null,
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
      },
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool readOnly = false,
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
              if (readOnly) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: AppColors.secondaryText,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: !readOnly && !_isBusy,
            readOnly: readOnly,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.done,
            onChanged: readOnly ? null : (_) => setState(() {}),
            onSubmitted: readOnly ? null : (_) => _save(),
            style: TextStyle(
              fontSize: 13,
              color: readOnly ? AppColors.secondaryText : AppColors.text,
            ),
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
