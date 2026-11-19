import 'package:flutter/material.dart';

/// Taksonomi 8 kategori resmi Finku sesuai Bab 5.2.1 GEMINI.md (`TC-AI-04`).
class CategoryTaxonomy {
  CategoryTaxonomy._();

  static const String makananMinuman = 'Makanan & Minuman';
  static const String transportasi = 'Transportasi';
  static const String belanjaHarian = 'Belanja Harian';
  static const String tagihanUtilitas = 'Tagihan & Utilitas';
  static const String hiburanGayaHidup = 'Hiburan & Gaya Hidup';
  static const String kesehatan = 'Kesehatan';
  static const String pendidikan = 'Pendidikan';
  static const String lainnya = 'Lainnya';

  static const List<String> validCategories = [
    makananMinuman,
    transportasi,
    belanjaHarian,
    tagihanUtilitas,
    hiburanGayaHidup,
    kesehatan,
    pendidikan,
    lainnya,
  ];

  static const Map<String, Color> categoryColors = {
    makananMinuman: Color(0xFF006B2C),
    transportasi: Color(0xFF0051D5),
    belanjaHarian: Color(0xFFF59E0B),
    tagihanUtilitas: Color(0xFF8B5CF6),
    hiburanGayaHidup: Color(0xFFEC4899),
    kesehatan: Color(0xFF0D9488),
    pendidikan: Color(0xFF6366F1),
    lainnya: Color(0xFF64748B),
  };

  static const Map<String, IconData> categoryIcons = {
    makananMinuman: Icons.restaurant_rounded,
    transportasi: Icons.directions_car_rounded,
    belanjaHarian: Icons.shopping_basket_rounded,
    tagihanUtilitas: Icons.bolt_rounded,
    hiburanGayaHidup: Icons.theater_comedy_rounded,
    kesehatan: Icons.medical_services_rounded,
    pendidikan: Icons.school_rounded,
    lainnya: Icons.category_rounded,
  };

  static Color colorFor(String category) =>
      categoryColors[normalize(category)] ?? const Color(0xFF64748B);

  static IconData iconFor(String category) =>
      categoryIcons[normalize(category)] ?? Icons.category_rounded;

  /// Menormalisasi string kategori atau nama item agar selalu valid dalam 8 kategori baku.
  static String normalize(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final valid in validCategories) {
      if (valid.toLowerCase() == lower) return valid;
    }

    if (_matchesAny(lower, [
      'makan',
      'minum',
      'kopi',
      'coffee',
      'starbucks',
      'resto',
      'warteg',
      'bakso',
      'ayam',
      'nasi',
      'sushi',
      'roti',
      'boba',
      'fnb',
      'sarapan',
      'lunch',
      'dinner',
      'jajan',
    ])) {
      return makananMinuman;
    }
    if (_matchesAny(lower, [
      'transport',
      'bensin',
      'pertamax',
      'pertalite',
      'parkir',
      'tol',
      'ojek',
      'gojek',
      'goride',
      'grab',
      'taksi',
      'kereta',
      'mrt',
      'bus',
      'tiket',
      'krl',
    ])) {
      return transportasi;
    }
    if (_matchesAny(lower, [
      'belanja',
      'indomaret',
      'alfamart',
      'superindo',
      'minimarket',
      'sembako',
      'galon',
      'aqua',
      'gas',
      'lpg',
      'sabun',
      'deterjen',
      'indomie',
      'susu',
      'grocer',
    ])) {
      return belanjaHarian;
    }
    if (_matchesAny(lower, [
      'tagihan',
      'listrik',
      'pln',
      'token',
      'air',
      'pdam',
      'internet',
      'wifi',
      'indihome',
      'pulsa',
      'kuota',
      'sewa',
      'kos',
      'cicilan',
      'bpjs',
    ])) {
      return tagihanUtilitas;
    }
    if (_matchesAny(lower, [
      'hiburan',
      'bioskop',
      'xxi',
      'cgv',
      'netflix',
      'spotify',
      'game',
      'konser',
      'rekreasi',
      'wisata',
      'baju',
      'fashion',
      'nongkrong',
    ])) {
      return hiburanGayaHidup;
    }
    if (_matchesAny(lower, [
      'kesehatan',
      'obat',
      'apotek',
      'kimia farma',
      'dokter',
      'klinik',
      'rumah sakit',
      'vitamin',
      'halodoc',
    ])) {
      return kesehatan;
    }
    if (_matchesAny(lower, [
      'pendidikan',
      'buku',
      'kuliah',
      'spp',
      'kursus',
      'les',
      'sekolah',
      'gramedia',
      'seminar',
    ])) {
      return pendidikan;
    }
    return lainnya;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }
}
