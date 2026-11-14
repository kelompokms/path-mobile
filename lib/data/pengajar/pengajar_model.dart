export 'package:path_mobile/data/kelas/kelas_model.dart';

class AdminModel {
  final int id;
  final String nama;
  final String email;
  final String phone;
  final String profilePicture;
  final bool admin;
  final String dibuat;

  const AdminModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.phone,
    required this.profilePicture,
    required this.admin,
    required this.dibuat,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone']?.toString() ?? '',
      profilePicture: json['profile_picture']?.toString() ?? '',
      admin: json['admin'] as bool? ?? false,
      dibuat: json['dibuat']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'email': email,
    'phone': phone,
    'profile_picture': profilePicture,
    'admin': admin,
    'dibuat': dibuat,
  };
}

class GuruModel {
  final int kelasId;
  final String namaKelas;
  final int penggunaId;
  final String namaPengguna;

  const GuruModel({
    required this.kelasId,
    required this.namaKelas,
    required this.penggunaId,
    required this.namaPengguna,
  });

  factory GuruModel.fromJson(Map<String, dynamic> json) {
    return GuruModel(
      kelasId: (json['kelas_id'] as num?)?.toInt() ?? 0,
      namaKelas: json['nama_kelas'] as String? ?? '',
      penggunaId: (json['pengguna_id'] as num?)?.toInt() ?? 0,
      namaPengguna: json['nama_pengguna'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'kelas_id': kelasId,
    'nama_kelas': namaKelas,
    'pengguna_id': penggunaId,
    'nama_pengguna': namaPengguna,
  };
}

class UpdateGuruPayload {
  final bool roleGuru;

  const UpdateGuruPayload({required this.roleGuru});

  Map<String, dynamic> toJson() => {
    'role_guru': roleGuru,
  };
}
