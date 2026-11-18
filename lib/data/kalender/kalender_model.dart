class KalenderAkademikModel {
  final int id;
  final String namaKegiatan;
  final String keterangan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final DateTime? dibuat;

  const KalenderAkademikModel({
    required this.id,
    required this.namaKegiatan,
    this.keterangan = '',
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.dibuat,
  });

  factory KalenderAkademikModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return KalenderAkademikModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaKegiatan: json['nama_kegiatan'] as String? ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      tanggalMulai:
          DateTime.tryParse(json['tanggal_mulai']?.toString() ?? '') ?? now,
      tanggalSelesai:
          DateTime.tryParse(json['tanggal_selesai']?.toString() ?? '') ?? now,
      dibuat: DateTime.tryParse(json['dibuat']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama_kegiatan': namaKegiatan,
    'keterangan': keterangan,
    'tanggal_mulai': tanggalMulai.toIso8601String(),
    'tanggal_selesai': tanggalSelesai.toIso8601String(),
    if (dibuat != null) 'dibuat': dibuat!.toIso8601String(),
  };
}

class AgendaItemModel {
  final DateTime date;
  final DateTime? endDate;
  final String heading;
  final String title;
  final String description;
  final String time;

  const AgendaItemModel({
    required this.date,
    this.endDate,
    required this.heading,
    required this.title,
    this.description = '',
    required this.time,
  });
}

class CreateAgendaPayload {
  final String namaKegiatan;
  final String keterangan;
  final String tanggalMulai;
  final String tanggalSelesai;

  const CreateAgendaPayload({
    required this.namaKegiatan,
    this.keterangan = '',
    required this.tanggalMulai,
    String? tanggalSelesai,
  }) : tanggalSelesai = tanggalSelesai ?? tanggalMulai;

  Map<String, dynamic> toJson() => {
    'nama_kegiatan': namaKegiatan,
    'keterangan': keterangan,
    'tanggal_mulai': tanggalMulai,
    'tanggal_selesai': tanggalSelesai,
  };
}
