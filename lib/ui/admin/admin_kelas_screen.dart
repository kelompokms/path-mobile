import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/data/kelas/kelas_repository.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/admin/admin_kelas_detail_screen.dart';
import 'package:path_mobile/ui/admin/admin_kelas_dialogs.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

export 'admin_kelas_detail_screen.dart';
export 'admin_kelas_dialogs.dart';

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
  static const int _maxCsvBytes = 5 * 1024 * 1024;

  final _nameFilterController = TextEditingController();
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        widget.controller.loadAllKelas();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdminKelasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      Future<void>.microtask(() {
        if (mounted) {
          widget.controller.loadAllKelas();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleRefresh() async {
    await widget.controller.loadAllKelas();
    if (!mounted) return;
    final err = widget.controller.kelasError;
    if (err != null && widget.controller.allKelas.isNotEmpty) {
      _showSnack(err);
    }
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

  static const String _kelasCsvTemplate =
      'nama,tingkat,tahun_ajaran,deskripsi\n'
      'X PPLG 1,10,2026/2027,Dasar HTML CSS dan JavaScript\n'
      'XI RPL 1,11,2026/2027,Desain ERD dan SQL\n';

  Future<void> _downloadKelasTemplateCsv() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(_kelasCsvTemplate));
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Simpan Template CSV Kelas',
        fileName: 'template_kelas.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      if (saved != null) {
        _showSnack('Template CSV kelas berhasil diunduh');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _kelasCsvTemplate));
      if (mounted) {
        _showSnack('Template CSV disalin ke clipboard');
      }
    }
  }

  Future<void> _openCreateKelasDialog() async {
    if (_isMutating) return;
    if (widget.controller.guruList.isEmpty &&
        !widget.controller.isLoadingUsers) {
      await widget.controller.loadUsers();
      if (!mounted) return;
    }
    final result = await showDialog<CreateKelasDialogResult>(
      context: context,
      builder: (_) =>
          AdminCreateKelasDialog(guruList: widget.controller.guruList),
    );
    if (result == null || !mounted) return;

    final existingCodes = widget.controller.allKelas
        .map((k) => k.kodeKelas)
        .toSet();

    setState(() => _isMutating = true);
    String? err;
    try {
      err = await widget.controller.createKelas(
        nama: result.nama,
        deskripsi: result.deskripsi,
        gradeInput: result.tingkat.toString(),
        tahunAjaran: result.tahunAjaran,
        pengampuId: result.pengampuId,
      );
      if (err == null && result.pengampuId != null && mounted) {
        AdminKelasModel? created;
        for (final k in widget.controller.allKelas) {
          if (!existingCodes.contains(k.kodeKelas) &&
              k.nama.trim().toLowerCase() ==
                  result.nama.trim().toLowerCase() &&
              k.tingkat == result.tingkat) {
            created = k;
            break;
          }
        }
        if (created != null &&
            created.kodeKelas.isNotEmpty &&
            created.pengampu != result.pengampuId) {
          final pengampuErr = await widget.controller.updatePengampuKelas(
            created.kodeKelas,
            result.pengampuId,
          );
          if (pengampuErr != null) {
            err = 'Kelas dibuat, tetapi gagal mengatur pengampu: $pengampuErr';
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
    if (!mounted) return;

    _showSnack(err ?? 'Kelas berhasil dibuat');
  }

  Future<http.MultipartFile?> _defaultPickCsvFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return null;
    final knownSize = file.lengthSync();
    if (knownSize != null && knownSize > _maxCsvBytes) {
      _showSnack('Ukuran file CSV terlalu besar (maks. 5 MB)');
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _showSnack('File CSV kosong');
      return null;
    }
    if (bytes.length > _maxCsvBytes) {
      _showSnack('Ukuran file CSV terlalu besar (maks. 5 MB)');
      return null;
    }
    final fileName = file.name.trim().isEmpty ? 'kelas.csv' : file.name.trim();
    return http.MultipartFile.fromBytes('file_csv', bytes, filename: fileName);
  }

  Future<void> _openUploadCsvDialog() async {
    if (_isMutating) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
        title: const Text(
          'Upload CSV Kelas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unggah file CSV (dapat dibuat dari Excel lalu Save As CSV UTF-8) untuk membuat banyak kelas sekaligus. Guru pengampu diatur manual oleh admin setelah import.',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 10),
              const Text(
                'Format kolom CSV:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const SelectableText(
                _kelasCsvTemplate,
                style: TextStyle(fontSize: 11, color: AppColors.text),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('admin_csv_download_template_button'),
                    onPressed: _downloadKelasTemplateCsv,
                    icon: const Icon(Icons.download_outlined, size: 15),
                    label: const Text(
                      'Download Template',
                      style: TextStyle(fontSize: 11),
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
                  OutlinedButton.icon(
                    key: const Key('admin_csv_copy_template_button'),
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: _kelasCsvTemplate),
                      );
                      if (mounted) {
                        _showSnack('Template CSV disalin ke clipboard');
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    label: const Text(
                      'Salin Template',
                      style: TextStyle(fontSize: 11),
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
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('admin_csv_pick_confirm_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pilih File CSV'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _isMutating = true);
    try {
      final http.MultipartFile? fileCsv;
      try {
        fileCsv = await (widget.onPickCsvFile ?? _defaultPickCsvFile)();
      } catch (e) {
        _showSnack('Gagal memilih file CSV: $e');
        return;
      }
      if (fileCsv == null || !mounted) return;

      final (msg, err) = await widget.controller.uploadKelasCsv(fileCsv);
      if (!mounted) return;

      _showSnack(err ?? msg ?? 'Kelas dari CSV berhasil dibuat');
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<AdminKelasModel?> _openChangePengampuDialog(
    AdminKelasModel kelas,
  ) async {
    if (_isMutating) return null;
    setState(() => _isMutating = true);
    try {
      if (!widget.controller.isLoadingUsers) {
        await widget.controller.loadUsers();
        if (!mounted) return null;
      }

      final selection = await showDialog<PengampuSelectionResult>(
        context: context,
        builder: (_) => PilihPengampuDialog(
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

      _showSnack(err ?? 'Pengampu kelas berhasil diperbarui');
      if (err != null) return null;

      final idx = widget.controller.allKelas.indexWhere(
        (k) => k.kodeKelas == kelas.kodeKelas,
      );
      return idx != -1 ? widget.controller.allKelas[idx] : null;
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  void _openClassDetail(AdminKelasModel kelas) {
    final trail = ['Admin', 'Kelas', kelas.nama];
    openPage(
      context,
      breadcrumb: trail,
      page: AdminKelasDetailScreen(
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
                                    key: const Key(
                                      'admin_upload_csv_kelas_button',
                                    ),
                                    onPressed: _isMutating
                                        ? null
                                        : _openUploadCsvDialog,
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Upload CSV'),
                                    style: AppTheme.softCompactButton,
                                  ),
                                  ElevatedButton.icon(
                                    key: const Key('admin_add_kelas_button'),
                                    onPressed: _isMutating
                                        ? null
                                        : _openCreateKelasDialog,
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
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('admin_filter_nama_kelas'),
                          controller: _nameFilterController,
                          onChanged: ctrl.setNamaKelasFilter,
                          textInputAction: TextInputAction.search,
                          onSubmitted: ctrl.setNamaKelasFilter,
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.cardRadius,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.cardRadius,
                                      ),
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.cardRadius,
                                      ),
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
                        const SizedBox(height: 16),
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
                      onRefresh: _handleRefresh,
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
                              physics: const AlwaysScrollableScrollPhysics(),
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
                                  data: item.toClassItem(),
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
