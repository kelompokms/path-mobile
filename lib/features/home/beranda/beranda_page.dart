import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../widgets/class_card.dart';
import '../widgets/empty_class_view.dart';
import '../../../core/constants/app_assets.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  int _selectedTab = 0; 
  int _navIndex = 0;

  // DATA SEMENTARA. Nanti diganti data dari backend.
  final List<ClassModel> _registeredClasses = List.generate(
    8,
    (i) => ClassModel(
      title: 'Mapel ${i + 1}',
      grade: 'Kelas X',
      teacher: 'Guru ${i + 1}',
      imagePath: AppAssets.covers[i % AppAssets.covers.length], 
    ),
  );

  final List<ClassModel> _teachingClasses = List.generate(
    6,
    (i) => ClassModel(
      title: 'Mapel ${i + 1}',
      grade: 'Kelas X',
      imagePath: AppAssets.covers[i % AppAssets.covers.length], 
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hasNoClass = _registeredClasses.isEmpty && _teachingClasses.isEmpty;
    final classes = _selectedTab == 0 ? _registeredClasses : _teachingClasses;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: const [
            Text('PATH', style: TextStyle(fontWeight: FontWeight.bold)),
            Icon(Icons.chevron_right, size: 20),
            Text('Beranda', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      body: hasNoClass
          ? EmptyClassView(
              onJoinClass: () {}, // TODO: buka halaman gabung kelas
              onAddClass: () {}, // TODO: buka halaman tambah kelas
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildTabButton('Terdaftar', 0),
                      const SizedBox(width: 12),
                      _buildTabButton('Pengajar', 1),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 150, // tinggi tiap kartu
                        ),
                    itemCount: classes.length,
                    itemBuilder: (context, index) => ClassCard(
                      data: classes[index],
                      onTap: () {}, // TODO: buka detail kelas
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.white,
        indicatorColor:
            Colors.transparent, 
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

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    void onPressed() => setState(() => _selectedTab = index);

    return SizedBox(
      width: 110,
      child: isSelected
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
