import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';

class ClassItem {
  final String title;
  final String description;
  final String grade;
  final String? teacher;
  final int? coverIndex;
  final String code;
  final bool isGuru;

  const ClassItem({
    required this.title,
    this.description = '',
    required this.grade,
    this.teacher,
    this.coverIndex,
    this.code = 'ABC123',
    this.isGuru = false,
  });

  ClassItem copyWith({
    String? title,
    String? description,
    String? grade,
    String? teacher,
    int? coverIndex,
    String? code,
    bool? isGuru,
  }) {
    return ClassItem(
      title: title ?? this.title,
      description: description ?? this.description,
      grade: grade ?? this.grade,
      teacher: teacher ?? this.teacher,
      coverIndex: coverIndex ?? this.coverIndex,
      code: code ?? this.code,
      isGuru: isGuru ?? this.isGuru,
    );
  }

  String get inviteLink => 'https://path.app/join/$code';
}

class _CoverTheme {
  final Color color1;
  final Color color2;
  final IconData icon;

  const _CoverTheme(this.color1, this.color2, this.icon);
}

const _coverThemes = [
  _CoverTheme(Color(0xFF1E88E5), Color(0xFF1565C0), Icons.menu_book_rounded),
  _CoverTheme(Color(0xFF43A047), Color(0xFF2E7D32), Icons.devices_rounded),
  _CoverTheme(Color(0xFFE53935), Color(0xFFC62828), Icons.public_rounded),
  _CoverTheme(Color(0xFF8E24AA), Color(0xFF6A1B9A), Icons.school_rounded),
  _CoverTheme(Color(0xFF00ACC1), Color(0xFF00838F), Icons.science_rounded),
  _CoverTheme(Color(0xFFFB8C00), Color(0xFFEF6C00), Icons.straighten_rounded),
  _CoverTheme(
    Color(0xFF3949AB),
    Color(0xFF283593),
    Icons.sports_soccer_rounded,
  ),
  _CoverTheme(Color(0xFF546E7A), Color(0xFF37474F), Icons.handyman_rounded),
];

class ClassCard extends StatelessWidget {
  final ClassItem data;
  final VoidCallback? onTap;
  final String? menuLabel;
  final VoidCallback? onMenuSelected;
  final List<({String label, VoidCallback onSelected})>? menuItems;

  const ClassCard({
    super.key,
    required this.data,
    this.onTap,
    this.menuLabel,
    this.onMenuSelected,
    this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final idx =
        (data.coverIndex ?? data.title.hashCode).abs() % _coverThemes.length;
    final cover = _coverThemes[idx];

    return Card(
      elevation: AppTheme.cardElevation,
      shadowColor: AppTheme.shadowColor,
      margin: EdgeInsets.zero,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: AppTheme.cardShape(),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 70,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cover.color1, cover.color2],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        cover.icon,
                        size: 68,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 17,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        child: Icon(cover.icon, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.grade,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (data.teacher != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.teacher!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((menuItems == null || menuItems!.isEmpty) &&
                      onMenuSelected == null)
                    const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.secondaryText,
                    )
                  else
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<int>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.text,
                        ),
                        tooltip: 'Opsi kelas',
                        elevation: AppTheme.cardElevation,
                        shadowColor: AppTheme.shadowColor,
                        color: AppColors.background,
                        surfaceTintColor: Colors.transparent,
                        shape: AppTheme.cardShape(),
                        onSelected: (index) {
                          if (menuItems != null && menuItems!.isNotEmpty) {
                            menuItems![index].onSelected();
                          } else {
                            onMenuSelected?.call();
                          }
                        },
                        itemBuilder: (_) {
                          if (menuItems != null && menuItems!.isNotEmpty) {
                            return [
                              for (var i = 0; i < menuItems!.length; i++)
                                PopupMenuItem<int>(
                                  value: i,
                                  child: Text(menuItems![i].label),
                                ),
                            ];
                          }
                          return [
                            PopupMenuItem<int>(
                              value: 0,
                              child: Text(menuLabel ?? ''),
                            ),
                          ];
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyClassView extends StatelessWidget {
  final String message;
  final String? hint;
  final VoidCallback? onJoinClass;
  final VoidCallback? onAddClass;
  final String joinLabel;

  const EmptyClassView({
    super.key,
    required this.message,
    this.hint,
    this.onJoinClass,
    this.onAddClass,
    this.joinLabel = 'Gabung Kelas',
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              elevation: AppTheme.cardElevation,
              shadowColor: AppTheme.shadowColor,
              color: AppColors.card,
              surfaceTintColor: Colors.transparent,
              shape: AppTheme.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.color1.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.school_outlined,
                          size: 72,
                          color: AppColors.color1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        hint!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onJoinClass != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: onJoinClass,
                  child: Text(joinLabel),
                ),
              ),
            ],
            if (onAddClass != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: OutlinedButton(
                  onPressed: onAddClass,
                  child: const Text('Tambah Kelas'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class JoinClassForm extends StatefulWidget {
  final VoidCallback onCancel;
  final ValueChanged<String> onJoined;

  const JoinClassForm({
    super.key,
    required this.onCancel,
    required this.onJoined,
  });

  @override
  State<JoinClassForm> createState() => _JoinClassFormState();
}

class _JoinClassFormState extends State<JoinClassForm> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^[a-zA-Z0-9]{5,8}$').hasMatch(code)) {
      showInfoDialog(
        context,
        title: 'Terjadi error',
        message: 'Tidak dapat bergabung ke kelas ini. Periksa kode dan akun, lalu coba lagi.',
      );
      return;
    }
    widget.onJoined(code);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = constraints.maxWidth < 360 ? 16.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Gabung ke kelas',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: AppTheme.cardElevation,
                shadowColor: AppTheme.shadowColor,
                color: AppColors.card,
                surfaceTintColor: Colors.transparent,
                shape: AppTheme.cardShape(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kode Kelas',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mintalah kode kelas kepada pengajar, lalu masukkan kode di sini',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_codeController.text.isNotEmpty) {
                            _submit();
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Kode Kelas',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Untuk login menggunakan kode kelas',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Gunakan akun yang diberi otorisasi',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                '2. Gunakan kode kelas yang terdiri dari 5-8 huruf atau angka, tanpa spasi atau simbol',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: _codeController.text.isNotEmpty
                          ? _submit
                          : null,
                      child: const Text('Gabung Kelas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<({String nama, String deskripsi})?> showEditKelasDialog(
  BuildContext context, {
  required String initialNama,
  required String initialDeskripsi,
}) {
  return showDialog<({String nama, String deskripsi})>(
    context: context,
    builder: (_) => _EditKelasDialog(
      initialNama: initialNama,
      initialDeskripsi: initialDeskripsi,
    ),
  );
}

class _EditKelasDialog extends StatefulWidget {
  final String initialNama;
  final String initialDeskripsi;

  const _EditKelasDialog({
    required this.initialNama,
    required this.initialDeskripsi,
  });

  @override
  State<_EditKelasDialog> createState() => _EditKelasDialogState();
}

class _EditKelasDialogState extends State<_EditKelasDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialNama);
    _descController = TextEditingController(text: widget.initialDeskripsi);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSave) return;
    Navigator.pop(context, (
      nama: _nameController.text.trim(),
      deskripsi: _descController.text.trim(),
    ));
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Kelas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nama Kelas',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 16, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama kelas',
                  errorText: _canSave ? null : 'Nama kelas wajib diisi',
                  isDense: true,
                  border: const UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deskripsi Kelas',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
              TextField(
                controller: _descController,
                minLines: 3,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                decoration: const InputDecoration(
                  hintText: 'Tambahkan deskripsi kelas (opsional)',
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: AppColors.text, height: 1),
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
                    TextButton(
                      onPressed: _canSave ? _submit : null,
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
