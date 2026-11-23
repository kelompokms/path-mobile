import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_mobile/data/kalender/kalender_model.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';
import 'package:path_mobile/ui/kalender/agenda_widgets.dart';
import 'package:path_mobile/ui/kalender/kalender_controller.dart';
import 'package:path_mobile/ui/kalender/month_calendar.dart';
import 'package:path_mobile/ui/kalender/tambah_agenda_dialog.dart';
import 'package:path_mobile/utils/date_time_helper.dart';

export 'agenda_widgets.dart';
export 'month_calendar.dart';
export 'tambah_agenda_dialog.dart';

class KalenderScreen extends StatefulWidget {
  final KalenderController controller;
  final bool isAdmin;
  final Future<http.MultipartFile?> Function()? onPickCsvFile;

  const KalenderScreen({
    super.key,
    required this.controller,
    this.isAdmin = false,
    this.onPickCsvFile,
  });

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  static const int _initialPage = 1200;
  static const int _maxCsvBytes = 5 * 1024 * 1024;
  static const String _kalenderCsvTemplate =
      'nama_kegiatan,tanggal_mulai,tanggal_selesai,keterangan\n'
      'UTS Semester Ganjil,2026-10-01,2026-10-07,Ujian Tengah Semester\n'
      'Libur Nasional,2026-12-25,2026-12-25,Hari Raya Natal\n';

  late final DateTime _today = DateUtils.dateOnly(nowGmt7());
  late final DateTime _baseMonth = DateTime(_today.year, _today.month);
  late DateTime _shownMonth = _baseMonth;
  late DateTime _selectedDate = _today;
  late final PageController _pageController = PageController(
    initialPage: _initialPage,
  );
  int _targetPage = _initialPage;
  bool? _lastIsTwoPane;
  bool _submittingAgenda = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        widget.controller.loadAgendas(includeClassTasks: !widget.isAdmin);
      }
    });
  }

  @override
  void didUpdateWidget(covariant KalenderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.isAdmin != widget.isAdmin) {
      Future<void>.microtask(() {
        if (mounted) {
          widget.controller.loadAgendas(includeClassTasks: !widget.isAdmin);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) =>
      DateTime(_baseMonth.year, _baseMonth.month + (page - _initialPage));

  void _onPageChanged(int page) {
    _targetPage = page;
    final nextMonth = _monthForPage(page);
    if (nextMonth.year == _shownMonth.year &&
        nextMonth.month == _shownMonth.month) {
      return;
    }
    setState(() {
      _shownMonth = nextMonth;
    });
  }

  void _changeMonth(int delta) {
    final nextPage = math.max(0, _targetPage + delta);
    if (nextPage == _targetPage) return;
    _targetPage = nextPage;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() {
      _shownMonth = _monthForPage(nextPage);
    });
  }

  void _jumpToMonth(DateTime date) {
    final monthsDelta =
        (date.year - _baseMonth.year) * 12 + (date.month - _baseMonth.month);
    final nextPage = math.max(0, _initialPage + monthsDelta);
    _targetPage = nextPage;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() {
      _shownMonth = _monthForPage(nextPage);
    });
  }

  Future<void> _openAddAgendaDialog() async {
    if (_submittingAgenda) return;
    final result = await showDialog<TambahAgendaResult>(
      context: context,
      builder: (_) => TambahAgendaDialog(initialDate: _selectedDate),
    );
    if (result == null || !mounted) return;

    setState(() => _submittingAgenda = true);
    final String? err;
    try {
      err = await widget.controller.createAgenda(
        namaEvent: result.namaEvent,
        keterangan: result.keterangan,
        tanggalMulai: result.tanggalMulai,
        tanggalSelesai: result.tanggalSelesai,
      );
    } finally {
      if (mounted) {
        setState(() => _submittingAgenda = false);
      }
    }
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() {
      _selectedDate = result.tanggalMulai;
    });
    if (result.tanggalMulai.year != _shownMonth.year ||
        result.tanggalMulai.month != _shownMonth.month) {
      _jumpToMonth(result.tanggalMulai);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Agenda berhasil ditambahkan')),
      );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _downloadKalenderTemplateCsv() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(_kalenderCsvTemplate));
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Simpan Template CSV Kalender',
        fileName: 'template_kalender.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      if (saved != null) {
        _showSnack('Template CSV kalender berhasil diunduh');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _kalenderCsvTemplate));
      if (mounted) {
        _showSnack('Template CSV disalin ke clipboard');
      }
    }
  }

  Future<http.MultipartFile?> _defaultPickKalenderCsv() async {
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
    final fileName =
        file.name.trim().isEmpty ? 'kalender.csv' : file.name.trim();
    return http.MultipartFile.fromBytes('file_csv', bytes, filename: fileName);
  }

  Future<void> _openUploadKalenderCsvDialog() async {
    if (_submittingAgenda) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
        title: const Text(
          'Upload CSV Kalender',
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
                'Unggah file CSV kalender akademik (format tanggal YYYY-MM-DD). Mengunggah CSV akan memperbarui daftar kegiatan kalender akademik.',
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
                _kalenderCsvTemplate,
                style: TextStyle(fontSize: 11, color: AppColors.text),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('admin_kalender_csv_download_template_button'),
                    onPressed: _downloadKalenderTemplateCsv,
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
                    key: const Key('admin_kalender_csv_copy_template_button'),
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: _kalenderCsvTemplate),
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
            key: const Key('admin_kalender_csv_pick_confirm_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pilih File CSV'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _submittingAgenda = true);
    try {
      final http.MultipartFile? fileCsv;
      try {
        fileCsv = await (widget.onPickCsvFile ?? _defaultPickKalenderCsv)();
      } catch (e) {
        _showSnack('Gagal memilih file CSV: $e');
        return;
      }
      if (fileCsv == null || !mounted) return;

      final err = await widget.controller.uploadKalenderAkademik(fileCsv);
      if (!mounted) return;
      _showSnack(err ?? 'Kalender akademik berhasil diunggah');
    } finally {
      if (mounted) {
        setState(() => _submittingAgenda = false);
      }
    }
  }

  Future<void> _openEditAgendaDialog(AgendaItemModel item) async {
    if (_submittingAgenda || item.id == null) return;
    final result = await showDialog<TambahAgendaResult>(
      context: context,
      builder: (_) => TambahAgendaDialog(
        title: 'Edit Agenda',
        initialDate: item.date,
        initialEndDate: item.endDate ?? item.date,
        initialNama: item.title,
        initialKeterangan: item.description,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _submittingAgenda = true);
    final String? err;
    try {
      err = await widget.controller.updateAgenda(
        agendaId: item.id!,
        namaEvent: result.namaEvent,
        keterangan: result.keterangan,
        tanggalMulai: result.tanggalMulai,
        tanggalSelesai: result.tanggalSelesai,
      );
    } finally {
      if (mounted) {
        setState(() => _submittingAgenda = false);
      }
    }
    if (!mounted) return;
    _showSnack(err ?? 'Agenda berhasil diperbarui');
  }

  Future<void> _confirmDeleteAgenda(AgendaItemModel item) async {
    if (_submittingAgenda || item.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Agenda',
      message: 'Apakah Anda yakin ingin menghapus agenda "${item.title}"?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _submittingAgenda = true);
    final String? err;
    try {
      err = await widget.controller.deleteAgenda(item.id!);
    } finally {
      if (mounted) {
        setState(() => _submittingAgenda = false);
      }
    }
    if (!mounted) return;
    _showSnack(err ?? 'Agenda berhasil dihapus');
  }

  Widget _buildCalendarHeader() {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const Text(
            'Kalender',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (widget.isAdmin)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  key: const Key('admin_upload_csv_kalender_button'),
                  onPressed:
                      _submittingAgenda ? null : _openUploadKalenderCsvDialog,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload CSV'),
                  style: AppTheme.softCompactButton,
                ),
                ElevatedButton.icon(
                  key: const Key('admin_add_agenda_button'),
                  onPressed: _submittingAgenda ? null : _openAddAgendaDialog,
                  icon: _submittingAgenda
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Tambah Agenda'),
                  style: AppTheme.softCompactButton,
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showDayAgendaDialog(DateTime day, List<AgendaItemModel> items) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: AppTheme.cardElevation,
        shadowColor: AppTheme.shadowColor,
        shape: AppTheme.cardShape(radius: AppTheme.dialogRadius),
        title: Text(
          'Agenda • ${formatTanggal(day)}',
          style: const TextStyle(
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
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 16),
                Text(
                  items[i].title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatAgendaMeta(items[i]),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (items[i].description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    items[i].description,
                    style: const TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.softCompactButton,
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final globalAgendas = widget.controller.globalAgendasByDay;
    return MonthCalendar(
      month: _shownMonth,
      today: _today,
      selectedDate: widget.isAdmin ? _selectedDate : null,
      globalAgendasByDay: globalAgendas,
      pageController: _pageController,
      monthForPage: _monthForPage,
      onPageChanged: _onPageChanged,
      onPrev: () => _changeMonth(-1),
      onNext: () => _changeMonth(1),
      onSelectDate: widget.isAdmin
          ? (day) => setState(() => _selectedDate = DateUtils.dateOnly(day))
          : null,
      onTapAgendaDay: widget.isAdmin
          ? null
          : (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              final items = globalAgendas[normalized] ?? const [];
              if (items.isNotEmpty) {
                _showDayAgendaDialog(normalized, items);
              }
            },
    );
  }

  List<MapEntry<DateTime, List<AgendaItemModel>>> get _days {
    final grouped = <DateTime, List<AgendaItemModel>>{};
    final monthStart = DateTime(_shownMonth.year, _shownMonth.month, 1);
    final monthEnd = DateTime(
      _shownMonth.year,
      _shownMonth.month,
      DateUtils.getDaysInMonth(_shownMonth.year, _shownMonth.month),
    );
    for (final item in widget.controller.agendas) {
      final start = DateTime(item.date.year, item.date.month, item.date.day);
      if (start.year == _shownMonth.year && start.month == _shownMonth.month) {
        (grouped[start] ??= []).add(item);
        continue;
      }
      final rawEnd = item.endDate;
      if (rawEnd != null &&
          (item.isGlobal || item.heading == 'Kalender Akademik')) {
        final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
        if (!start.isAfter(monthEnd) && !end.isBefore(monthStart)) {
          (grouped[monthStart] ??= []).add(item);
        }
      }
    }
    return grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      breadcrumb: const ['Kalender'],
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final days = _days;

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isTwoPane = width >= 720;
              if (_lastIsTwoPane != null && _lastIsTwoPane != isTwoPane) {
                final target = _targetPage;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients) {
                    _pageController.jumpToPage(target);
                  }
                });
              }
              _lastIsTwoPane = isTwoPane;

              if (isTwoPane) {
                final hPad = responsiveHorizontalPadding(width);
                final calendarPaneWidth = math.min(
                  420.0,
                  math.max(310.0, width * 0.4),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: calendarPaneWidth,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(hPad, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCalendarHeader(),
                            const SizedBox(height: 4),
                            _buildMonthCalendar(),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Colors.black12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(20, 12, hPad, 4),
                            child: const Text(
                              'Agenda',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildAgendaPane(
                              days,
                              leftPadding: 20,
                              rightPadding: hPad,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final hInset = responsiveHorizontalInset(width, maxWidth: 680);
              return RefreshIndicator(
                onRefresh: widget.controller.loadAgendas,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hInset, 8, hInset, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCalendarHeader(),
                            const SizedBox(height: 4),
                            _buildMonthCalendar(),
                            const Padding(
                              padding: EdgeInsets.only(top: 16, bottom: 4),
                              child: Text(
                                'Agenda',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.controller.isLoading && days.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (widget.controller.errorMessage != null &&
                        days.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.controller.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: widget.controller.loadAgendas,
                                  style: AppTheme.softCompactButton,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (days.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Belum ada agenda',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hInset, 8, 0, 24),
                        sliver: SliverList.builder(
                          itemCount: days.length,
                          itemBuilder: (context, i) {
                            final day = days[i];
                            return AgendaRow(
                              date: day.key,
                              items: day.value,
                              isToday: DateUtils.isSameDay(day.key, _today),
                              rightPadding: hInset,
                              onEditAgenda: widget.isAdmin
                                  ? _openEditAgendaDialog
                                  : null,
                              onDeleteAgenda: widget.isAdmin
                                  ? _confirmDeleteAgenda
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAgendaPane(
    List<MapEntry<DateTime, List<AgendaItemModel>>> days, {
    required double leftPadding,
    required double rightPadding,
  }) {
    if (widget.controller.isLoading && days.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.controller.errorMessage != null && days.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.controller.loadAgendas,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.controller.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: widget.controller.loadAgendas,
                        style: AppTheme.softCompactButton,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (days.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.controller.loadAgendas,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada agenda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: widget.controller.loadAgendas,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(leftPadding, 8, 0, 24),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          return AgendaRow(
            date: day.key,
            items: day.value,
            isToday: DateUtils.isSameDay(day.key, _today),
            rightPadding: rightPadding,
            onEditAgenda: widget.isAdmin ? _openEditAgendaDialog : null,
            onDeleteAgenda: widget.isAdmin ? _confirmDeleteAgenda : null,
          );
        },
      ),
    );
  }
}
