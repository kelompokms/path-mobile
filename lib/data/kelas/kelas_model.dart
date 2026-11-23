import 'package:path_mobile/ui/core/class_card.dart';
import 'package:path_mobile/utils/date_time_helper.dart';
import 'package:path_mobile/utils/lampiran_helper.dart';

export 'package:path_mobile/utils/lampiran_helper.dart'
    show UploadPostinganFilesResponse, UploadedPostinganFile;

class KelasModel {
  final int id;
  final String nama;
  final String mapel;
  final String deskripsi;
  final int tingkat;
  final String tahunAjaran;
  final String kodeKelas;
  final int pengampu;
  final String namaPengampu;
  final String dibuat;
  final bool guru;

  KelasModel({
    required this.id,
    required this.nama,
    this.mapel = '',
    this.deskripsi = '',
    required this.tingkat,
    required this.tahunAjaran,
    required this.kodeKelas,
    int? pengampu,
    int? pembuat,
    this.namaPengampu = '',
    required this.dibuat,
    this.guru = false,
  }) : pengampu = pengampu ?? pembuat ?? 0;

  int get pembuat => pengampu;

  String get displayTitle => mapel.trim().isNotEmpty ? mapel.trim() : nama;

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
    final trimmedMapel = mapel.trim();
    final trimmedNama = nama.trim();
    final hasMapel = trimmedMapel.isNotEmpty;
    final resolvedTeacher = (teacher != null && teacher.trim().isNotEmpty)
        ? teacher
        : (namaPengampu.trim().isNotEmpty ? namaPengampu.trim() : null);
    return ClassItem(
      title: hasMapel ? trimmedMapel : trimmedNama,
      description: deskripsi,
      grade: hasMapel
          ? (trimmedNama.isNotEmpty ? trimmedNama : gradeLabel)
          : gradeLabel,
      teacher: resolvedTeacher,
      coverIndex: coverIndex ?? id,
      code: kodeKelas,
      isGuru: guru,
    );
  }

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    return KelasModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      mapel: json['mapel'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      tingkat: (json['tingkat'] as num?)?.toInt() ?? 10,
      tahunAjaran: json['tahun_ajaran'] as String? ?? '',
      kodeKelas: json['kode_kelas'] as String? ?? '',
      pengampu:
          (json['pengampu'] as num? ?? json['pembuat'] as num?)?.toInt() ?? 0,
      namaPengampu: json['nama_pengampu'] as String? ?? '',
      dibuat: json['dibuat']?.toString() ?? '',
      guru: json['guru'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'mapel': mapel,
    'deskripsi': deskripsi,
    'tingkat': tingkat,
    'tahun_ajaran': tahunAjaran,
    'kode_kelas': kodeKelas,
    'pengampu': pengampu,
    if (namaPengampu.isNotEmpty) 'nama_pengampu': namaPengampu,
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
  final bool utama;
  final String role;
  final DateTime? dibuat;

  const AnggotaKelasModel({
    required this.penggunaId,
    required this.nama,
    required this.email,
    this.profilePicture = '',
    required this.guru,
    this.utama = false,
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
      utama: isGuru && (json['utama'] as bool? ?? false),
      role: rawRole ?? (isGuru ? 'guru' : 'murid'),
      dibuat: parseGmt7DateTime(rawDibuat),
    );
  }

  Map<String, dynamic> toJson() => {
    'pengguna_id': penggunaId,
    'nama': nama,
    'email': email,
    'profile_picture': profilePicture,
    'guru': guru,
    'utama': utama,
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
  final bool menerimaKiriman;
  final DateTime? tenggatWaktu;

  PostinganModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.lampiran,
    required this.penggunaId,
    required this.kelasId,
    required this.tipeId,
    required this.dibuat,
    this.menerimaKiriman = true,
    this.tenggatWaktu,
  });

  List<LampiranItem> get lampiranItems => parseLampiranItems(lampiran);

  factory PostinganModel.fromJson(Map<String, dynamic> json) {
    final rawLampiran = json['lampiran'];
    final List<String> parsedLampiran = rawLampiran is List
        ? rawLampiran.map((e) => e.toString()).toList()
        : <String>[];

    final rawDibuat = json['dibuat']?.toString();
    final parsedDibuat = parseGmt7DateTime(rawDibuat) ?? nowGmt7();
    final parsedTenggat = parseGmt7DateTime(json['tenggat_waktu']?.toString());

    return PostinganModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      judul: json['judul'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      lampiran: parsedLampiran,
      penggunaId: (json['pengguna_id'] as num?)?.toInt() ?? 0,
      kelasId: (json['kelas_id'] as num?)?.toInt() ?? 0,
      tipeId: (json['tipe_id'] as num?)?.toInt() ?? 1,
      dibuat: parsedDibuat,
      menerimaKiriman: json['menerima_kiriman'] as bool? ?? true,
      tenggatWaktu: parsedTenggat,
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
    'menerima_kiriman': menerimaKiriman,
    if (tenggatWaktu != null) 'tenggat_waktu': formatIsoGmt7(tenggatWaktu!),
  };
}

class CreatePostinganPayload {
  final String judul;
  final String deskripsi;
  final List<String> lampiran;
  final int tipe;
  final DateTime? tenggatWaktu;

  const CreatePostinganPayload({
    required this.judul,
    this.deskripsi = '',
    this.lampiran = const [],
    required this.tipe,
    this.tenggatWaktu,
  });

  Map<String, dynamic> toJson() => {
    'judul': judul,
    'deskripsi': deskripsi,
    if (lampiran.isNotEmpty) 'lampiran': lampiran,
    'tipe': tipe,
    if (tenggatWaktu != null) 'tenggat_waktu': formatIsoGmt7(tenggatWaktu!),
  };
}

class EditPostinganPayload {
  final String judul;
  final String deskripsi;
  final List<String>? lampiran;
  final int tipe;
  final bool? menerimaKiriman;
  final DateTime? tenggatWaktu;
  final bool hapusTenggat;

  const EditPostinganPayload({
    required this.judul,
    this.deskripsi = '',
    this.lampiran,
    required this.tipe,
    this.menerimaKiriman,
    this.tenggatWaktu,
    this.hapusTenggat = false,
  });

  Map<String, dynamic> toJson() => {
    'judul': judul,
    'deskripsi': deskripsi,
    if (lampiran != null) 'lampiran': lampiran,
    'tipe': tipe,
    if (menerimaKiriman != null) 'menerima_kiriman': menerimaKiriman,
    if (tenggatWaktu != null && !hapusTenggat)
      'tenggat_waktu': formatIsoGmt7(tenggatWaktu!),
    if (hapusTenggat) 'hapus_tenggat': true,
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

class PengumpulanTugasModel {
  final int id;
  final int postinganId;
  final int penggunaId;
  final bool submitted;
  final List<String> lampiran;
  final int? nilai;
  final DateTime? dibuat;

  const PengumpulanTugasModel({
    this.id = 0,
    required this.postinganId,
    this.penggunaId = 0,
    required this.submitted,
    this.lampiran = const [],
    this.nilai,
    this.dibuat,
  });

  List<LampiranItem> get lampiranItems => parseLampiranItems(lampiran);

  factory PengumpulanTugasModel.fromJson(Map<String, dynamic> json) {
    final rawLampiran = json['lampiran'];
    final parsedLampiran = rawLampiran is List
        ? rawLampiran.map((e) => e.toString()).toList()
        : <String>[];
    final rawDibuat = json['dibuat']?.toString();
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final submitted = json['submitted'] as bool? ?? (id > 0);
    return PengumpulanTugasModel(
      id: id,
      postinganId: (json['postingan_id'] as num?)?.toInt() ?? 0,
      penggunaId: (json['pengguna_id'] as num?)?.toInt() ?? 0,
      submitted: submitted,
      lampiran: parsedLampiran,
      nilai: (json['nilai'] as num?)?.toInt(),
      dibuat: parseGmt7DateTime(rawDibuat),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'postingan_id': postinganId,
    'pengguna_id': penggunaId,
    'submitted': submitted,
    'lampiran': lampiran,
    if (nilai != null) 'nilai': nilai,
    if (dibuat != null) 'dibuat': dibuat!.toIso8601String(),
  };
}

class PengumpulanMuridModel {
  final int id;
  final int postinganId;
  final int penggunaId;
  final String nama;
  final String email;
  final String profilePicture;
  final List<String> lampiran;
  final int? nilai;
  final DateTime? dibuat;

  const PengumpulanMuridModel({
    required this.id,
    required this.postinganId,
    required this.penggunaId,
    required this.nama,
    required this.email,
    this.profilePicture = '',
    this.lampiran = const [],
    this.nilai,
    this.dibuat,
  });

  List<LampiranItem> get lampiranItems => parseLampiranItems(lampiran);

  bool get isMarkAsDone => lampiran.isEmpty;

  factory PengumpulanMuridModel.fromJson(Map<String, dynamic> json) {
    final rawLampiran = json['lampiran'];
    final parsedLampiran = rawLampiran is List
        ? rawLampiran.map((e) => e.toString()).toList()
        : <String>[];
    final rawDibuat = json['dibuat']?.toString();
    return PengumpulanMuridModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postinganId: (json['postingan_id'] as num?)?.toInt() ?? 0,
      penggunaId: (json['pengguna_id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
      lampiran: parsedLampiran,
      nilai: (json['nilai'] as num?)?.toInt(),
      dibuat: parseGmt7DateTime(rawDibuat),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'postingan_id': postinganId,
    'pengguna_id': penggunaId,
    'nama': nama,
    'email': email,
    'profile_picture': profilePicture,
    'lampiran': lampiran,
    if (nilai != null) 'nilai': nilai,
    if (dibuat != null) 'dibuat': dibuat!.toIso8601String(),
  };
}
