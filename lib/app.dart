import 'features/home/beranda/beranda_page.dart';
import 'features/main/main_shell.dart';
import 'package:flutter/material.dart';

// import 'features/auth/welcome/welcome_page.dart';

class PathApp extends StatelessWidget {
  const PathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PATH Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}
