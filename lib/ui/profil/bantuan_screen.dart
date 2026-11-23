import 'package:flutter/material.dart';
import 'package:path_mobile/data/profil/profil_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/profil/profil_controller.dart';

class BantuanScreen extends StatefulWidget {
  final ProfilController? controller;

  const BantuanScreen({super.key, this.controller});

  static const List<BantuanKontenModel> defaultItems = [
    BantuanKontenModel(
      kunci: 'panduan_ai',
      judul: 'Panduan AI',
      editable: true,
      isi:
          'Fitur AI di PATH membantu proses belajar dan mengajar secara adaptif:\n\n'
          '1. Bantuan AI (Murid)\n'
          'Buka halaman detail materi di dalam kelas, lalu tekan tombol "Bantuan AI". '
          'Pilih gaya penjelasan yang diinginkan (Tabel, Diagram, Ilustrasi, atau Kombinasi) '
          'atau ketik pertanyaan langsung terkait materi tersebut.\n\n'
          '2. Buat Materi dengan AI (Guru)\n'
          'Di tab Materi kelas, tekan "Buat Materi" lalu pilih "Buat materi dengan AI". '
          'Isi judul, topik materi, dan elemen pendukung untuk membuat draf materi yang dapat langsung digunakan atau disesuaikan.\n\n'
          '3. Koreksi Menggunakan AI (Guru)\n'
          'Di halaman "Pengumpulan & Penilaian" pada tugas, tekan "Koreksi menggunakan AI", '
          'unggah file kunci jawaban (PDF, TXT, DOC/DOCX, XLS/XLSX, CSV) atau tulis deskripsi kunci jawaban, '
          'pilih kiriman siswa, lalu tinjau hasil penilaian sebelum disimpan.',
    ),
    BantuanKontenModel(
      kunci: 'etika_ai',
      judul: 'Etika Penggunaan AI',
      editable: false,
      isi:
          'Agar pemanfaatan AI tetap bermanfaat dan bertanggung jawab di lingkungan sekolah:\n\n'
          '• Gunakan AI sebagai alat bantu memahami konsep, bukan untuk menyalin jawaban secara langsung.\n'
          '• Selalu periksa dan verifikasi kebenaran informasi yang dihasilkan AI dengan buku pelajaran atau guru.\n'
          '• Hindari plagiarisme dan biasakan menuliskan hasil pemahaman dengan bahasa sendiri.\n'
          '• Jangan memasukkan data sensitif atau informasi pribadi ke dalam prompt AI.\n'
          '• Patuhi ketentuan penggunaan AI yang ditetapkan oleh guru dan pihak sekolah.',
    ),
    BantuanKontenModel(
      kunci: 'kontak_kami',
      judul: 'Kontak Kami',
      editable: true,
      isi:
          'MBKM PATH\n'
          'Email: -\n\n'
          'Jika mengalami kendala atau memiliki pertanyaan terkait penggunaan aplikasi PATH, '
          'silakan hubungi administrator sekolah atau tim MBKM PATH.',
    ),
  ];

  @override
  State<BantuanScreen> createState() => _BantuanScreenState();
}

class _BantuanScreenState extends State<BantuanScreen> {
  List<BantuanKontenModel> _items = List<BantuanKontenModel>.from(
    BantuanScreen.defaultItems,
  );
  bool _saving = false;

  bool get _isAdmin => widget.controller?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    final (list, err) = await ctrl.getBantuan();
    if (!mounted || err != null || list == null || list.isEmpty) return;
    setState(() {
      _items = list;
    });
  }

  Future<void> _editSection(BantuanKontenModel item) async {
    final ctrl = widget.controller;
    if (ctrl == null || _saving) return;

    final updatedText = await showDialog<String>(
      context: context,
      builder: (_) => _EditBantuanDialog(item: item),
    );
    if (updatedText == null || !mounted) return;

    setState(() => _saving = true);
    final (updated, err) = await ctrl.updateBantuan(item.kunci, updatedText);
    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() {
      _items = [
        for (final existing in _items)
          if (existing.kunci == item.kunci)
            updated ?? existing.copyWith(isi: updatedText)
          else
            existing,
      ];
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${item.judul} diperbarui')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = responsiveHorizontalInset(
          constraints.maxWidth,
          maxWidth: 720,
        );
        return Column(
          children: [
            Padding(
              padding: alignedBackTitlePadding(h),
              child: const BackTitleRow(title: 'Bantuan'),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(h, 8, h, 24),
                children: [
                  for (final item in _items) ...[
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(
                        Icons.help_outline,
                        size: 18,
                        color: AppColors.text,
                      ),
                      title: Text(
                        item.judul,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            item.isi,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (_isAdmin && item.editable) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              key: Key('admin_edit_bantuan_${item.kunci}'),
                              onPressed: _saving
                                  ? null
                                  : () => _editSection(item),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: Text(
                                'Edit ${item.judul}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.cardRadius,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditBantuanDialog extends StatefulWidget {
  final BantuanKontenModel item;

  const _EditBantuanDialog({required this.item});

  @override
  State<_EditBantuanDialog> createState() => _EditBantuanDialogState();
}

class _EditBantuanDialogState extends State<_EditBantuanDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.item.isi);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
      title: Text(
        'Edit ${item.judul}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: TextField(
          key: Key('edit_bantuan_field_${item.kunci}'),
          controller: _textController,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: 'Masukkan isi ${item.judul}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: Key('save_bantuan_button_${item.kunci}'),
          onPressed: () {
            final value = _textController.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
