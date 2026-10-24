import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';

class EmptyClassView extends StatelessWidget {
  final String message;
  final String? hint;
  final VoidCallback? onJoinClass;
  final VoidCallback? onAddClass;

  const EmptyClassView({
    super.key,
    required this.message,
    this.hint,
    this.onJoinClass,
    this.onAddClass,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        AppAssets.emptyClass,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        hint!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: onJoinClass,
                child: const Text('Gabung Kelas'),
              ),
            ),
            if (onAddClass != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: OutlinedButton(
                  onPressed: onAddClass,
                  child: const Text('Tambah Kelas'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
