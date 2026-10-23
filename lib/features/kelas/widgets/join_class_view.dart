import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JoinClassView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onJoined;

  const JoinClassView({
    super.key,
    required this.onCancel,
    required this.onJoined,
  });

  @override
  State<JoinClassView> createState() => _JoinClassViewState();
}

class _JoinClassViewState extends State<JoinClassView> {
  final _controller = TextEditingController();

  // KODE SEMENTARA untuk uji coba. Nanti diganti pengecekan ke backend.
  static const _dummyValidCode = '32hc3s';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    final isFormatOk = RegExp(r'^[a-zA-Z0-9]{5,8}$').hasMatch(code);
    final isCorrect = code.toLowerCase() == _dummyValidCode;

    if (isFormatOk && isCorrect) {
      widget.onJoined();
    } else {
      _showError();
    }
  }

  void _showError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terjadi error'),
        content: const Text(
          'Tidak dapat bergabung ke kelas ini. Periksa kode dan akun, lalu coba lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Gabung ke kelas',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kode Kelas', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Mintalah kode kelas kepada pengajar, lalu masukkan kode di sini',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Kode Kelas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Untuk login menggunakan kode kelas',
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '1. Gunakan akun yang diberi otorisasi',
            style: textTheme.bodySmall,
          ),
          Text(
            '2. Gunakan kode kelas yang terdiri dari 5-8 huruf atau angka, tanpa spasi atau simbol',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Batal'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: _controller.text.isNotEmpty ? _submit : null,
                child: const Text('Gabung Kelas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}