import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class DoaDanDzikirPage extends StatefulWidget {
  const DoaDanDzikirPage({super.key});

  @override
  State<DoaDanDzikirPage> createState() => _DoaDanDzikirPageState();
}

class _DoaDanDzikirPageState extends State<DoaDanDzikirPage> {
  String selectedCategory = 'Semua';
  String searchQuery = '';

  static const List<Map<String, String>> items = [
    {
      'title': 'Doa Berangkat dari Rumah',
      'category': 'Perjalanan',
      'scope': 'Umrah & Haji',
      'arabic': 'بِسْمِ اللهِ تَوَكَّلْتُ عَلَى اللهِ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ',
      'latin': 'Bismillahi tawakkaltu ‘alallahi wa la haula wa la quwwata illa billahil ‘aliyyil ‘azhim.',
      'meaning': 'Dengan nama Allah, aku bertawakal kepada Allah. Tidak ada daya dan kekuatan kecuali dengan pertolongan Allah.',
      'source': 'Materi doa yang diberikan pengguna.',
    },
    {
      'title': 'Doa Setelah Duduk dalam Kendaraan',
      'category': 'Perjalanan',
      'scope': 'Umrah & Haji',
      'arabic': 'بِسْمِ اللّٰهِ مَجْرٰ۪ىهَا وَمُرْسٰىهَا ۗ اِنَّ رَبِّيْ لَغَفُوْرٌ رَّحِيْمٌ',
      'latin': 'Bismillahi majreha wa mursaha, inna rabbi laghafurur rahim.',
      'meaning': 'Dengan nama Allah pada waktu berlayar dan berlabuhnya. Sesungguhnya Tuhanku Maha Pengampun, Maha Penyayang.',
      'source': 'QS Hud: 41; periksa kembali pelafalan sesuai ayat.',
    },
    {
      'title': 'Doa ketika Kendaraan Mulai Bergerak',
      'category': 'Perjalanan',
      'scope': 'Umrah & Haji',
      'arabic': 'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ ۝ اَللهُ أَكْبَرُ اَللهُ أَكْبَرُ اَللهُ أَكْبَرُ ۝ سُبْحَانَ الَّذِيْ سَخَّرَ لَنَا هٰذَا وَمَا كُنَّا لَهٗ مُقْرِنِيْنَ ۝ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُوْنَ',
      'latin': 'Bismillahirrahmanirrahim. Allahu akbar, Allahu akbar, Allahu akbar. Subhanalladzi sakhkhara lana hadza wa ma kunna lahu muqrinin, wa inna ila rabbina lamunqalibun.',
      'meaning': 'Dengan nama Allah Yang Maha Pengasih lagi Maha Penyayang. Allah Mahabesar. Mahasuci Allah yang telah menundukkan kendaraan ini bagi kami, padahal kami tidak mampu menguasainya sendiri. Sesungguhnya kepada Tuhan kami, kami akan kembali.',
      'source': 'Materi doa perjalanan; bagian kendaraan merujuk QS Az-Zukhruf: 13–14.',
    },
    {
      'title': 'Doa ketika Tiba di Tempat Tujuan',
      'category': 'Perjalanan',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللّٰهُمَّ إِنِّيْ أَسْأَلُكَ خَيْرَهَا وَخَيْرَ أَهْلِهَا وَخَيْرَ مَا فِيْهَا، وَأَعُوْذُ بِكَ مِنْ شَرِّهَا وَشَرِّ أَهْلِهَا وَشَرِّ مَا فِيْهَا',
      'latin': 'Allahumma inni as-aluka khairaha wa khaira ahliha wa khaira ma fiha, wa a‘udzu bika min syarriha wa syarri ahliha wa syarri ma fiha.',
      'meaning': 'Ya Allah, aku memohon kebaikan tempat ini, penduduknya, dan segala yang ada di dalamnya. Aku berlindung kepada-Mu dari keburukan tempat ini, penduduknya, dan segala yang ada di dalamnya.',
      'source':
          'Materi doa yang diberikan pengguna; verifikasi sumber riwayat.',
    },
    {
      'title': 'Niat Haji',
      'category': 'Ihram',
      'scope': 'Khusus Haji',
      'arabic': 'نَوَيْتُ الْحَجَّ وَأَحْرَمْتُ بِهِ لِلّٰهِ تَعَالَى',
      'latin': 'Nawaitul hajja wa ahramtu bihi lillahi ta‘ala.',
      'meaning':
          'Aku berniat melaksanakan haji dan berihram karena Allah Taala.',
      'source': 'Lafal dalam materi pengguna. Niat berkaitan dengan maksud hati dan tata cara ihram.',
    },
    {
      'title': 'Niat Umrah',
      'category': 'Ihram',
      'scope': 'Khusus Umrah',
      'arabic': 'نَوَيْتُ الْعُمْرَةَ وَأَحْرَمْتُ بِهَا لِلّٰهِ تَعَالَى',
      'latin': 'Nawaitul ‘umrata wa ahramtu biha lillahi ta‘ala.',
      'meaning':
          'Aku berniat melaksanakan umrah dan berihram karena Allah Taala.',
      'source': 'Lafal dalam materi pengguna. Niat berkaitan dengan maksud hati dan tata cara ihram.',
    },
    {
      'title': 'Niat Haji Sekaligus Umrah (Qiran)',
      'category': 'Ihram',
      'scope': 'Khusus Haji',
      'arabic': 'نَوَيْتُ الْحَجَّ وَالْعُمْرَةَ وَأَحْرَمْتُ بِهِمَا لِلّٰهِ تَعَالَى',
      'latin': 'Nawaitul hajja wal ‘umrata wa ahramtu bihima lillahi ta‘ala.',
      'meaning': 'Aku berniat melaksanakan haji sekaligus umrah dan berihram karena Allah Taala.',
      'source': 'Lafal dalam materi pengguna; pelajari ketentuan haji qiran.',
    },
    {
      'title': 'Doa Selesai Berihram',
      'category': 'Ihram',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللّٰهُمَّ أُحَرِّمُ شَعْرِيْ وَبَشَرِيْ وَجَسَدِيْ وَجَمِيْعَ جَوَارِحِيْ مِنْ كُلِّ شَيْءٍ حَرَّمْتَهُ عَلَى الْمُحْرِمِ أَبْتَغِيْ بِذٰلِكَ وَجْهَكَ الْكَرِيْمَ يَا رَبَّ الْعَالَمِيْنَ',
      'latin': 'Allahumma uharrimu sya‘ri wa basyari wa jasadi wa jami‘a jawarihi min kulli syai-in harramtahu ‘alal muhrim, abtaghi bidzalika wajhakal karim ya rabbal ‘alamin.',
      'meaning': 'Ya Allah, aku mengharamkan rambut, kulit, tubuh, dan seluruh anggota tubuhku dari hal-hal yang Engkau haramkan bagi orang yang berihram, demi mengharapkan ridha-Mu.',
      'source': 'Materi pengguna; status dan sumber khusus lafal ini perlu diverifikasi.',
    },
    {
      'title': 'Lafal Talbiyah',
      'category': 'Ihram',
      'scope': 'Umrah & Haji',
      'arabic': 'لَبَّيْكَ اللّٰهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيْكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ لَا شَرِيْكَ لَكَ',
      'latin': 'Labbaika Allahumma labbaik, labbaika la syarika laka labbaik. Innal hamda wan-ni‘mata laka wal-mulk, la syarika lak.',
      'meaning': 'Aku memenuhi panggilan-Mu, ya Allah. Tiada sekutu bagi-Mu. Sesungguhnya segala puji, nikmat, dan kerajaan adalah milik-Mu; tiada sekutu bagi-Mu.',
      'source': 'Bacaan talbiyah yang dikenal dalam tuntunan haji dan umrah.',
    },
    {
      'title': 'Doa Memasuki Kota Makkah',
      'category': 'Makkah',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللّٰهُمَّ هٰذَا حَرَمُكَ وَأَمْنُكَ فَحَرِّمْ لَحْمِيْ وَدَمِيْ وَشَعْرِيْ وَبَشَرِيْ عَلَى النَّارِ وَآمِنِّيْ مِنْ عَذَابِكَ يَوْمَ تَبْعَثُ عِبَادَكَ وَاجْعَلْنِيْ مِنْ أَوْلِيَائِكَ وَأَهْلِ طَاعَتِكَ',
      'latin': 'Allahumma hadza haramuka wa amnuka, faharrim lahmi wa dami wa sya‘ri wa basyari ‘alan-nar, wa aminni min ‘adzabika yauma tab‘atsu ‘ibadaka, waj‘alni min auliyaika wa ahli tha‘atik.',
      'meaning': 'Ya Allah, ini tanah haram-Mu dan tempat aman-Mu. Lindungilah aku dari api neraka dan siksa-Mu, serta jadikanlah aku termasuk hamba-hamba-Mu yang taat.',
      'source':
          'Materi doa yang diberikan pengguna; verifikasi sumber riwayat.',
    },
    {
      'title': 'Doa Masuk Masjidil Haram',
      'category': 'Makkah',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللّٰهُمَّ افْتَحْ لِيْ أَبْوَابَ رَحْمَتِكَ',
      'latin': 'Allahummaftah li abwaba rahmatik.',
      'meaning': 'Ya Allah, bukakanlah untukku pintu-pintu rahmat-Mu.',
      'source': 'Doa masuk masjid yang diriwayatkan dalam Sahih Muslim.',
    },
    {
      'title': 'Doa ketika Melihat Ka’bah',
      'category': 'Makkah',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللّٰهُمَّ زِدْ هٰذَا الْبَيْتَ تَشْرِيْفًا وَتَعْظِيْمًا وَتَكْرِيْمًا وَمَهَابَةً وَزِدْ مَنْ شَرَّفَهُ وَكَرَّمَهُ مِمَّنْ حَجَّهُ أَوِ اعْتَمَرَهُ تَشْرِيْفًا وَتَكْرِيْمًا وَتَعْظِيْمًا وَبِرًّا',
      'latin': 'Allahumma zid hadzal baita tasyrifan wa ta‘zhiman wa takriman wa mahabah, wa zid man syarrafahu wa karramahu mimman hajjahu awi‘ tamarahu tasyrifan wa takriman wa ta‘zhiman wa birran.',
      'meaning': 'Ya Allah, tambahkanlah kemuliaan, kehormatan, keagungan, dan kebaikan bagi Baitullah ini serta orang-orang yang berhaji atau berumrah.',
      'source':
          'Materi doa yang diberikan pengguna; verifikasi sumber riwayat.',
    },
    {
      'title': 'Doa Tawaf: Hajar Aswad ke Rukun Yamani',
      'category': 'Tawaf',
      'scope': 'Umrah & Haji',
      'arabic': 'سُبْحَانَ اللهِ وَالْحَمْدُ لِلّٰهِ وَلَا إِلٰهَ إِلَّا اللهُ وَاللهُ أَكْبَرُ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ الْعَلِيِّ الْعَظِيْمِ',
      'latin': 'Subhanallahi walhamdulillahi wa la ilaha illallah wallahu akbar, wa la haula wa la quwwata illa billahil ‘aliyyil ‘azhim.',
      'meaning': 'Mahasuci Allah, segala puji bagi Allah, tiada sesembahan yang berhak disembah selain Allah, Allah Mahabesar. Tidak ada daya dan kekuatan kecuali dengan pertolongan Allah.',
      'source': 'Materi doa yang diberikan pengguna; bukan bacaan wajib setiap putaran.',
    },
    {
      'title': 'Doa Tawaf: Rukun Yamani ke Hajar Aswad',
      'category': 'Tawaf',
      'scope': 'Umrah & Haji',
      'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      'latin': 'Rabbana atina fid-dunya hasanah, wa fil-akhirati hasanah, wa qina ‘adzaban-nar.',
      'meaning': 'Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat, serta lindungilah kami dari azab neraka.',
      'source': 'QS Al-Baqarah: 201.',
    },
    {
      'title': 'Doa Sa’i',
      'category': 'Sa’i',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللهُ أَكْبَرُ، اَللهُ أَكْبَرُ، اَللهُ أَكْبَرُ، كَبِيْرًا وَالْحَمْدُ لِلّٰهِ كَثِيْرًا وَسُبْحَانَ اللهِ بُكْرَةً وَأَصِيْلًا',
      'latin': 'Allahu akbar, Allahu akbar, Allahu akbar, kabiran walhamdulillahi katsiran wa subhanallahi bukratan wa ashila.',
      'meaning': 'Allah Mahabesar. Segala puji bagi Allah sebanyak-banyaknya dan Mahasuci Allah pada waktu pagi maupun petang.',
      'source': 'Materi doa yang diberikan pengguna; bacaan ini bukan satu-satunya doa yang dapat dibaca saat sa’i.',
    },
    {
      'title': 'Doa Menggunting Rambut',
      'category': 'Tahallul',
      'scope': 'Umrah & Haji',
      'arabic': 'اَللّٰهُمَّ اثْبُتْ لِيْ بِكُلِّ شَعْرَةٍ حَسَنَةً وَامْحُ عَنِّيْ بِهَا سَيِّئَةً وَارْفَعْ لِيْ عِنْدَكَ دَرَجَةً',
      'latin': 'Allahumma-tsbut li bikulli sya‘ratin hasanatan, wamhu ‘anni biha sayyi-atan, warfa‘ li ‘indaka darajatan.',
      'meaning': 'Ya Allah, tetapkanlah kebaikan bagiku melalui setiap helai rambut ini, hapuslah keburukanku, dan angkatlah derajatku di sisi-Mu.',
      'source':
          'Materi doa yang diberikan pengguna; verifikasi sumber riwayat.',
    },
    {
      'title': 'Doa ketika Masuk Arafah',
      'category': 'Rangkaian Haji',
      'scope': 'Khusus Haji',
      'arabic': 'اَللّٰهُمَّ إِلَيْكَ تَوَجَّهْتُ، وَبِكَ اعْتَصَمْتُ، وَعَلَيْكَ تَوَكَّلْتُ. اَللّٰهُمَّ اجْعَلْنِيْ مِمَّنْ تُبَاهِيْ بِهِ الْيَوْمَ مَلَائِكَتَكَ، إِنَّكَ عَلَى كُلِّ شَيْءٍ قَدِيْرٌ',
      'latin': 'Allahumma ilaika tawajjahtu, wa bika‘tashamtu, wa ‘alaika tawakkaltu. Allahummaj‘alni mimman tubahi bihil yauma malaikataka, innaka ‘ala kulli syai-in qadir.',
      'meaning': 'Ya Allah, kepada-Mu aku menghadap, kepada-Mu aku berpegang teguh, dan kepada-Mu aku bertawakal. Jadikanlah aku termasuk orang yang Engkau banggakan di hadapan para malaikat-Mu.',
      'source': 'Materi doa yang diberikan pengguna; khusus haji.',
    },
    {
      'title': 'Doa Wukuf',
      'category': 'Rangkaian Haji',
      'scope': 'Khusus Haji',
      'arabic': 'اَللّٰهُمَّ لَكَ الْحَمْدُ كَالَّذِيْ تَقُوْلُ وَخَيْرًا مِمَّا نَقُوْلُ. اَللّٰهُمَّ لَكَ صَلَاتِيْ وَنُسُكِيْ وَمَحْيَايَ وَمَمَاتِيْ وَإِلَيْكَ مَآبِيْ',
      'latin': 'Allahumma lakal hamdu kalladzi taqulu wa khairan mimma naqulu. Allahumma laka shalati wa nusuki wa mahyaya wa mamati wa ilaika ma-abi.',
      'meaning': 'Ya Allah, bagi-Mu segala puji. Bagi-Mu salatku, ibadahku, hidupku, dan matiku. Kepada-Mu tempat kembaliku.',
      'source': 'Bagian awal dari doa wukuf pada materi pengguna; teks sumber lengkap lebih panjang.',
    },
    {
      'title': 'Doa ketika Sampai di Muzdalifah',
      'category': 'Rangkaian Haji',
      'scope': 'Khusus Haji',
      'arabic': 'اَللّٰهُمَّ إِنَّ هٰذِهِ مُزْدَلِفَةُ جُمِعَتْ فِيْهَا أَلْسِنَةٌ مُخْتَلِفَةٌ تَسْأَلُكَ حَوَائِجَ مُتَنَوِّعَةً فَاجْعَلْنِيْ مِمَّنْ دَعَاكَ فَاسْتَجَبْتَ لَهُ وَتَوَكَّلَ عَلَيْكَ فَكَفَّيْتَهُ يَا أَرْحَمَ الرَّاحِمِيْنَ',
      'latin': 'Allahumma inna hadzihi Muzdalifatu jumi‘at fiha alsinatun mukhtalifatun tas-aluka hawaija mutanawwi‘atan, faj‘alni mimman da‘aka fastajabta lahu wa tawakkala ‘alaika fakafaitahu ya arhamar rahimin.',
      'meaning': 'Ya Allah, di Muzdalifah berkumpul orang-orang dengan beragam permohonan. Jadikanlah aku termasuk orang yang berdoa lalu Engkau kabulkan dan bertawakal lalu Engkau cukupkan.',
      'source': 'Materi doa yang diberikan pengguna; khusus haji.',
    },
    {
      'title': 'Doa ketika Sampai di Mina',
      'category': 'Rangkaian Haji',
      'scope': 'Khusus Haji',
      'arabic': 'اَللّٰهُمَّ هٰذَا مِنَى فَامْنُنْ عَلَيَّ بِمَا مَنَنْتَ بِهِ عَلَى أَوْلِيَائِكَ وَأَهْلِ طَاعَتِكَ',
      'latin': 'Allahumma hadza Mina, famnun ‘alayya bima mananta bihi ‘ala auliyaika wa ahli tha‘atik.',
      'meaning': 'Ya Allah, ini Mina. Anugerahkanlah kepadaku apa yang Engkau anugerahkan kepada para hamba-Mu yang dekat dan taat kepada-Mu.',
      'source': 'Materi doa yang diberikan pengguna; khusus haji.',
    },
    {
      'title': 'Doa Melontar Jamrah',
      'category': 'Rangkaian Haji',
      'scope': 'Khusus Haji',
      'arabic': 'بِسْمِ اللهِ وَاللهُ أَكْبَرُ رَجْمًا لِلشَّيَاطِيْنِ وَرِضًا لِلرَّحْمٰنِ اَللّٰهُمَّ اجْعَلْ حَجًّا مَبْرُوْرًا وَسَعْيًا مَشْكُوْرًا',
      'latin': 'Bismillahi wallahu akbar, rajman lisy-syayathini wa ridhan lirrahman. Allahummaj‘al hajjan mabruran wa sa‘yan masykuran.',
      'meaning': 'Dengan nama Allah, Allah Mahabesar. Ya Allah, jadikanlah hajiku diterima dan usahaku dibalas dengan pahala.',
      'source': 'Materi doa yang diberikan pengguna; khusus haji.',
    },
    {
      'title': 'Doa Masuk Kota Madinah',
      'category': 'Madinah',
      'scope': 'Perjalanan',
      'arabic': 'اَللّٰهُمَّ هٰذَا حَرَمُ رَسُولِكَ وَاجْعَلْهُ لِيْ وِقَايَةً مِنَ النَّارِ وَأَمَانًا مِنَ الْعَذَابِ وَسُوْءِ الْحِسَابِ',
      'latin': 'Allahumma hadza haramu rasulika, waj‘alhu li wiqayatan minan-nari wa amanan minal ‘adzabi wa su-il hisab.',
      'meaning': 'Ya Allah, ini tanah haram Rasul-Mu. Jadikanlah ia perlindungan bagiku dari neraka, siksa, dan buruknya perhitungan amal.',
      'source':
          'Materi doa yang diberikan pengguna; verifikasi sumber riwayat.',
    },
    {
      'title': 'Doa Masuk Masjid Nabawi',
      'category': 'Madinah',
      'scope': 'Perjalanan',
      'arabic': 'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ. أَعُوْذُ بِاللهِ الْعَظِيْمِ وَوَجْهِهِ الْكَرِيْمِ وَسُلْطَانِهِ الْقَدِيْمِ مِنَ الشَّيْطَانِ الرَّجِيْمِ. اَللّٰهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
      'latin': 'Bismillahirrahmanirrahim. A‘udzu billahil ‘azhim wa wajhihil karim wa sulthanihil qadim minasy-syaithanir rajim. Allahummaftah li abwaba rahmatik.',
      'meaning': 'Dengan nama Allah Yang Maha Pengasih lagi Maha Penyayang. Aku berlindung kepada Allah dari godaan setan. Ya Allah, bukakanlah bagiku pintu-pintu rahmat-Mu.',
      'source': 'Materi doa yang diberikan pengguna.',
    },
    {
      'title': 'Doa ketika Pulang Haji atau Umrah',
      'category': 'Perjalanan',
      'scope': 'Umrah & Haji',
      'arabic': 'لَا إِلٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، آيِبُونَ تَائِبُونَ عَابِدُونَ سَاجِدُونَ لِرَبِّنَا حَامِدُونَ',
      'latin': 'La ilaha illallahu wahdahu la syarika lah, lahul mulku wa lahul hamdu wa huwa ‘ala kulli syai-in qadir. Ayibun, taibun, ‘abidun, sajidun, li rabbina hamidun.',
      'meaning': 'Tiada sesembahan selain Allah semata, tiada sekutu bagi-Nya. Milik-Nya kerajaan dan segala pujian, dan Dia Mahakuasa atas segala sesuatu. Kami kembali, bertobat, beribadah, bersujud, dan memuji Tuhan kami.',
      'source': 'Materi doa yang diberikan pengguna; teks sumber lengkap juga memuat bagian akhir tambahan.',
    },
  ];

  static const List<String> categories = [
    'Semua',
    'Perjalanan',
    'Ihram',
    'Makkah',
    'Tawaf',
    'Sa’i',
    'Tahallul',
    'Rangkaian Haji',
    'Madinah',
  ];

  List<Map<String, String>> get filteredItems {
    return items.where((item) {
      final matchesCategory =
          selectedCategory == 'Semua' || item['category'] == selectedCategory;

      final query = searchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          item['title']!.toLowerCase().contains(query) ||
          item['category']!.toLowerCase().contains(query) ||
          item['scope']!.toLowerCase().contains(query) ||
          item['meaning']!.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  void copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredItems;

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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: safarLightGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, color: safarGreen, size: 32),
                SizedBox(height: 10),
                Text(
                  'Kumpulan Doa Haji & Umrah',
                  style: TextStyle(
                    color: safarGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Temukan bacaan berdasarkan tahapan perjalanan, ibadah, dan lokasi. Setiap bacaan dilengkapi tulisan Arab, transliterasi, arti, serta fungsi salin.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cari nama doa atau arti...',
              prefixIcon: const Icon(Icons.search, color: safarGreen),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == selectedCategory;

                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  selectedColor: safarLightGreen,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? safarGreen : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected ? safarGreen : Colors.black12,
                  ),
                  onSelected: (_) {
                    setState(() => selectedCategory = category);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${filtered.length} bacaan ditemukan',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Tidak ada bacaan yang sesuai pencarian.'),
              ),
            ),
          ...filtered.map(_buildPrayerCard),
          const SizedBox(height: 12),
          const Text(
            'Catatan: transliterasi merupakan bantuan membaca. Untuk ketepatan pelafalan dan penerapan ibadah, rujuk pembimbing atau sumber keagamaan tepercaya.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(Map<String, String> item) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const CircleAvatar(
          backgroundColor: safarLightGreen,
          child: Icon(Icons.menu_book_rounded, color: safarGreen),
        ),
        title: Text(
          item['title']!,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('${item['category']} • ${item['scope']}'),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SelectableText(
                item['arabic']!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 25,
                  height: 2,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildTextSection(title: 'Transliterasi', text: item['latin']!),
          const SizedBox(height: 12),
          _buildTextSection(title: 'Artinya', text: item['meaning']!),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Rujukan: ${item['source']}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _copyButton('Arab', item['arabic']!),
              _copyButton('Latin', item['latin']!),
              _copyButton('Arti', item['meaning']!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection({required String title, required String text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: safarGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(text, style: const TextStyle(height: 1.6)),
      ],
    );
  }

  Widget _copyButton(String label, String text) {
    return OutlinedButton.icon(
      onPressed: () => copyText(text, label),
      icon: const Icon(Icons.copy_rounded, size: 16),
      label: Text('Salin $label'),
      style: OutlinedButton.styleFrom(
        foregroundColor: safarGreen,
        side: const BorderSide(color: safarGreen),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
