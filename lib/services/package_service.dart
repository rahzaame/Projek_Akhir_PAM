import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

enum QuizCategory {
  manasik('manasik', 'Manasik Umrah', 'Rukun, tata cara, dan larangan ihram'),
  destinasi(
    'destinasi',
    'Destinasi & Perjalanan',
    'Makkah, Madinah, Turki, mata uang, dan zona waktu',
  ),
  campuran('campuran', 'Campuran', 'Soal acak dari semua kategori');

  final String id;
  final String label;
  final String description;

  const QuizCategory(this.id, this.label, this.description);
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final QuizCategory category;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
  });
}

class _RawQuestion {
  final QuizCategory category;
  final String question;
  final String correct;
  final List<String> wrong;
  final String explanation;

  const _RawQuestion(
    this.category,
    this.question,
    this.correct,
    this.wrong,
    this.explanation,
  );
}

class QuizHistoryEntry {
  final String category;
  final int correctCount;
  final int totalQuestions;
  final int score;
  final int durationSeconds;
  final DateTime createdAt;

  const QuizHistoryEntry({
    required this.category,
    required this.correctCount,
    required this.totalQuestions,
    required this.score,
    required this.durationSeconds,
    required this.createdAt,
  });

  factory QuizHistoryEntry.fromMap(Map<String, dynamic> map) {
    return QuizHistoryEntry(
      category: map['category']?.toString() ?? '',
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class QuizService {
  final SupabaseClient _client = Supabase.instance.client;

  static const int questionsPerRound = 5;

  static List<QuizQuestion> generateRound(
    QuizCategory category, {
    int count = questionsPerRound,
    Random? random,
  }) {
    final rng = random ?? Random();

    final pool =
        _bank
            .where(
              (q) =>
                  category == QuizCategory.campuran || q.category == category,
            )
            .toList()
          ..shuffle(rng);

    return pool.take(min(count, pool.length)).map((raw) {
      final options = [raw.correct, ...raw.wrong]..shuffle(rng);
      return QuizQuestion(
        question: raw.question,
        options: options,
        correctIndex: options.indexOf(raw.correct),
        explanation: raw.explanation,
        category: raw.category,
      );
    }).toList();
  }

  Future<void> saveResult({
    required QuizCategory category,
    required int correctCount,
    required int totalQuestions,
    required int durationSeconds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');

    final score = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    await _client.from('quiz_results').insert({
      'user_id': user.id,
      'category': category.id,
      'correct_count': correctCount,
      'total_questions': totalQuestions,
      'score': score,
      'duration_seconds': durationSeconds,
    });
  }

  Future<List<QuizHistoryEntry>> fetchHistory({int limit = 10}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('quiz_results')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response)
        .map(QuizHistoryEntry.fromMap)
        .toList();
  }

  static const List<_RawQuestion> _bank = [
    _RawQuestion(
      QuizCategory.manasik,
      'Berapa kali putaran tawaf mengelilingi Ka’bah?',
      '7 putaran',
      ['3 putaran', '5 putaran', '9 putaran'],
      'Tawaf dilakukan sebanyak tujuh putaran, dimulai dan diakhiri di garis Hajar Aswad.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Sa’i dilakukan di antara dua bukit, yaitu…',
      'Shafa dan Marwah',
      ['Uhud dan Quba', 'Arafah dan Muzdalifah', 'Nur dan Tsur'],
      'Sa’i adalah berjalan antara bukit Shafa dan Marwah, mengenang perjuangan Siti Hajar.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Sa’i dimulai dari bukit…',
      'Shafa',
      ['Marwah', 'Uhud', 'Nur'],
      'Sa’i dimulai dari Shafa dan berakhir di Marwah; setiap perjalanan satu arah dihitung satu kali, total tujuh kali.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Tempat dimulainya niat ihram untuk umrah disebut…',
      'Miqat',
      ['Multazam', 'Hijir Ismail', 'Raudhah'],
      'Miqat adalah batas tempat atau waktu yang ditentukan untuk memulai niat ihram.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Tawaf dimulai dan diakhiri dari…',
      'Hajar Aswad',
      ['Maqam Ibrahim', 'Multazam', 'Rukun Yamani'],
      'Setiap putaran tawaf dimulai dari garis sejajar Hajar Aswad dan berakhir di tempat yang sama.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Posisi Ka’bah saat melakukan tawaf berada di sisi…',
      'Kiri',
      ['Kanan', 'Depan', 'Belakang'],
      'Jemaah bertawaf berlawanan arah jarum jam sehingga Ka’bah selalu berada di sebelah kiri.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Tahallul pada akhir rangkaian umrah dilakukan dengan…',
      'Mencukur atau memotong rambut',
      ['Berwudu di Hijir Ismail', 'Menyentuh kiswah Ka’bah', 'Melempar jumrah'],
      'Tahallul menandai selesainya umrah dan berakhirnya larangan ihram.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Lafaz talbiyah dimulai dengan kalimat…',
      'Labbaikallahumma labbaik',
      [
        'Allahu akbar kabira',
        'Subhanallah wal hamdulillah',
        'Rabbana atina fid dunya hasanah',
      ],
      'Talbiyah dibaca sejak berniat ihram sebagai jawaban atas panggilan Allah.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Pakaian ihram untuk laki-laki terdiri dari…',
      'Dua lembar kain tanpa jahitan',
      [
        'Gamis dan sorban berjahit',
        'Kemeja dan celana panjang',
        'Jubah dan peci',
      ],
      'Laki-laki memakai dua lembar kain tanpa jahitan (izar dan rida’) serta tidak menutup kepala.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Manakah yang termasuk larangan saat berihram?',
      'Memakai wewangian',
      ['Membaca Al-Qur’an', 'Berdoa', 'Minum air zamzam'],
      'Selama ihram dilarang memakai wewangian, memotong kuku atau rambut, serta berburu.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Salat sunah dua rakaat setelah tawaf disunahkan dilakukan di dekat…',
      'Maqam Ibrahim',
      ['Raudhah', 'Jabal Rahmah', 'Bukit Marwah'],
      'Setelah tawaf, jemaah disunahkan salat dua rakaat di belakang Maqam Ibrahim bila memungkinkan.',
    ),
    _RawQuestion(
      QuizCategory.manasik,
      'Urutan rukun umrah yang benar adalah…',
      'Ihram, tawaf, sa’i, tahallul',
      [
        'Tawaf, ihram, tahallul, sa’i',
        'Sa’i, tawaf, ihram, tahallul',
        'Ihram, sa’i, tahallul, tawaf',
      ],
      'Umrah dikerjakan berurutan: berihram dari miqat, tawaf, sa’i, lalu tahallul.',
    ),

    // ---------------------------- DESTINASI
    _RawQuestion(
      QuizCategory.destinasi,
      'Masjidil Haram dan Ka’bah berada di kota…',
      'Makkah',
      ['Madinah', 'Jeddah', 'Riyadh'],
      'Masjidil Haram yang mengelilingi Ka’bah terletak di Makkah al-Mukarramah.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Masjid Nabawi dan Raudhah berada di kota…',
      'Madinah',
      ['Makkah', 'Taif', 'Istanbul'],
      'Masjid Nabawi di Madinah adalah masjid yang dibangun Rasulullah ﷺ; Raudhah ada di dalamnya.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Mata uang resmi Arab Saudi adalah…',
      'Riyal Saudi (SAR)',
      ['Dinar (KWD)', 'Dirham (AED)', 'Lira (TRY)'],
      'Arab Saudi memakai Riyal Saudi dengan kode mata uang SAR.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Mata uang resmi Turki adalah…',
      'Lira Turki (TRY)',
      ['Euro (EUR)', 'Riyal (SAR)', 'Pound (GBP)'],
      'Turki memakai Lira Turki dengan kode mata uang TRY.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Masjid Biru (Sultanahmet) dan Hagia Sophia terletak di kota…',
      'Istanbul',
      ['Ankara', 'Izmir', 'Bursa'],
      'Keduanya berdiri berdekatan di kawasan Sultanahmet, Istanbul.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Ibu kota negara Turki adalah…',
      'Ankara',
      ['Istanbul', 'Izmir', 'Konya'],
      'Istanbul adalah kota terbesar, tetapi ibu kota Turki adalah Ankara.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Selat yang membelah Istanbul dan memisahkan benua Eropa dan Asia adalah…',
      'Selat Bosporus',
      ['Selat Malaka', 'Selat Hormuz', 'Terusan Suez'],
      'Selat Bosporus menghubungkan Laut Hitam dengan Laut Marmara.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Masjid pertama yang dibangun dalam sejarah Islam dan berada di Madinah adalah…',
      'Masjid Quba',
      ['Masjid Nabawi', 'Masjid Qiblatain', 'Masjidil Haram'],
      'Masjid Quba dibangun Rasulullah ﷺ saat hijrah, sebelum memasuki kota Madinah.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Gua Hira, tempat turunnya wahyu pertama, berada di bukit…',
      'Jabal Nur',
      ['Jabal Uhud', 'Jabal Tsur', 'Jabal Rahmah'],
      'Gua Hira terletak di Jabal Nur, di dekat Makkah.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Saat pukul 12.00 WIB, waktu di Arab Saudi adalah pukul…',
      '08.00',
      ['11.00', '15.00', '19.00'],
      'Arab Saudi (UTC+3) lebih lambat 4 jam dari WIB (UTC+7).',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Selisih waktu antara WIB dan WIT adalah…',
      'WIT lebih cepat 2 jam',
      ['WIT lebih cepat 1 jam', 'WIT lebih lambat 2 jam', 'Tidak ada selisih'],
      'WIB = UTC+7, WITA = UTC+8, WIT = UTC+9.',
    ),
    _RawQuestion(
      QuizCategory.destinasi,
      'Zona waktu Arab Saudi adalah…',
      'UTC+3',
      ['UTC+1', 'UTC+5', 'UTC+7'],
      'Arab Saudi memakai Arabia Standard Time (UTC+3) dan tidak menerapkan jam musim panas.',
    ),
  ];
}
