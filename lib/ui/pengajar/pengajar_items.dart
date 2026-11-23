import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_mobile/data/pengajar/pengajar_model.dart';
import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/pengajar/pengajar_controller.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

void copyPengajarText(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<ClassItem?> editKelasWithDialog(
  BuildContext context,
  ClassItem classData,
  PengajarController? controller,
) async {
  final result = await showEditKelasDialog(
    context,
    initialNama: classData.title,
    initialDeskripsi: classData.description,
  );
  if (result == null || !context.mounted) return null;

  if (controller != null) {
    final (updated, err) = await controller.editKelas(
      classData.code,
      nama: result.nama,
      deskripsi: result.deskripsi,
    );
    if (!context.mounted) return null;
    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return null;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Kelas berhasil diperbarui')),
      );
    if (updated != null) {
      return updated.toClassItem(
        teacher: classData.teacher,
        coverIndex: classData.coverIndex,
      );
    }
  }

  return classData.copyWith(
    title: result.nama,
    description: result.deskripsi,
  );
}

class MateriPengajar {
  int? id;
  String title;
  String description;
  final DateTime postedAt;
  List<LampiranItem> lampiran;

  MateriPengajar({
    this.id,
    required this.title,
    required this.description,
    required this.postedAt,
    List<LampiranItem>? lampiran,
  }) : lampiran = lampiran ?? [];

  factory MateriPengajar.fromModel(PostinganModel model) {
    return MateriPengajar(
      id: model.id,
      title: model.judul,
      description: model.deskripsi,
      postedAt: model.dibuat,
      lampiran: List<LampiranItem>.from(model.lampiranItems),
    );
  }
}

class TugasPengajar {
  int? id;
  String title;
  String description;
  DateTime postedAt;
  DateTime? dueDate;
  final int points = 100;
  bool acceptSubmissions;
  List<LampiranItem> lampiran;
  final List<PengumpulanItem> pengumpulan;

  TugasPengajar({
    this.id,
    required this.title,
    required this.description,
    required this.postedAt,
    this.dueDate,
    this.acceptSubmissions = true,
    List<LampiranItem>? lampiran,
    List<PengumpulanItem>? pengumpulan,
  }) : lampiran = lampiran ?? [],
       pengumpulan = pengumpulan ?? [];

  factory TugasPengajar.fromModel(PostinganModel model) {
    return TugasPengajar(
      id: model.id,
      title: model.judul,
      description: model.deskripsi,
      postedAt: model.dibuat,
      dueDate: model.tenggatWaktu,
      acceptSubmissions: model.menerimaKiriman,
      lampiran: List<LampiranItem>.from(model.lampiranItems),
    );
  }
}

class PengumpulanStatus {
  static const diserahkan = 'Diserahkan';
  static const terlambat = 'Terlambat';
  static const belumMengumpulkan = 'Belum Mengumpulkan';
  static const tidakMengumpulkan = 'Tidak Mengumpulkan';
  static const sudahDinilai = 'Sudah Dinilai';

  static const all = [
    diserahkan,
    terlambat,
    belumMengumpulkan,
    tidakMengumpulkan,
    sudahDinilai,
  ];

  static const filters = ['Semua', ...all];

  static String normalize(String raw) {
    switch (raw) {
      case 'Ditugaskan':
        return belumMengumpulkan;
      case 'Dinilai':
        return sudahDinilai;
      default:
        return raw;
    }
  }
}

class PengumpulanItem {
  final int? penggunaId;
  final String studentName;
  final String email;
  final String profilePicture;
  final String? fileName;
  final List<LampiranItem> lampiran;
  final DateTime? submittedAt;
  final bool isSubmitted;
  final bool isLate;
  String status;
  int? score;

  PengumpulanItem({
    this.penggunaId,
    required this.studentName,
    this.email = '',
    this.profilePicture = '',
    this.fileName,
    List<LampiranItem>? lampiran,
    this.submittedAt,
    bool? isSubmitted,
    bool? isLate,
    required String status,
    this.score,
  }) : lampiran = lampiran ?? const [],
       status = PengumpulanStatus.normalize(status),
       isLate = isLate ?? (status == PengumpulanStatus.terlambat),
       isSubmitted =
           isSubmitted ??
           (status != 'Ditugaskan' &&
               status != PengumpulanStatus.belumMengumpulkan &&
               status != PengumpulanStatus.tidakMengumpulkan);

  String get keyId =>
      penggunaId != null && penggunaId! > 0 ? 'u_$penggunaId' : studentName;

  bool get isMarkAsDone => isSubmitted && lampiran.isEmpty && fileName == null;
}
