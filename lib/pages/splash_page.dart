import 'dart:async';

import 'package:flutter/material.dart';

import 'login_page.dart';

const Color _green = Color(0xFF176B50);
const Color _cream = Color(0xFFFCFCF9);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final PageController _controller = PageController();
  Timer? _autoSlide;
  int _page = 0;

  static const List<String> _slides = [
    'Persiapan lebih mudah,\nibadah lebih khusyuk',
    'Panduan manasik, doa, dan\nitinerary dalam satu aplikasi',
    'Pengingat, checklist, dan\ncatatan pengeluaran perjalananmu',
  ];

  @override
  void initState() {
    super.initState();
    _autoSlide = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoSlide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _buildIllustration() {
    return Image.asset(
      'lib/assets/splash_kaaba.png',
      width: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      errorBuilder: (_, __, ___) =>
          CustomPaint(painter: _SkylinePainter(), size: Size.infinite),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _page ? _green : Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9ED2CB), Color(0xFFE6F0E3), _cream],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: height * 0.20,
              height: height * 0.49,
              child: _buildIllustration(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.30,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00FCFCF9), Color(0xF2FCFCF9)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: height * 0.04),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 16),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'lib/assets/logo_safarmate.png',
                          height: 96,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.mosque_rounded,
                            size: 90,
                            color: _green,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'SafarMate',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Teman Perjalanan Ibadahmu',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 64,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (_, index) => Center(
                        child: Text(
                          _slides[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDots(),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _start,
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Mulai',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final groundTop = h * 0.86;
    canvas.drawRect(
      Rect.fromLTRB(0, groundTop, w, h),
      Paint()..color = const Color(0xFFEFE9DA),
    );
    final crowd = Paint()..color = const Color(0xFFB7AE98);
    for (int row = 0; row < 3; row++) {
      for (int i = 0; i < 28; i++) {
        final x = (i + (row.isEven ? 0.3 : 0.8)) * (w / 28);
        final y = groundTop + h * 0.025 + row * h * 0.035;
        canvas.drawCircle(Offset(x, y), 2.2 + row * 0.5, crowd);
      }
    }

    void minaret(double cx, double top, double width) {
      final body = Paint()..color = const Color(0xFFE9DFC9);
      final shade = Paint()..color = const Color(0xFFD9CCAE);
      final bottom = groundTop;

      canvas.drawRect(
        Rect.fromLTRB(cx - width / 2, top, cx + width / 2, bottom),
        body,
      );
      canvas.drawRect(Rect.fromLTRB(cx, top, cx + width / 2, bottom), shade);
      canvas.drawRect(
        Rect.fromLTRB(
          cx - width * 0.85,
          top + h * 0.09,
          cx + width * 0.85,
          top + h * 0.115,
        ),
        shade,
      );
      final cap = Path()
        ..moveTo(cx - width * 0.7, top)
        ..quadraticBezierTo(cx, top - h * 0.12, cx + width * 0.7, top)
        ..close();
      canvas.drawPath(cap, Paint()..color = const Color(0xFF8E9B8F));
      canvas.drawRect(
        Rect.fromLTWH(cx - 1, top - h * 0.15, 2, h * 0.05),
        Paint()..color = const Color(0xFFB9A57A),
      );
    }

    minaret(w * 0.13, h * 0.30, w * 0.045);
    minaret(w * 0.28, h * 0.46, w * 0.035);
    minaret(w * 0.74, h * 0.46, w * 0.035);
    minaret(w * 0.88, h * 0.30, w * 0.045);

    // Ka'bah.
    final kw = w * 0.42;
    final kh = h * 0.34;
    final kx = (w - kw) / 2;
    final ky = groundTop - kh;

    final top = Path()
      ..moveTo(kx, ky)
      ..lineTo(kx + kw, ky)
      ..lineTo(kx + kw - kw * 0.07, ky - kh * 0.12)
      ..lineTo(kx + kw * 0.07, ky - kh * 0.12)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xFF3A3A3A));

    canvas.drawRect(
      Rect.fromLTWH(kx, ky, kw, kh),
      Paint()..color = const Color(0xFF161616),
    );

    canvas.drawRect(
      Rect.fromLTWH(kx, ky + kh * 0.16, kw, kh * 0.09),
      Paint()..color = const Color(0xFFC9A24B),
    );
    canvas.drawRect(
      Rect.fromLTWH(kx + kw * 0.62, ky + kh * 0.48, kw * 0.1, kh * 0.38),
      Paint()..color = const Color(0xFFB08A3A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
