import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/ui/core/post_card.dart';

class KelasModel {
  final int id;
  final String nama;
  final int tingkat;
  final String tahunAjaran;
  final String kodeKelas;
  final int pengampu;
  final String dibuat;

  KelasModel({
    required this.id,
    required this.nama,
    required this.tingkat,
    required this.tahunAjaran,
    required this.kodeKelas,
    int? pengampu,
    int? pembuat,
    required this.dibuat,
  }) : pengampu = pengampu ?? pembuat ?? 0;

  int get pembuat => pengampu;

  String get gradeLabel {
    switch (tingkat) {
      case 10:
        return 'Kelas X';
      case 11:
        return 'Kelas XI';
      case 12:
        return 'Kelas XII';
      default:
        return 'Kelas $tingkat';
    }
  }

  ClassItem toClassItem({String? teacher, int? coverIndex}) {
    return ClassItem(
      title: nama,
      grade: gradeLabel,
      teacher: teacher,
      coverIndex: coverIndex ?? id,
      code: kodeKelas,
    );
  }

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    return KelasModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      tingkat: (json['tingkat'] as num?)?.toInt() ?? 10,
      tahunAjaran: json['tahun_ajaran'] as String? ?? '',
      kodeKelas: json['kode_kelas'] as String? ?? '',
      pengampu: (json['pengampu'] as num? ?? json['pembuat'] as num?)?.toInt() ?? 0,
      dibuat: json['dibuat']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'tingkat': tingkat,
    'tahun_ajaran': tahunAjaran,
    'kode_kelas': kodeKelas,
    'pengampu': pengampu,
    'dibuat': dibuat,
  };
}

class CreateKelasRequest {
  final String nama;
  final int tingkat;
  final String tahunAjaran;

  const CreateKelasRequest({
    required this.nama,
    required this.tingkat,
    required this.tahunAjaran,
  });

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'tingkat': tingkat,
    'tahun_ajaran': tahunAjaran,
  };
}

class PostinganModel {
  static const int tipeTugas = 1;
  static const int tipeMateri = 2;

  final int id;
  final String judul;
  final String deskripsi;
  final List<String> lampiran;
  final String? mataPelajaran;
  final int penggunaId;
  final int kelasId;
  final int tipeId;
  final DateTime dibuat;

  PostinganModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.lampiran,
    this.mataPelajaran,
    required this.penggunaId,
    required this.kelasId,
    required this.tipeId,
    required this.dibuat,
  });

  List<LampiranItem> get lampiranItems {
    return lampiran.map((raw) {
      final isHttp = raw.startsWith('http://') || raw.startsWith('https://');
      if (isHttp && !raw.contains('/uploads/')) {
        return LampiranItem(name: 'Link', detail: raw, isLink: true);
      }
      final fileName = raw.split('/').last;
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toUpperCase()
          : 'FILE';
      return LampiranItem(name: fileName, detail: ext);
    }).toList();
  }

  factory PostinganModel.fromJson(Map<String, dynamic> json) {
    final rawLampiran = json['lampiran'];
    final List<String> parsedLampiran = rawLampiran is List
        ? rawLampiran.map((e) => e.toString()).toList()
        : <String>[];

    final rawDibuat = json['dibuat']?.toString();
    final parsedDibuat =
        (rawDibuat != null ? DateTime.tryParse(rawDibuat) : null) ??
        DateTime.now();

    return PostinganModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      judul: json['judul'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      lampiran: parsedLampiran,
      mataPelajaran: json['mata_pelajaran'] as String?,
      penggunaId: (json['pengguna_id'] as num?)?.toInt() ?? 0,
      kelasId: (json['kelas_id'] as num?)?.toInt() ?? 0,
      tipeId: (json['tipe_id'] as num?)?.toInt() ?? 1,
      dibuat: parsedDibuat,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': judul,
    'deskripsi': deskripsi,
    'lampiran': lampiran,
    if (mataPelajaran != null) 'mata_pelajaran': mataPelajaran,
    'pengguna_id': penggunaId,
    'kelas_id': kelasId,
    'tipe_id': tipeId,
    'dibuat': dibuat.toIso8601String(),
  };
}

class CreatePostinganPayload {
  final String judul;
  final String deskripsi;
  final List<String> lampiran;
  final int tipe;

  const CreatePostinganPayload({
    required this.judul,
    this.deskripsi = '',
    this.lampiran = const [],
    required this.tipe,
  });

  Map<String, dynamic> toJson() => {
    'judul': judul,
    'deskripsi': deskripsi,
    if (lampiran.isNotEmpty) 'lampiran': lampiran,
    'tipe': tipe,
  };
}

class EditPostinganPayload {
  final String judul;
  final String deskripsi;
  final List<String>? lampiran;
  final int tipe;

  const EditPostinganPayload({
    required this.judul,
    this.deskripsi = '',
    this.lampiran,
    required this.tipe,
  });

  Map<String, dynamic> toJson() => {
    'judul': judul,
    'deskripsi': deskripsi,
    if (lampiran != null) 'lampiran': lampiran,
    'tipe': tipe,
  };
}

class TipePostinganModel {
  final int id;
  final String nama;

  const TipePostinganModel({
    required this.id,
    required this.nama,
  });

  factory TipePostinganModel.fromJson(Map<String, dynamic> json) {
    return TipePostinganModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
  };
}

class UploadedPostinganFile {
  final String nama;
  final String path;
  final int ukuran;

  const UploadedPostinganFile({
    required this.nama,
    required this.path,
    required this.ukuran,
  });

  factory UploadedPostinganFile.fromJson(Map<String, dynamic> json) {
    return UploadedPostinganFile(
      nama: json['nama'] as String? ?? '',
      path: json['path'] as String? ?? '',
      ukuran: (json['ukuran'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'path': path,
    'ukuran': ukuran,
  };
}

class UploadPostinganFilesResponse {
  final List<UploadedPostinganFile> files;

  const UploadPostinganFilesResponse({required this.files});

  factory UploadPostinganFilesResponse.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final list = rawFiles is List
        ? rawFiles
              .map(
                (e) =>
                    UploadedPostinganFile.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : <UploadedPostinganFile>[];
    return UploadPostinganFilesResponse(files: list);
  }
}
