import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

export 'package:path_mobile/utils/lampiran_helper.dart'
    show UploadPostinganFilesResponse, UploadedPostinganFile;

class KelasModel {
  final int id;
  final String nama;
  final String deskripsi;
  final int tingkat;
  final String tahunAjaran;
  final String kodeKelas;
  final int pengampu;
  final String dibuat;
  final bool guru;

  KelasModel({
    required this.id,
    required this.nama,
    this.deskripsi = '',
    required this.tingkat,
    required this.tahunAjaran,
    required this.kodeKelas,
    int? pengampu,
    int? pembuat,
    required this.dibuat,
    this.guru = false,
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
      description: deskripsi,
      grade: gradeLabel,
      teacher: teacher,
      coverIndex: coverIndex ?? id,
      code: kodeKelas,
      isGuru: guru,
    );
  }

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    return KelasModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      tingkat: (json['tingkat'] as num?)?.toInt() ?? 10,
      tahunAjaran: json['tahun_ajaran'] as String? ?? '',
      kodeKelas: json['kode_kelas'] as String? ?? '',
      pengampu:
          (json['pengampu'] as num? ?? json['pembuat'] as num?)?.toInt() ?? 0,
      dibuat: json['dibuat']?.toString() ?? '',
      guru: json['guru'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'deskripsi': deskripsi,
    'tingkat': tingkat,
    'tahun_ajaran': tahunAjaran,
    'kode_kelas': kodeKelas,
    'pengampu': pengampu,
    'dibuat': dibuat,
    'guru': guru,
  };
}

class AnggotaKelasModel {
  final int penggunaId;
  final String nama;
  final String email;
  final String profilePicture;
  final bool guru;
  final String role;
  final DateTime? dibuat;

  const AnggotaKelasModel({
    required this.penggunaId,
    required this.nama,
    required this.email,
    this.profilePicture = '',
    required this.guru,
    String? role,
    this.dibuat,
  }) : role = role ?? (guru ? 'guru' : 'murid');

  bool get isGuru => guru;

  factory AnggotaKelasModel.fromJson(Map<String, dynamic> json) {
    final rawGuru = json['guru'] as bool?;
    final rawRole = (json['role'] as String?)?.toLowerCase().trim();
    final isGuru = rawGuru ?? (rawRole == 'guru');
    final rawDibuat = json['dibuat']?.toString();
    return AnggotaKelasModel(
      penggunaId:
          (json['pengguna_id'] as num? ?? json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
      guru: isGuru,
      role: rawRole ?? (isGuru ? 'guru' : 'murid'),
      dibuat: rawDibuat != null ? DateTime.tryParse(rawDibuat) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'pengguna_id': penggunaId,
    'nama': nama,
    'email': email,
    'profile_picture': profilePicture,
    'guru': guru,
    'role': role,
    if (dibuat != null) 'dibuat': dibuat!.toIso8601String(),
  };
}

class CreateKelasRequest {
  final String nama;
  final String deskripsi;
  final int tingkat;
  final String tahunAjaran;

  const CreateKelasRequest({
    required this.nama,
    this.deskripsi = '',
    required this.tingkat,
    required this.tahunAjaran,
  });

  Map<String, dynamic> toJson() => {
    'nama': nama,
    if (deskripsi.isNotEmpty) 'deskripsi': deskripsi,
    'tingkat': tingkat,
    'tahun_ajaran': tahunAjaran,
  };
}

class UpdateKelasRequest {
  final String nama;
  final String deskripsi;

  const UpdateKelasRequest({
    required this.nama,
    required this.deskripsi,
  });

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'deskripsi': deskripsi,
  };
}

class PostinganModel {
  static const int tipeTugas = 1;
  static const int tipeMateri = 2;

  final int id;
  final String judul;
  final String deskripsi;
  final List<String> lampiran;
  final int penggunaId;
  final int kelasId;
  final int tipeId;
  final DateTime dibuat;

  PostinganModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.lampiran,
    required this.penggunaId,
    required this.kelasId,
    required this.tipeId,
    required this.dibuat,
  });

  List<LampiranItem> get lampiranItems {
    return lampiran.map((raw) {
      final trimmed = raw.trim();
      final lower = trimmed.toLowerCase();
      final isHttp =
          lower.startsWith('http://') || lower.startsWith('https://');
      final isUpload = isLampiranUploadPath(trimmed);
      if (isHttp && !isUpload) {
        return LampiranItem(
          name: 'Link',
          detail: trimmed,
          isLink: true,
          url: trimmed,
        );
      }
      final uri = Uri.tryParse(trimmed);
      final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
      final fileName = (segments != null && segments.isNotEmpty)
          ? segments.last
          : trimmed.split('/').last;
      final ext = extractLampiranExtension(fileName);
      return LampiranItem(
        name: fileName,
        detail: ext.isEmpty ? 'FILE' : ext.toUpperCase(),
        url: (isHttp || isUpload) ? trimmed : null,
      );
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
