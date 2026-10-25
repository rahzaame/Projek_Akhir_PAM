import 'package:flutter/material.dart';

class SaranKesanPage extends StatelessWidget {
  const SaranKesanPage({super.key});

  static const Color primaryGreen = Color(0xFF176B52);
  static const Color lightGreen = Color(0xFFE2F2EA);
  static const Color backgroundColor = Color(0xFFF5F6F4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Saran dan Kesan',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header halaman
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: lightGreen,
                      child: Icon(
                        Icons.school_rounded,
                        size: 38,
                        color: primaryGreen,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saran dan Kesan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Mata Kuliah Pemrograman Aplikasi Mobile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _buildContentCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Saran',
                content:
                    'Semoga pembelajaran Pemrograman Aplikasi Mobile '
                    'semakin banyak disertai praktik langsung, contoh '
                    'proyek nyata, dan penjelasan secara bertahap agar '
                    'mahasiswa lebih mudah memahami pengembangan '
                    'aplikasi. Semoga juga tersedia lebih banyak '
                    'kesempatan untuk berdiskusi dan mencoba teknologi '
                    'baru dalam pengembangan aplikasi mobile.',
              ),

              const SizedBox(height: 16),

              _buildContentCard(
                icon: Icons.favorite_border_rounded,
                title: 'Kesan',
                content:
                    'Mata kuliah Pemrograman Aplikasi Mobile memberikan '
                    'pengalaman dan pengetahuan baru dalam membuat '
                    'aplikasi mobile. Kami belajar memahami proses '
                    'pengembangan aplikasi, mulai dari merancang '
                    'tampilan, menulis kode program, hingga '
                    'menghubungkan berbagai fitur agar dapat '
                    'berfungsi dengan baik. Meskipun dalam '
                    'perjalanannya cukup menguras tenaga '
                    'dan pikiran, setiap tantangan yang dilalui membuat '
                    'kami semakin kreatif, teliti, dan terbiasa '
                    'memecahkan masalah.',
              ),

              const SizedBox(height: 24),

              // Penutup
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: primaryGreen,
                      size: 34,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Terima Kasih!',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Terima kasih atas ilmu, bimbingan, dan '
                      'pengalaman belajar yang telah diberikan '
                      'selama perkuliahan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF3D5E4D),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryGreen, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 14,
              height: 1.8,
              color: Color(0xFF45534B),
            ),
          ),
        ],
      ),
    );
  }
}
