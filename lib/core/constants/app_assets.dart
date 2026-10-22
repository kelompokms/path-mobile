class AppAssets {
  // Ilustrasi bagian home
  static const emptyClass = 'assets/images/illustrations/home.png';

  // Sampul kartu mapel
  static const covers = [
    'assets/images/covers/book.png',
    'assets/images/covers/devices.png',
    'assets/images/covers/globe.png',
    'assets/images/covers/graduation.png',
    'assets/images/covers/mikroskop.png',
    'assets/images/covers/ruler.png',
    'assets/images/covers/sepatu.png',
    'assets/images/covers/tools.png'
  ];


  // Ikon navigasi yang dibawah
  static const navItems = [
    NavIconAsset(
      label: 'Beranda',
      inactive: 'assets/icons/navbar_home.png',
      active: 'assets/icons/navbar_home_active.png',
    ),

    NavIconAsset(
      label: 'Pengajar',
      inactive: 'assets/icons/navbar_pengajar.png',
      active: 'assets/icons/navbar_pengajar_active.png',
    ),

    NavIconAsset(
      label: 'Kelas',
      inactive: 'assets/icons/navbar_kelas.png',
      active: 'assets/icons/navbar_kelas_active.png',
    ),

    NavIconAsset(
      label: 'Kalender',
      inactive: 'assets/icons/navbar_calendar.png',
      active: 'assets/icons/navbar_calendar_active.png',
    ),

    NavIconAsset(
      label: 'Profil',
      inactive: 'assets/icons/navbar_profil.png',
      active: 'assets/icons/navbar_profil_active.png',
    ),
  ];
}


// Formulir untuk satu menu navigasi
class NavIconAsset {
  final String label;
  final String inactive;
  final String active; 

  const NavIconAsset({
    required this.label,
    required this.inactive,
    required this.active,
  });
}