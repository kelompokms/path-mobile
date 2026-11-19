import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

class PathLogo extends StatelessWidget {
  final double width;
  final double height;

  const PathLogo({super.key, this.width = 104, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: AppTheme.cardDecoration(
        color: Colors.white,
        radius: AppTheme.dialogRadius,
      ),
      child: Image.asset('assets/images/path_logo.png', fit: BoxFit.contain),
    );
  }
}
