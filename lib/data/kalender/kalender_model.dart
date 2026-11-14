class KalenderAkademikModel {
  final int id;
  final String namaKegiatan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final DateTime? dibuat;

  const KalenderAkademikModel({
    required this.id,
    required this.namaKegiatan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.dibuat,
  });

  factory KalenderAkademikModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return KalenderAkademikModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaKegiatan: json['nama_kegiatan'] as String? ?? '',
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
    'tanggal_mulai': tanggalMulai.toIso8601String(),
    'tanggal_selesai': tanggalSelesai.toIso8601String(),
    if (dibuat != null) 'dibuat': dibuat!.toIso8601String(),
  };
}

class AgendaItemModel {
  final DateTime date;
  final String heading;
  final String title;
  final String time;

  const AgendaItemModel({
    required this.date,
    required this.heading,
    required this.title,
    required this.time,
  });
}
