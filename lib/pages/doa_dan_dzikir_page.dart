import 'package:flutter/material.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class DoaDanDzikirPage extends StatelessWidget {
  const DoaDanDzikirPage({super.key});

  static const items = [
    {
      'category': 'Talbiyah',
      'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ',
      'latin': 'Labbaika Allahumma labbaik, labbaika laa syariika laka labbaik. Innal hamda wan-ni’mata laka wal-mulk, laa syariika lak.',
      'meaning': 'Aku memenuhi panggilan-Mu, ya Allah, aku memenuhi panggilan-Mu. Tiada sekutu bagi-Mu. Sesungguhnya segala puji, nikmat, dan kerajaan adalah milik-Mu; tiada sekutu bagi-Mu.',
      'source': 'Bacaan talbiyah yang dikenal dalam tuntunan haji dan umrah.',
    },
    {
      'category': 'Doa kebaikan dunia dan akhirat',
      'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      'latin': 'Rabbanaa aatinaa fid-dunyaa hasanah, wa fil-aakhirati hasanah, wa qinaa ‘adzaaban-naar.',
      'meaning': 'Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat, serta lindungilah kami dari azab neraka.',
      'source': 'Al-Qur’an, Surah Al-Baqarah ayat 201.',
    },
    {
      'category': 'Dzikir',
      'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      'latin': 'Subhaanallaahi wa bihamdih.',
      'meaning': 'Mahasuci Allah dan segala puji bagi-Nya.',
      'source': 'Dzikir umum; dapat dibaca sesuai tuntunan yang dipelajari.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Doa dan Dzikir'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: safarLightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Bacaan berikut merupakan pilihan ringkas, bukan daftar lengkap seluruh doa dalam umrah. Pelajari pelafalannya dari guru atau sumber tepercaya.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['category']!,
                      style: const TextStyle(
                        color: safarGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        item['arabic']!,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 24, height: 1.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Transliterasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(item['latin']!, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Artinya',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(item['meaning']!, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 10),
                    Text(
                      'Rujukan: ${item['source']}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
