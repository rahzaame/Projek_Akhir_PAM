import 'package:flutter/material.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class TataCaraUmrahPage extends StatelessWidget {
  const TataCaraUmrahPage({super.key});

  static const List<Map<String, String>> steps = [
    {
      'title': '1. Persiapan Sebelum Ihram',
      'description': 'Sebelum ihram, jamaah dianjurkan mandi dan membersihkan diri. Laki-laki dapat memakai wewangian sebelum berniat ihram jika tersedia. Persiapkan perlengkapan sebelum melewati miqat.',
      'detail': 'Laki-laki mengenakan dua lembar kain ihram. Perempuan mengenakan pakaian yang menutup aurat sesuai ketentuan. Materi rujukan menjelaskan bahwa perempuan yang berihram tidak mengenakan niqab dan sarung tangan khusus.',
      'note': 'Pakaian ihram tidak harus dibeli sebagai seragam khusus. Ikuti arahan pembimbing ibadah.',
    },
    {
      'title': '2. Niat Ihram dan Talbiyah',
      'description': 'Niat umrah dilakukan ketika memulai ihram di miqat. Setelah berniat, jamaah dianjurkan memperbanyak talbiyah selama perjalanan menuju Masjidil Haram.',
      'arabic': 'لَبَّيْكَ عُمْرَةً',
      'latin': 'Labbaika ‘umrah',
      'meaning': 'Aku memenuhi panggilan-Mu untuk menunaikan umrah.',
      'detail': 'Bacaan talbiyah yang diulang:',
      'extraArabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ',
      'extraLatin': 'Labbaik Allahumma labbaik. Labbaika laa syariika laka labbaik. Innal hamda wan-ni‘mata laka wal-mulk, laa syariika lak.',
      'extraMeaning': 'Aku memenuhi panggilan-Mu, ya Allah. Aku memenuhi panggilan-Mu, tiada sekutu bagi-Mu. Sesungguhnya segala pujian, nikmat, dan kerajaan adalah milik-Mu; tiada sekutu bagi-Mu.',
      'note': 'Jika khawatir terhalang menyelesaikan umrah, tanyakan kepada pembimbing mengenai doa bersyarat dan penerapannya.',
    },
    {
      'title': '3. Memasuki Masjidil Haram',
      'description': 'Ketika memasuki masjid, dahulukan kaki kanan dan bacalah doa masuk masjid. Kemudian ikuti petunjuk petugas atau pembimbing menuju area tawaf.',
      'arabic': 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
      'latin': 'Allahummaftah lii abwaaba rahmatik',
      'meaning': 'Ya Allah, bukakanlah untukku pintu-pintu rahmat-Mu.',
      'note': 'Utamakan keselamatan. Jangan berhenti di jalur padat hanya untuk membaca doa atau mengambil foto.',
    },
    {
      'title': '4. Tawaf Umrah',
      'description': 'Tawaf dilakukan sebanyak tujuh putaran mengelilingi Ka’bah, dimulai sejajar Hajar Aswad dan berakhir di titik tersebut. Ka’bah berada di sebelah kiri jamaah.',
      'detail': 'Saat sejajar Hajar Aswad, jamaah dapat bertakbir. Jika aman dan memungkinkan, Hajar Aswad dapat disentuh tanpa memaksakan diri. Materi rujukan menyebutkan lari-lari kecil pada tiga putaran pertama bagi laki-laki dalam kondisi yang memungkinkan.',
      'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      'latin': 'Rabbanaa aatinaa fid-dunyaa hasanah, wa fil-aakhirati hasanah, wa qinaa ‘adzaaban-naar.',
      'meaning': 'Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat serta lindungilah kami dari azab neraka.',
      'note': 'Tidak ada satu bacaan wajib untuk setiap putaran tawaf. Jamaah dapat berdoa dan berzikir. Jangan berdesakan demi menyentuh Hajar Aswad atau Rukun Yamani.',
    },
    {
      'title': '5. Salat Sunah Tawaf dan Zamzam',
      'description': 'Setelah tawaf, jamaah dianjurkan melaksanakan salat sunah tawaf dua rakaat jika memungkinkan. Materi rujukan menyebut Surah Al-Kafirun dan Al-Ikhlas sebagai bacaan yang dianjurkan.',
      'detail': 'Salat dapat dilakukan di belakang Maqam Ibrahim jika memungkinkan dan tidak mengganggu arus jamaah. Jika padat, ikuti petunjuk petugas dan pilih tempat yang diperbolehkan. Setelah itu, jamaah dapat minum air Zamzam.',
      'note': 'Maqam Ibrahim bukan makam Nabi Ibrahim. Jangan memaksakan salat tepat di belakangnya jika keadaan tidak memungkinkan.',
    },
    {
      'title': '6. Memulai Sa’i di Safa',
      'description': 'Sa’i dimulai di Safa dan berakhir di Marwah. Ketika mendekati Safa, materi rujukan mencantumkan bacaan berikut.',
      'arabic': 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ',
      'latin': 'Innash-shafaa wal-marwata min syaa’irillaah.',
      'meaning': 'Sesungguhnya Safa dan Marwah termasuk syiar Allah.',
      'detail': 'Di Safa, jamaah dapat menghadap kiblat, bertakbir, berzikir, dan berdoa. Materi rujukan juga mencantumkan zikir tauhid berikut:',
      'extraArabic': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      'extraLatin': 'Laa ilaaha illallaahu wahdahu laa syariika lah, lahul-mulku wa lahul-hamd, wa huwa ‘alaa kulli syai’in qadiir.',
      'extraMeaning': 'Tiada sesembahan yang berhak disembah selain Allah semata, tiada sekutu bagi-Nya. Milik-Nya kerajaan dan segala pujian, dan Dia Mahakuasa atas segala sesuatu.',
      'note': 'Bacaan ini bukan satu-satunya doa yang boleh dibaca. Jamaah dapat berdoa sesuai kebutuhan.',
    },
    {
      'title': '7. Menyelesaikan Sa’i',
      'description': 'Berjalanlah dari Safa menuju Marwah, kemudian kembali menuju Safa, hingga genap tujuh perjalanan. Safa ke Marwah dihitung satu perjalanan. Perjalanan ketujuh berakhir di Marwah.',
      'detail': 'Materi rujukan menyebutkan laki-laki berlari kecil di antara dua tanda hijau jika mampu. Di luar bagian tersebut, jamaah berjalan biasa. Selama sa’i, jamaah boleh berzikir, berdoa, atau membaca Al-Qur’an.',
      'arabic': 'اللَّهُمَّ اغْفِرْ وَارْحَمْ وَأَنْتَ الأَعَزُّ الأَكْرَمُ',
      'latin': 'Allahummaghfir warham wa antal a‘azzul akram.',
      'meaning': 'Ya Allah, ampunilah dan rahmatilah aku. Sesungguhnya Engkau Maha Perkasa lagi Maha Pemurah.',
      'note': 'Bacaan ini disebut dalam materi rujukan sebagai doa yang boleh dibaca, bukan bacaan wajib sepanjang sa’i. Sesuaikan kecepatan dengan kondisi fisik.',
    },
    {
      'title': '8. Tahallul',
      'description': 'Setelah menyelesaikan sa’i, jamaah melakukan tahallul dengan mencukur atau memendekkan rambut sesuai ketentuan. Setelah tahallul, rangkaian umrah selesai.',
      'detail': 'Materi rujukan menyebut mencukur gundul sebagai pilihan yang lebih utama bagi laki-laki, atau memendekkan rambut. Perempuan memotong sedikit ujung rambut sesuai bimbingan ibadah.',
      'note': 'Jika ada kondisi khusus atau keraguan mengenai sahnya ibadah, tanyakan kepada pembimbing umrah yang kompeten.',
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
                  'Panduan Lengkap Umrah',
                  style: TextStyle(
                    color: safarGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Ikuti tahapan dari persiapan ihram hingga tahallul. Panduan ini merupakan ringkasan edukasi. Untuk praktik ibadah, ikuti pembimbing umrah dan rujukan keagamaan tepercaya.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5DF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Utamakan ketertiban dan keselamatan. Amalan sunah tidak perlu dipaksakan jika berisiko mengganggu atau membahayakan jamaah lain.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => _buildStepCard(step)),
          const SizedBox(height: 8),
          const Text(
            'Catatan: rincian sebagian amalan dapat berbeda menurut rujukan fikih dan kondisi jamaah. Pastikan mengikuti bimbingan yang tepercaya.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, String> step) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const CircleAvatar(
          backgroundColor: safarLightGreen,
          child: Icon(Icons.menu_book_rounded, color: safarGreen),
        ),
        title: Text(
          step['title']!,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        children: [
          _paragraph(step['description']!),
          if (step['arabic'] != null) ...[
            const SizedBox(height: 14),
            _prayerCard(
              arabic: step['arabic']!,
              latin: step['latin'],
              meaning: step['meaning'],
            ),
          ],
          if (step['detail'] != null) ...[
            const SizedBox(height: 12),
            _paragraph(step['detail']!),
          ],
          if (step['extraArabic'] != null) ...[
            const SizedBox(height: 12),
            _prayerCard(
              title: step['title']!.startsWith('2.')
                  ? 'Bacaan Talbiyah'
                  : 'Bacaan Zikir',
              arabic: step['extraArabic']!,
              latin: step['extraLatin'],
              meaning: step['extraMeaning'],
            ),
          ],
          if (step['note'] != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5DF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF8A5A00),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step['note']!,
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paragraph(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(height: 1.55)),
    );
  }

  Widget _prayerCard({
    String? title,
    required String arabic,
    String? latin,
    String? meaning,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                color: safarGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              arabic,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                height: 1.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (latin != null) ...[
            const SizedBox(height: 8),
            Text(
              latin,
              style: const TextStyle(fontStyle: FontStyle.italic, height: 1.5),
            ),
          ],
          if (meaning != null) ...[
            const SizedBox(height: 6),
            Text(
              meaning,
              style: const TextStyle(height: 1.5, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}
