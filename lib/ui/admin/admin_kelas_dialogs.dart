import 'package:flutter/material.dart';
import 'package:path_mobile/data/admin/admin_model.dart';
import 'package:path_mobile/ui/admin/admin_controller.dart';
import 'package:path_mobile/ui/core/app_theme.dart';

class CreateKelasDialogResult {
  final String nama;
  final String deskripsi;
  final int tingkat;
  final String tahunAjaran;

  const CreateKelasDialogResult({
    required this.nama,
    required this.deskripsi,
    required this.tingkat,
    required this.tahunAjaran,
  });
}

class AdminCreateKelasDialog extends StatefulWidget {
  const AdminCreateKelasDialog({super.key});

  @override
  State<AdminCreateKelasDialog> createState() => _AdminCreateKelasDialogState();
}

class _AdminCreateKelasDialogState extends State<AdminCreateKelasDialog> {
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
      CreateKelasDialogResult(
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
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            spacing: 4,
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Nama Kelas',
                  hintText: 'Contoh: X PPLG 1',
                  errorText: _triedSubmit && _namaController.text.trim().isEmpty
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
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

class PengampuSelectionResult {
  final int? pengampuId;

  const PengampuSelectionResult(this.pengampuId);
}

class PilihPengampuDialog extends StatefulWidget {
  final AdminKelasModel kelas;
  final AdminController controller;

  const PilihPengampuDialog({
    super.key,
    required this.kelas,
    required this.controller,
  });

  @override
  State<PilihPengampuDialog> createState() => _PilihPengampuDialogState();
}

class _PilihPengampuDialogState extends State<PilihPengampuDialog> {
  late int? _selectedGuruId = widget.kelas.pengampu > 0
      ? widget.kelas.pengampu
      : null;

  @override
  Widget build(BuildContext context) {
    final gurus = widget.controller.guruList;

    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
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
                        PengampuSelectionResult(_selectedGuruId),
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
