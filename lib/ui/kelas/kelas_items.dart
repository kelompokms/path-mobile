import 'package:path_mobile/data/kelas/kelas_model.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

class MateriData {
  final int? id;
  final String title;
  final String author;
  final DateTime postedAt;
  final String description;
  final List<LampiranItem> lampiran;

  const MateriData({
    this.id,
    required this.title,
    required this.author,
    required this.postedAt,
    required this.description,
    this.lampiran = const [],
  });

  factory MateriData.fromModel(PostinganModel model, {String? author}) {
    return MateriData(
      id: model.id,
      title: model.judul,
      author: author ?? 'Pengajar',
      postedAt: model.dibuat,
      description: model.deskripsi,
      lampiran: model.lampiranItems,
    );
  }
}

class TugasData {
  final int? id;
  final String title;
  final String author;
  final DateTime postedAt;
  final DateTime dueDate;
  final int points = 100;
  final String description;
  String status = 'Ditugaskan';
  int? score;
  final List<LampiranItem> lampiran;
  final List<LampiranItem> submissionLampiran;
  final List<LampiranItem> draftLampiran;

  TugasData({
    this.id,
    required this.title,
    required this.author,
    required this.postedAt,
    required this.dueDate,
    required this.description,
    this.score,
    List<LampiranItem>? lampiran,
    List<LampiranItem>? submissionLampiran,
    List<LampiranItem>? draftLampiran,
  }) : lampiran = lampiran ?? [],
       submissionLampiran = submissionLampiran ?? [],
       draftLampiran = draftLampiran ?? [];

  bool get isSubmitted =>
      status == 'Dikumpulkan' ||
      status == 'Ditandai Sebagai Selesai' ||
      status == 'Dinilai';

  factory TugasData.fromModel(PostinganModel model, {String? author}) {
    return TugasData(
      id: model.id,
      title: model.judul,
      author: author ?? 'Pengajar',
      postedAt: model.dibuat,
      dueDate: model.dibuat.add(const Duration(days: 7)),
      description: model.deskripsi,
      lampiran: List<LampiranItem>.from(model.lampiranItems),
    );
  }
}
