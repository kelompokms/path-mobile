import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';

class TambahAgendaResult {
  final String namaEvent;
  final String keterangan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;

  const TambahAgendaResult({
    required this.namaEvent,
    required this.keterangan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
  });
}

class TambahAgendaDialog extends StatefulWidget {
  final DateTime initialDate;

  const TambahAgendaDialog({super.key, required this.initialDate});

  @override
  State<TambahAgendaDialog> createState() => _TambahAgendaDialogState();
}

class _TambahAgendaDialogState extends State<TambahAgendaDialog> {
  final _namaController = TextEditingController();
  final _keteranganController = TextEditingController();
  late DateTime _tanggalMulai = DateUtils.dateOnly(widget.initialDate);
  late DateTime _tanggalSelesai = DateUtils.dateOnly(widget.initialDate);
  bool _triedSubmit = false;

  bool get _canSave => _namaController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _namaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalMulai,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggalMulai = DateUtils.dateOnly(picked);
      if (_tanggalSelesai.isBefore(_tanggalMulai)) {
        _tanggalSelesai = _tanggalMulai;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalSelesai.isBefore(_tanggalMulai)
          ? _tanggalMulai
          : _tanggalSelesai,
      firstDate: _tanggalMulai,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggalSelesai = DateUtils.dateOnly(picked);
    });
  }

  void _submit() {
    if (!_canSave) {
      setState(() => _triedSubmit = true);
      return;
    }
    Navigator.pop(
      context,
      TambahAgendaResult(
        namaEvent: _namaController.text.trim(),
        keterangan: _keteranganController.text.trim(),
        tanggalMulai: _tanggalMulai,
        tanggalSelesai: _tanggalSelesai,
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
                'Tambah Agenda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nama Event',
                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
              TextField(
                key: const Key('agenda_nama_field'),
                controller: _namaController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama event',
                  errorText: _triedSubmit && !_canSave
                      ? 'Nama event wajib diisi'
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Keterangan',
                style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
              TextField(
                key: const Key('agenda_keterangan_field'),
                controller: _keteranganController,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Tambahkan keterangan agenda (opsional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 340;
                  final startBtn = DatePickerField(
                    key: const Key('agenda_tanggal_mulai_field'),
                    label: 'Tanggal Mulai',
                    date: _tanggalMulai,
                    onTap: _pickStartDate,
                  );
                  final endBtn = DatePickerField(
                    key: const Key('agenda_tanggal_selesai_field'),
                    label: 'Tanggal Selesai',
                    date: _tanggalSelesai,
                    onTap: _pickEndDate,
                  );
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: startBtn),
                        const SizedBox(width: 8),
                        Expanded(child: endBtn),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      startBtn,
                      const SizedBox(height: 8),
                      endBtn,
                    ],
                  );
                },
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
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.text,
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton(
                      key: const Key('agenda_submit_button'),
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

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const DatePickerField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                formatTanggal(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
