import 'package:flutter/material.dart';
import '../models/class_model.dart';

class ClassCard extends StatelessWidget {
  final ClassModel data;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  const ClassCard({
    super.key,
    required this.data,
    this.onTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Bagian gambar sampul
            SizedBox(
              height: 70,
              width: double.infinity,
              child: _buildImage(),
            ),
            
            // Bagian teks + ikon titik tiga
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(data.grade, style: textTheme.bodySmall),
                        // Hanya tampil kalau teacher tidak kosong
                        if (data.teacher != null) ...[
                          const SizedBox(height: 2),
                          Text(data.teacher!, style: textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onMenuTap,
                    child: const Icon(Icons.more_vert, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final path = data.imagePath;
    if (path == null) return _placeholder();
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(), // kalau path salah
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE3F2FD),
      child: const Icon(Icons.image_outlined, size: 32, color: Colors.black26),
    );
  }
}