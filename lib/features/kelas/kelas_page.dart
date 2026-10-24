import 'package:flutter/material.dart';
import '../home/widgets/empty_class_view.dart';
import 'widgets/join_class_view.dart';

class KelasPage extends StatefulWidget {
  const KelasPage({super.key});

  @override
  State<KelasPage> createState() => _KelasPageState();
}

class _KelasPageState extends State<KelasPage> {
  bool _isJoining = false; // sakelar: true = sedang di form "Gabung ke kelas"

  @override
  Widget build(BuildContext context) {
    if (_isJoining) {
      return JoinClassView(
        onCancel: () => setState(() => _isJoining = false),
        onJoined: () =>
            setState(() => _isJoining = false), // TODO: tampilkan daftar kelas
      );
    }

    return EmptyClassView(
      message: 'Anda belum bergabung kelas manapun',
      onJoinClass: () => setState(() => _isJoining = true),
    );
  }
}
