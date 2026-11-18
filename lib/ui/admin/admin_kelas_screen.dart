import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/core/anggota_kelas_tab.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/post_card.dart';
import 'package:path_mobile/ui/core/responsive.dart';

/// Admin page listing all school classes with interactive filtering by
/// academic year (`tahun_ajaran`), grade (`tingkat`), and class name (`nama`),
/// plus manual & CSV class creation (pengampu defaults to null) and teacher assignment.
class AdminKelasScreen extends StatefulWidget {
  final AdminController controller;
  final KelasRepository? kelasRepository;
  final Future<http.MultipartFile?> Function()? onPickCsvFile;

  const AdminKelasScreen({
    super.key,
    required this.controller,
    this.kelasRepository,
    this.onPickCsvFile,
  });

  @override
  State<AdminKelasScreen> createState() => _AdminKelasScreenState();
}

class _AdminKelasScreenState extends State<AdminKelasScreen> {
  final _nameFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.loadAllKelas();
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    super.dispose();
  }

  String _tingkatLabel(int tingkat) {
    switch (tingkat) {
      case 10:
        return 'Kelas X (10)';
      case 11:
        return 'Kelas XI (11)';
      case 12:
        return 'Kelas XII (12)';
      default:
        return 'Kelas $tingkat';
    }
  }

  Future<void> _openCreateKelasDialog() async {
    final result = await showDialog<_CreateKelasDialogResult>(
      context: context,
      builder: (_) => const _AdminCreateKelasDialog(),
    );
    if (result == null || !mounted) return;

    final err = await widget.controller.createKelas(
      nama: result.nama,
      deskripsi: result.deskripsi,
      gradeInput: result.tingkat.toString(),
      tahunAjaran: result.tahunAjaran,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(err ?? 'Kelas berhasil dibuat')),
      );
  }

  Future<http.MultipartFile?> _defaultPickCsvFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final fileName = file.name.trim().isEmpty ? 'kelas.csv' : file.name.trim();
    return http.MultipartFile.fromBytes('file_csv', bytes, filename: fileName);
  }

  Future<void> _openUploadCsvDialog() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Upload CSV Kelas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unggah file CSV untuk membuat banyak kelas sekaligus dengan pengampu default kosong (null).',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            SizedBox(height: 10),
            Text(
              'Format kolom CSV:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            SizedBox(height: 4),
            SelectableText(
              'nama,tingkat,tahun_ajaran,deskripsi\n'
              'X PPLG 1,10,2026/2027,Pemrograman Dasar\n'
              'XI RPL 1,11,2026/2027,Basis Data',
              style: TextStyle(fontSize: 11, color: AppColors.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('admin_csv_pick_confirm_button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pilih File CSV'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final fileCsv = await (widget.onPickCsvFile ?? _defaultPickCsvFile)();
    if (fileCsv == null || !mounted) return;

    final (msg, err) = await widget.controller.uploadKelasCsv(fileCsv);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(err ?? msg ?? 'Kelas dari CSV berhasil dibuat'),
        ),
      );
  }

  Future<AdminKelasModel?> _openChangePengampuDialog(
    AdminKelasModel kelas,
  ) async {
    if (!widget.controller.isLoadingUsers) {
      await widget.controller.loadUsers();
      if (!mounted) return null;
    }

    final selection = await showDialog<_PengampuSelectionResult>(
      context: context,
      builder: (_) => _PilihPengampuDialog(
        kelas: kelas,
        controller: widget.controller,
      ),
    );
    if (selection == null || !mounted) return null;

    final err = await widget.controller.updatePengampuKelas(
      kelas.kodeKelas,
      selection.pengampuId,
    );
    if (!mounted) return null;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(err ?? 'Pengampu kelas berhasil diperbarui'),
        ),
      );
    if (err != null) return null;

    final idx = widget.controller.allKelas.indexWhere(
      (k) => k.kodeKelas == kelas.kodeKelas,
    );
    return idx != -1 ? widget.controller.allKelas[idx] : null;
  }

  void _openClassDetail(AdminKelasModel kelas) {
    final trail = ['Admin', 'Kelas', kelas.nama];
    openPage(
      context,
      breadcrumb: trail,
      page: _AdminKelasDetailScreen(
        kelas: kelas,
        kelasRepository: widget.kelasRepository,
        onChangePengampu: _openChangePengampuDialog,
      ),
      routeName: 'admin-kelas-detail',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Admin', 'Kelas'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final allKelas = ctrl.allKelas;
          final filtered = ctrl.filteredKelas;
          final yearOptions = ctrl.tahunAjaranOptions;
          final tingkatOptions = ctrl.tingkatOptions;

          if (ctrl.isLoadingKelas && allKelas.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ctrl.kelasError != null && allKelas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctrl.kelasError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: ctrl.loadAllKelas,
                      style: AppTheme.softCompactButton,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final hPad = responsiveHorizontalInset(
                width,
                maxWidth: ResponsiveBreakpoints.wide,
              );

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text(
                                'Daftar Kelas Sekolah',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  ElevatedButton.icon(
                                    key: const Key('admin_upload_csv_kelas_button'),
                                    onPressed: _openUploadCsvDialog,
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Upload CSV'),
                                    style: AppTheme.softCompactButton,
                                  ),
                                  ElevatedButton.icon(
                                    key: const Key('admin_add_kelas_button'),
                                    onPressed: _openCreateKelasDialog,
                                    icon: const Icon(
                                      Icons.add_box_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Tambah Kelas'),
                                    style: AppTheme.softCompactButton,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('admin_filter_nama_kelas'),
                          controller: _nameFilterController,
                          onChanged: ctrl.setNamaKelasFilter,
                          decoration: InputDecoration(
                            hintText: 'Filter nama kelas...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: ctrl.searchNamaKelas.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _nameFilterController.clear();
                                      ctrl.setNamaKelasFilter('');
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Hapus filter nama',
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, filterConstraints) {
                            final sideBySide =
                                filterConstraints.maxWidth >= 340;
                            final yearDropdown =
                                DropdownButtonFormField<String?>(
                                  key: const Key('admin_filter_tahun_ajaran'),
                                  initialValue:
                                      yearOptions.contains(
                                        ctrl.selectedTahunAjaran,
                                      )
                                      ? ctrl.selectedTahunAjaran
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Tahun Ajaran',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'Semua Tahun Ajaran',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    for (final year in yearOptions)
                                      DropdownMenuItem<String?>(
                                        value: year,
                                        child: Text(
                                          year,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: ctrl.setTahunAjaranFilter,
                                );

                            final tingkatDropdown =
                                DropdownButtonFormField<int?>(
                                  key: const Key('admin_filter_tingkat'),
                                  initialValue:
                                      tingkatOptions.contains(
                                        ctrl.selectedTingkat,
                                      )
                                      ? ctrl.selectedTingkat
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Tingkat Kelas',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        'Semua Tingkat',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    for (final t in tingkatOptions)
                                      DropdownMenuItem<int?>(
                                        value: t,
                                        child: Text(
                                          _tingkatLabel(t),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: ctrl.setTingkatFilter,
                                );

                            if (sideBySide) {
                              return Row(
                                children: [
                                  Expanded(child: yearDropdown),
                                  const SizedBox(width: 8),
                                  Expanded(child: tingkatDropdown),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                yearDropdown,
                                const SizedBox(height: 8),
                                tingkatDropdown,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              'Menampilkan ${filtered.length} dari ${allKelas.length} kelas',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            if (ctrl.hasActiveKelasFilters)
                              TextButton.icon(
                                onPressed: () {
                                  _nameFilterController.clear();
                                  ctrl.resetKelasFilters();
                                },
                                icon: const Icon(Icons.refresh, size: 15),
                                label: const Text('Reset Filter'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: ctrl.loadAllKelas,
                      child: filtered.isEmpty
                          ? LayoutBuilder(
                              builder: (context, emptyConstraints) =>
                                  SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: emptyConstraints.maxHeight,
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Text(
                                            allKelas.isEmpty
                                                ? 'Belum ada kelas terdaftar'
                                                : 'Tidak ada kelas yang sesuai dengan filter',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.secondaryText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            )
                          : GridView.builder(
                              padding: responsiveListPadding(
                                width,
                                maxWidth: ResponsiveBreakpoints.wide,
                                top: 4,
                                bottom: 16,
                              ),
                              gridDelegate: responsiveClassGridDelegate(
                                context,
                                width,
                                maxContentWidth: ResponsiveBreakpoints.wide,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final item = filtered[i];
                                return ClassCard(
                                  data: item.toClassItem(coverIndex: i),
                                  onTap: () => _openClassDetail(item),
                                  menuItems: [
                                    (
                                      label: 'Ubah pengampu',
                                      onSelected: () =>
                                          _openChangePengampuDialog(item),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateKelasDialogResult {
  final String nama;
  final String deskripsi;
  final int tingkat;
  final String tahunAjaran;

  const _CreateKelasDialogResult({
    required this.nama,
    required this.deskripsi,
    required this.tingkat,
    required this.tahunAjaran,
  });
}

class _AdminCreateKelasDialog extends StatefulWidget {
  const _AdminCreateKelasDialog();

  @override
  State<_AdminCreateKelasDialog> createState() =>
      _AdminCreateKelasDialogState();
}

class _AdminCreateKelasDialogState extends State<_AdminCreateKelasDialog> {
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  late final TextEditingController _tahunController = TextEditingController(
    text: AdminController.defaultTahunAjaran(),
  );
  int _tingkat = 10;
  bool _triedSubmit = false;

  bool get _canSubmit =>
      _namaController.text.trim().isNotEmpty &&
      _tahunController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _tahunController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) {
      setState(() => _triedSubmit = true);
      return;
    }
    Navigator.pop(
      context,
      _CreateKelasDialogResult(
        nama: _namaController.text.trim(),
        deskripsi: _deskripsiController.text.trim(),
        tingkat: _tingkat,
        tahunAjaran: _tahunController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Kelas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_create_kelas_nama'),
                controller: _namaController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nama Kelas',
                  hintText: 'Contoh: X PPLG 1',
                  errorText:
                      _triedSubmit && _namaController.text.trim().isEmpty
                      ? 'Nama kelas wajib diisi'
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: const Key('admin_create_kelas_tingkat'),
                initialValue: _tingkat,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tingkat Kelas',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 10,
                    child: Text(
                      'Kelas X (10)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 11,
                    child: Text(
                      'Kelas XI (11)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 12,
                    child: Text(
                      'Kelas XII (12)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _tingkat = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('admin_create_kelas_tahun'),
                controller: _tahunController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Tahun Ajaran',
                  hintText: 'Contoh: 2026/2027',
                  errorText:
                      _triedSubmit && _tahunController.text.trim().isEmpty
                      ? 'Tahun ajaran wajib diisi'
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('admin_create_kelas_deskripsi'),
                controller: _deskripsiController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pengampu default bernilai kosong (null) dan dapat diubah dari daftar guru setelah kelas dibuat.',
                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      key: const Key('admin_create_kelas_submit'),
                      onPressed: _submit,
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PengampuSelectionResult {
  final int? pengampuId;

  const _PengampuSelectionResult(this.pengampuId);
}

class _PilihPengampuDialog extends StatefulWidget {
  final AdminKelasModel kelas;
  final AdminController controller;

  const _PilihPengampuDialog({required this.kelas, required this.controller});

  @override
  State<_PilihPengampuDialog> createState() => _PilihPengampuDialogState();
}

class _PilihPengampuDialogState extends State<_PilihPengampuDialog> {
  late int? _selectedGuruId = widget.kelas.pengampu > 0
      ? widget.kelas.pengampu
      : null;

  @override
  Widget build(BuildContext context) {
    final gurus = widget.controller.guruList;

    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubah Pengampu • ${widget.kelas.nama}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih guru pengampu utama untuk kelas ini:',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _selectedGuruId == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _selectedGuruId == null
                            ? AppColors.color1
                            : AppColors.secondaryText,
                      ),
                      title: const Text('Kosongkan Pengampu'),
                      onTap: () => setState(() => _selectedGuruId = null),
                    ),
                    if (gurus.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          widget.controller.usersError ??
                              'Belum ada pengguna ber-role Guru.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      )
                    else
                      for (final guru in gurus)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _selectedGuruId == guru.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _selectedGuruId == guru.id
                                ? AppColors.color1
                                : AppColors.secondaryText,
                          ),
                          title: Text(guru.nama),
                          subtitle: guru.email.isNotEmpty
                              ? Text(
                                  guru.email,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () =>
                              setState(() => _selectedGuruId = guru.id),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      key: const Key('admin_save_pengampu_button'),
                      onPressed: () => Navigator.pop(
                        context,
                        _PengampuSelectionResult(_selectedGuruId),
                      ),
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminKelasDetailScreen extends StatefulWidget {
  final AdminKelasModel kelas;
  final KelasRepository? kelasRepository;
  final Future<AdminKelasModel?> Function(AdminKelasModel kelas)?
  onChangePengampu;

  const _AdminKelasDetailScreen({
    required this.kelas,
    this.kelasRepository,
    this.onChangePengampu,
  });

  @override
  State<_AdminKelasDetailScreen> createState() =>
      _AdminKelasDetailScreenState();
}

class _AdminKelasDetailScreenState extends State<_AdminKelasDetailScreen> {
  late AdminKelasModel _kelas = widget.kelas;
  int _tabIndex = 0;
  bool _loadingPosts = false;
  String? _postsError;
  List<PostinganModel> _materi = const [];
  List<PostinganModel> _tugas = const [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final repo = widget.kelasRepository;
    if (repo == null) return;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });

    final results = await Future.wait([
      repo.getListPostingan(
        _kelas.kodeKelas,
        tipe: PostinganModel.tipeMateri,
      ),
      repo.getListPostingan(
        _kelas.kodeKelas,
        tipe: PostinganModel.tipeTugas,
      ),
    ]);
    if (!mounted) return;

    final (materiList, materiErr) = results[0];
    final (tugasList, tugasErr) = results[1];
    setState(() {
      _loadingPosts = false;
      _postsError = materiErr ?? tugasErr;
      if (materiList != null) _materi = materiList;
      if (tugasList != null) _tugas = tugasList;
    });
  }

  Future<void> _editPengampu() async {
    final handler = widget.onChangePengampu;
    if (handler == null) return;
    final updated = await handler(_kelas);
    if (updated != null && mounted) {
      setState(() => _kelas = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kelas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BackTitleRow(title: k.nama),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${k.gradeLabel} • Tahun Ajaran ${k.tahunAjaran} • Kode: ${k.kodeKelas}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    k.namaPengampu.isNotEmpty
                        ? 'Pengampu: ${k.namaPengampu}'
                        : 'Pengampu: Belum ditentukan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (widget.onChangePengampu != null)
                    TextButton.icon(
                      key: const Key('admin_detail_ubah_pengampu_button'),
                      onPressed: _editPengampu,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Ubah Pengampu'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              if (k.deskripsi.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  k.deskripsi,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Postingan'),
                selected: _tabIndex == 0,
                onSelected: (_) => setState(() => _tabIndex = 0),
              ),
              ChoiceChip(
                label: const Text('Anggota'),
                selected: _tabIndex == 1,
                onSelected: (_) => setState(() => _tabIndex = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _tabIndex == 1
              ? AnggotaKelasTab(
                  kodeKelas: k.kodeKelas,
                  horizontalPadding: 16,
                  loadMembers: widget.kelasRepository != null
                      ? () => widget.kelasRepository!.getListAnggota(
                          k.kodeKelas,
                        )
                      : null,
                )
              : _buildPostsTab(),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    if (_loadingPosts && _materi.isEmpty && _tugas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_postsError != null && _materi.isEmpty && _tugas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _postsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    final combined = <_AdminPostEntry>[
      for (final m in _materi) _AdminPostEntry(post: m, isTugas: false),
      for (final t in _tugas) _AdminPostEntry(post: t, isTugas: true),
    ]..sort((a, b) => b.post.dibuat.compareTo(a.post.dibuat));

    if (combined.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada postingan di kelas ini',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: combined.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final entry = combined[i];
        return PostCard(
          icon: entry.isTugas
              ? Icons.assignment_outlined
              : Icons.menu_book_outlined,
          label: entry.isTugas ? 'Tugas' : 'Materi',
          title: entry.post.judul,
          date: entry.post.dibuat,
          onTap: () => openPage(
            context,
            breadcrumb: ['Admin', 'Kelas', _kelas.nama, entry.post.judul],
            page: _AdminPostDetailScreen(
              post: entry.post,
              isTugas: entry.isTugas,
              baseUrl: widget.kelasRepository?.baseUrl,
            ),
          ),
        );
      },
    );
  }
}

class _AdminPostEntry {
  final PostinganModel post;
  final bool isTugas;

  const _AdminPostEntry({required this.post, required this.isTugas});
}

class _AdminPostDetailScreen extends StatelessWidget {
  final PostinganModel post;
  final bool isTugas;
  final String? baseUrl;

  const _AdminPostDetailScreen({
    required this.post,
    required this.isTugas,
    this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final items = post.lampiranItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        BackTitleRow(title: post.judul),
        Text(
          '${isTugas ? 'Tugas' : 'Materi'} • ${formatTanggal(post.dibuat)}',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        if (post.deskripsi.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            post.deskripsi,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ],
        if (items.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Lampiran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            FileCard.fromItem(item, baseUrl: baseUrl),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
