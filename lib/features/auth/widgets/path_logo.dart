
import 'package:flutter/material.dart';

class PathLogo extends StatelessWidget {
  final double width;
  final double height;

  const PathLogo({
    super.key,
    this.width = 104,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/path_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
