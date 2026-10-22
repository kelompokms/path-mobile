class ClassModel {
  final String title; // "Mapel 1"
  final String grade; // "Kelas X"
  final String? teacher; // boleh kosong (tab Pengajar tidak menampilkan guru)
  final String? imagePath; // boleh kosong, nanti diisi path asset

  const ClassModel({
    required this.title,
    required this.grade,
    this.teacher,
    this.imagePath,
  });
}