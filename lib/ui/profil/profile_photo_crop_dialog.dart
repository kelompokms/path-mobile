import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

/// Interactive circular profile photo cropper supporting images of any aspect
/// ratio. Users can pan and pinch-zoom so the circular framing matches the
/// rendered avatar across the app.
class ProfilePhotoCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final int maxOutputBytes;

  const ProfilePhotoCropDialog({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.maxOutputBytes,
  });

  @override
  State<ProfilePhotoCropDialog> createState() => _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<ProfilePhotoCropDialog> {
  static const double _viewportSize = 240.0;

  final TransformationController _transformCtrl = TransformationController();
  late final double _scaleToCover;
  late final double _displayWidth;
  late final double _displayHeight;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    final w = widget.imageWidth.toDouble();
    final h = widget.imageHeight.toDouble();
    _scaleToCover = math.max(_viewportSize / w, _viewportSize / h);
    _displayWidth = w * _scaleToCover;
    _displayHeight = h * _scaleToCover;
    final tx = (_viewportSize - _displayWidth) / 2.0;
    final ty = (_viewportSize - _displayHeight) / 2.0;
    _transformCtrl.value = Matrix4.translationValues(tx, ty, 0);
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _clampTransform() {
    final m = _transformCtrl.value.clone();
    final scale = m.getMaxScaleOnAxis().clamp(1.0, 4.0);
    final scaledW = _displayWidth * scale;
    final scaledH = _displayHeight * scale;
    final minTx = math.min(0.0, _viewportSize - scaledW);
    final minTy = math.min(0.0, _viewportSize - scaledH);
    final cur = m.getTranslation();
    final clampedTx = cur.x.clamp(minTx, 0.0).toDouble();
    final clampedTy = cur.y.clamp(minTy, 0.0).toDouble();
    if ((clampedTx - cur.x).abs() > 0.01 ||
        (clampedTy - cur.y).abs() > 0.01 ||
        (scale - m.getMaxScaleOnAxis()).abs() > 0.001) {
      _transformCtrl.value = Matrix4.identity()
        ..translateByDouble(clampedTx, clampedTy, 0.0, 1.0)
        ..scaleByDouble(scale, scale, 1.0, 1.0);
    }
  }

  Future<Uint8List?> _renderCroppedPng({required int targetDim}) async {
    ui.Codec? codec;
    ui.Image? srcImage;
    ui.Image? outImage;
    try {
      _clampTransform();
      codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      srcImage = frame.image;

      final inverted = Matrix4.inverted(_transformCtrl.value);
      final topLeftChild = MatrixUtils.transformPoint(inverted, Offset.zero);
      final bottomRightChild = MatrixUtils.transformPoint(
        inverted,
        const Offset(_viewportSize, _viewportSize),
      );

      final imgW = srcImage.width.toDouble();
      final imgH = srcImage.height.toDouble();
      final rawWidth = (bottomRightChild.dx - topLeftChild.dx) / _scaleToCover;
      final rawHeight = (bottomRightChild.dy - topLeftChild.dy) / _scaleToCover;
      if (rawWidth <= 0 || rawHeight <= 0) return null;

      final srcWidth = rawWidth.clamp(1.0, imgW).toDouble();
      final srcHeight = rawHeight.clamp(1.0, imgH).toDouble();
      final srcLeft = (topLeftChild.dx / _scaleToCover)
          .clamp(0.0, math.max(0.0, imgW - srcWidth))
          .toDouble();
      final srcTop = (topLeftChild.dy / _scaleToCover)
          .clamp(0.0, math.max(0.0, imgH - srcHeight))
          .toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        srcImage,
        ui.Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight),
        ui.Rect.fromLTWH(0, 0, targetDim.toDouble(), targetDim.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );

      final picture = recorder.endRecording();
      outImage = await picture.toImage(targetDim, targetDim);
      picture.dispose();
      final byteData = await outImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      outImage?.dispose();
      srcImage?.dispose();
      codec?.dispose();
    }
  }

  Future<void> _confirmCrop() async {
    if (_processing) return;
    setState(() => _processing = true);
    var cropped = await _renderCroppedPng(targetDim: 512);
    if (cropped != null && cropped.length > widget.maxOutputBytes) {
      cropped = await _renderCroppedPng(targetDim: 256);
    }
    if (!mounted) return;
    Navigator.of(context).pop(cropped);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Atur Area Foto Profil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Geser dan cubit untuk menyesuaikan area lingkaran foto profil.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: SizedBox(
                  width: _viewportSize,
                  height: _viewportSize,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: Colors.black12,
                          child: InteractiveViewer(
                            transformationController: _transformCtrl,
                            constrained: false,
                            minScale: 1.0,
                            maxScale: 4.0,
                            boundaryMargin: EdgeInsets.zero,
                            onInteractionEnd: (_) => _clampTransform(),
                            child: SizedBox(
                              width: _displayWidth,
                              height: _displayHeight,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _CircleCropMaskPainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _processing ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('crop_profile_photo_confirm'),
                    onPressed: _processing ? null : _confirmCrop,
                    child: _processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Gunakan Foto'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleCropMaskPainter extends CustomPainter {
  const _CircleCropMaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2.0;

    final maskPath = Path()
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
