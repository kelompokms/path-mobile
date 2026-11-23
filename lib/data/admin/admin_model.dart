import 'package:path_mobile/ui/core/class_card.dart';

/// Represents a school teacher or student returned by `/admin/pengguna`.
class AdminPenggunaModel {
  final int id;
  final String nama;
  final String email;
  final String phone;
  final String profilePicture;
  final String role;
  final List<String> kelas;

  const AdminPenggunaModel({
    required this.id,
    required this.nama,
    required this.email,
    this.phone = '',
    this.profilePicture = '',
    required this.role,
    this.kelas = const [],
  });

  bool get isGuru => role.toLowerCase() == 'guru';

  factory AdminPenggunaModel.fromJson(
    Map<String, dynamic> json, {
    String fallbackRole = 'murid',
  }) {
    final rawKelas = json['kelas'];
    final parsedKelas = rawKelas is List
        ? rawKelas
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    return AdminPenggunaModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
      role: (json['role'] as String?)?.trim().isNotEmpty == true
          ? (json['role'] as String).trim().toLowerCase()
          : fallbackRole,
      kelas: parsedKelas,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'email': email,
    'phone': phone,
    'profile_picture': profilePicture,
    'role': role,
    'kelas': kelas,
  };
}

/// Grouped teacher and student lists returned by `/admin/pengguna`.
class AdminGuruMuridData {
  final List<AdminPenggunaModel> guru;
  final List<AdminPenggunaModel> murid;

  const AdminGuruMuridData({required this.guru, required this.murid});

  factory AdminGuruMuridData.fromJson(Map<String, dynamic> json) {
    final rawGuru = json['guru'] as List<dynamic>? ?? const <dynamic>[];
    final rawMurid = json['murid'] as List<dynamic>? ?? const <dynamic>[];
    return AdminGuruMuridData(
      guru: rawGuru
          .whereType<Map<String, dynamic>>()
          .map((e) => AdminPenggunaModel.fromJson(e, fallbackRole: 'guru'))
          .toList(),
      murid: rawMurid
          .whereType<Map<String, dynamic>>()
          .map((e) => AdminPenggunaModel.fromJson(e, fallbackRole: 'murid'))
          .toList(),
    );
  }
}

/// Represents a school class entry returned by `/admin/kelas`.
class AdminKelasModel {
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

  const AdminKelasModel({
    required this.id,
    required this.nama,
    this.mapel = '',
    this.deskripsi = '',
    required this.tingkat,
    required this.tahunAjaran,
    required this.kodeKelas,
    this.pengampu = 0,
    this.namaPengampu = '',
    this.dibuat = '',
  });

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

  ClassItem toClassItem({int? coverIndex}) {
    final trimmedMapel = mapel.trim();
    final trimmedNama = nama.trim();
    final hasMapel = trimmedMapel.isNotEmpty;
    return ClassItem(
      title: hasMapel ? trimmedMapel : trimmedNama,
      description: deskripsi,
      grade: hasMapel
          ? (trimmedNama.isNotEmpty ? trimmedNama : gradeLabel)
          : (tahunAjaran.isNotEmpty
                ? '$gradeLabel • $tahunAjaran'
                : gradeLabel),
      teacher: namaPengampu.isNotEmpty
          ? 'Pengampu: $namaPengampu'
          : 'Pengampu: Belum ditentukan',
      coverIndex: coverIndex ?? id,
      code: kodeKelas,
      isGuru: false,
    );
  }

  factory AdminKelasModel.fromJson(Map<String, dynamic> json) {
    return AdminKelasModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      mapel: json['mapel'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      tingkat: (json['tingkat'] as num?)?.toInt() ?? 10,
      tahunAjaran: json['tahun_ajaran'] as String? ?? '',
      kodeKelas: json['kode_kelas'] as String? ?? '',
      pengampu: (json['pengampu'] as num?)?.toInt() ?? 0,
      namaPengampu: json['nama_pengampu'] as String? ?? '',
      dibuat: json['dibuat']?.toString() ?? '',
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
    'nama_pengampu': namaPengampu,
    'dibuat': dibuat,
  };
}

/// Token budget & free-tier quota telemetry returned by `GET /ai/ops/usage`.
class AdminAiOpsUsageModel {
  final int budgetLimit;
  final int budgetUsed;
  final int budgetRemaining;
  final double spentUsd;
  final int freeUsed;
  final int freeLimit;
  final int freeRemaining;

  const AdminAiOpsUsageModel({
    this.budgetLimit = 0,
    this.budgetUsed = 0,
    this.budgetRemaining = 0,
    this.spentUsd = 0,
    this.freeUsed = 0,
    this.freeLimit = 0,
    this.freeRemaining = 0,
  });

  factory AdminAiOpsUsageModel.fromJson(Map<String, dynamic> json) {
    final budget = json['budget'] is Map<String, dynamic>
        ? json['budget'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final free = json['free_quota'] is Map<String, dynamic>
        ? json['free_quota'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return AdminAiOpsUsageModel(
      budgetLimit: (budget['limit'] as num?)?.toInt() ?? 0,
      budgetUsed: (budget['used'] as num?)?.toInt() ?? 0,
      budgetRemaining: (budget['remaining'] as num?)?.toInt() ?? 0,
      spentUsd: (budget['spent_usd'] as num?)?.toDouble() ?? 0,
      freeUsed: (free['used'] as num?)?.toInt() ?? 0,
      freeLimit: (free['limit'] as num?)?.toInt() ?? 0,
      freeRemaining: (free['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
