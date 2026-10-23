import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../models/class_model.dart';
import '../widgets/class_card.dart';
import '../widgets/empty_class_view.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  int _selectedTab = 0;

  final List<ClassModel> _registeredClasses = [];
  final List<ClassModel> _teachingClasses = [];

  // // DATA SEMENTARA. Nanti diganti data dari backend.
  // final List<ClassModel> _registeredClasses = List.generate(
  //   8,
  //   (i) => ClassModel(
  //     title: 'Mapel ${i + 1}',
  //     grade: 'Kelas X',
  //     teacher: 'Guru ${i + 1}',
  //     imagePath: AppAssets.covers[i % AppAssets.covers.length], 
  //   ),
  // );

  // final List<ClassModel> _teachingClasses = List.generate(
  //   6,
  //   (i) => ClassModel(
  //     title: 'Mapel ${i + 1}',
  //     grade: 'Kelas X',
  //     imagePath: AppAssets.covers[i % AppAssets.covers.length], 
  //   ),
  // );

    @override
  Widget build(BuildContext context) {
    final hasNoClass = _registeredClasses.isEmpty && _teachingClasses.isEmpty;
    final classes = _selectedTab == 0 ? _registeredClasses : _teachingClasses;

    if (hasNoClass) {
      return EmptyClassView(
        message: 'Anda belum memiliki kelas atau bergabung ke kelas manapun',
        hint: 'Gabung Kelas atau Tambah Kelas',
        onJoinClass: () {}, // TODO: pindah ke form gabung kelas
        onAddClass: () {}, // TODO: tunggu desain Tambah Kelas
      );
    }

    return Column(
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 150,
            ),
            itemCount: classes.length,
            itemBuilder: (context, index) => ClassCard(
              data: classes[index],
              onTap: () {}, // TODO: buka detail kelas
            ),
          ),
        ),
      ],
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
