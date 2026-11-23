import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/utils/http_client.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

/// Displays a circular user profile photo from [previewBytes] or a backend
/// [picturePath] (resolved against [baseUrl]), falling back cleanly to
/// [fallback] when empty or unavailable.
class UserAvatar extends StatelessWidget {
  final String? picturePath;
  final String? baseUrl;
  final Uint8List? previewBytes;
  final double radius;
  final Color backgroundColor;
  final Widget fallback;

  const UserAvatar({
    super.key,
    this.picturePath,
    this.baseUrl,
    this.previewBytes,
    this.radius = 20,
    this.backgroundColor = AppColors.color1,
    required this.fallback,
  });

  Uri? _resolveUri() {
    final raw = picturePath?.trim() ?? '';
    if (raw.isEmpty) return null;
    final effectiveBase = (baseUrl != null && baseUrl!.trim().isNotEmpty)
        ? baseUrl!.trim()
        : HttpClient.defaultBaseUrl;
    return resolveLampiranUri(
      LampiranItem(name: 'profile', detail: 'IMG', url: raw),
      baseUrl: effectiveBase,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        foregroundImage: MemoryImage(previewBytes!),
        onForegroundImageError: (_, _) {},
        child: fallback,
      );
    }

    final uri = _resolveUri();
    if (uri != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        foregroundImage: NetworkImage(uri.toString()),
        onForegroundImageError: (_, _) {},
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: fallback,
    );
  }
}
