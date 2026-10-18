import 'package:flutter/material.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class TataCaraUmrahPage extends StatelessWidget {
  const TataCaraUmrahPage({super.key});

  static const steps = [
    {
      'title': '1. Persiapan dan Ihram',
      'description': 'Bersiaplah sebelum melewati miqat. Mandi dan membersihkan diri dianjurkan jika memungkinkan, lalu kenakan pakaian ihram sesuai ketentuan. Niat umrah dilakukan ketika memulai ihram di miqat.',
      'note': 'Ketentuan pakaian ihram berbeda bagi laki-laki dan perempuan. Tanyakan kepada pembimbing jika ragu.',
    },
    {
      'title': '2. Membaca Talbiyah',
      'description': 'Setelah berniat, jamaah dianjurkan memperbanyak talbiyah selama perjalanan menuju Masjidil Haram hingga memasuki rangkaian tawaf sesuai tuntunan yang diikuti.',
      'note': 'Ikuti arahan pembimbing rombongan mengenai waktu berhenti membaca talbiyah.',
    },
    {
      'title': '3. Tawaf',
      'description': 'Tawaf dilakukan dengan mengelilingi Ka’bah sebanyak tujuh putaran, dimulai sejajar Hajar Aswad dan berakhir di titik tersebut. Ka’bah berada di sebelah kiri jamaah.',
      'note': 'Utamakan keselamatan dan kelancaran. Tidak perlu memaksakan diri menyentuh atau mencium Hajar Aswad.',
    },
    {
      'title': '4. Salat dan Minum Zamzam',
      'description': 'Setelah tawaf, jamaah dapat melaksanakan salat sunah jika memungkinkan dan tidak mengganggu arus jamaah, kemudian minum air Zamzam.',
      'note': 'Lokasi dan kondisi Masjidil Haram dapat berubah. Ikuti petunjuk petugas setempat.',
    },
    {
      'title': '5. Sa’i',
      'description': 'Sa’i dilakukan dengan berjalan antara Safa dan Marwah sebanyak tujuh perjalanan, dimulai dari Safa dan berakhir di Marwah.',
      'note': 'Sesuaikan kecepatan dengan kondisi fisik. Lansia atau jamaah yang membutuhkan bantuan dapat mengikuti fasilitas yang tersedia.',
    },
    {
      'title': '6. Tahallul',
      'description': 'Setelah menyelesaikan sa’i, jamaah melakukan tahallul dengan memotong atau mencukur rambut sesuai ketentuan yang berlaku. Setelah itu, rangkaian umrah selesai.',
      'note': 'Jika ada kondisi khusus atau keraguan mengenai sahnya ibadah, tanyakan kepada pembimbing ibadah yang kompeten.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Tata Cara Umrah'),
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
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, color: safarGreen, size: 34),
                SizedBox(height: 10),
                Text(
                  'Panduan Ringkas Umrah',
                  style: TextStyle(
                    color: safarGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Gunakan panduan ini sebagai gambaran umum. Untuk praktik ibadah, ikuti bimbingan pembimbing umrah dan rujukan keagamaan tepercaya.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                leading: const CircleAvatar(
                  backgroundColor: safarLightGreen,
                  child: Icon(Icons.check_circle_outline, color: safarGreen),
                ),
                title: Text(
                  step['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      step['description']!,
                      style: const TextStyle(height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5DF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Perhatian: ${step['note']}',
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
