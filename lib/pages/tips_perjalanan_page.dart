import 'package:flutter/material.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class TipsPerjalananPage extends StatelessWidget {
  const TipsPerjalananPage({super.key});

  static const tips = [
    (
      Icons.badge_outlined,
      'Dokumen perjalanan',
      'Periksa paspor, visa, tiket, identitas, dan dokumen dari penyelenggara. Simpan salinan digital secara aman dan pisahkan dari dokumen asli.',
    ),
    (
      Icons.backpack_outlined,
      'Barang bawaan',
      'Siapkan pakaian ihram atau pakaian ibadah, alas kaki yang nyaman, obat pribadi yang diresepkan, perlengkapan mandi, dan tas kecil untuk kebutuhan harian.',
    ),
    (
      Icons.water_drop_outlined,
      'Jaga kondisi tubuh',
      'Minum air secara berkala, beristirahat cukup, gunakan perlindungan dari panas, dan jangan memaksakan aktivitas ketika merasa tidak sehat.',
    ),
    (
      Icons.groups_outlined,
      'Tetap bersama rombongan',
      'Catat nama hotel, nomor pembimbing, dan titik berkumpul. Jika terpisah, hubungi petugas atau pembimbing dan ikuti prosedur rombongan.',
    ),
    (
      Icons.directions_walk_outlined,
      'Atur tenaga saat beribadah',
      'Gunakan alas kaki yang nyaman di luar area yang mengharuskan dilepas. Berjalan sesuai kemampuan dan manfaatkan fasilitas yang tersedia bila diperlukan.',
    ),
    (
      Icons.language_outlined,
      'Hormati aturan setempat',
      'Ikuti arahan petugas, perhatikan jadwal rombongan, jaga kebersihan, dan hormati jamaah lain dari berbagai negara.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Tips Perjalanan'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: safarLightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Persiapan sederhana dapat membantu perjalanan umrah lebih tertata. Sesuaikan kebutuhan dengan kondisi diri dan arahan penyelenggara perjalanan.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          ...tips.map(
            (tip) => Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: safarLightGreen,
                  child: Icon(tip.$1, color: safarGreen),
                ),
                title: Text(
                  tip.$2,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(tip.$3, style: const TextStyle(height: 1.45)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
