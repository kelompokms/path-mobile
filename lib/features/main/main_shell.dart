import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../home/beranda/beranda_page.dart';
import '../kelas/kelas_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Urutan harus sama dengan AppAssets.navItems
  final List<Widget> _pages = const [
    BerandaPage(),
    KelasPage(),
    Center(child: Text('Tugas')), // sementara
    Center(child: Text('Jadwal')), // sementara
    Center(child: Text('Profil')), // sementara
  ];

  @override
  Widget build(BuildContext context) {
    final title = AppAssets.navItems[_index].label;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Text('PATH', style: TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.chevron_right, size: 20),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: AppAssets.navItems
            .map(
              (item) => NavigationDestination(
                icon: _navIcon(item.inactive),
                selectedIcon: _navIcon(item.active),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _navIcon(String path) {
    return Image.asset(
      path,
      width: 26,
      height: 26,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.image_not_supported_outlined),
    );
  }
}