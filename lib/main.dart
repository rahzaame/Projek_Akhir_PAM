
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/biometric_service.dart';
import 'services/biometric_preferences.dart';
import 'supabase_config.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const SafarMateApp());
}

class SafarMateApp extends StatelessWidget {
  const SafarMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafarMate',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B50),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF176B50),
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _unlocked = false;
  bool _needsAuthentication = false;

  final BiometricService _biometric = BiometricService();
  final BiometricPreferences _preferences = BiometricPreferences();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _needsAuthentication = true;
    }

    if (state == AppLifecycleState.resumed &&
        _needsAuthentication &&
        !_checking) {
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    if (_checking && _unlocked) return;

    if (mounted) {
      setState(() {
        _checking = true;
      });
    }

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;

      // Belum login ke Supabase.
      if (session == null) {
        if (!mounted) return;

        setState(() {
          _unlocked = false;
          _checking = false;
          _needsAuthentication = false;
        });
        return;
      }

      // Periksa apakah fitur biometrik diaktifkan.
      final enabled = await _preferences.isEnabled();

      // Jika nonaktif, cukup gunakan sesi login Supabase.
      if (!enabled) {
        if (!mounted) return;

        setState(() {
          _unlocked = true;
          _checking = false;
          _needsAuthentication = false;
        });
        return;
      }

      // Jika aktif, wajib verifikasi biometrik.
      final authenticated = await _biometric.authenticate();

      if (!mounted) return;

      setState(() {
        _unlocked = authenticated;
        _checking = false;
        _needsAuthentication = !authenticated;
      });
    } catch (e) {
      debugPrint('Gagal memeriksa akses biometrik: $e');

      if (!mounted) return;

      setState(() {
        _unlocked = false;
        _checking = false;
        _needsAuthentication = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // Tidak ada sesi login: tampilkan halaman login.
    if (session == null) {
      return const LoginPage();
    }

    // Sedang memeriksa akses.
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Verifikasi berhasil atau biometrik dinonaktifkan.
    if (_unlocked) {
      return const DashboardPage();
    }

    // Verifikasi gagal atau dibatalkan: dashboard tetap terkunci.
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Verifikasi biometrik untuk membuka SafarMate',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _checking ? null : _checkAccess,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
