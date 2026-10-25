import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/biometric_preferences.dart';
import '../services/biometric_service.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.startUnlocked = false});

  /// true jika pengguna baru saja login (sudah terverifikasi), sehingga tidak
  /// perlu meminta biometrik lagi saat pertama kali masuk.
  final bool startUnlocked;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _unlocked = false;
  bool _needsAuthentication = false;

  // Dialog biometrik itu sendiri memicu perubahan lifecycle (inactive/resumed).
  // Dua variabel ini mencegah kunci ulang berulang-ulang (loop).
  bool _authInProgress = false;
  DateTime _lastAuthAt = DateTime.fromMillisecondsSinceEpoch(0);

  final BiometricService _biometric = BiometricService();
  final BiometricPreferences _preferences = BiometricPreferences();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.startUnlocked) {
      _checking = false;
      _unlocked = true;
    } else {
      _checkAccess();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authInProgress) return;
    if (DateTime.now().difference(_lastAuthAt) < const Duration(seconds: 2)) {
      return;
    }

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

      if (session == null) {
        if (!mounted) return;

        setState(() {
          _unlocked = false;
          _checking = false;
          _needsAuthentication = false;
        });
        return;
      }

      final enabled = await _preferences.isEnabled();

      if (!enabled) {
        if (!mounted) return;

        setState(() {
          _unlocked = true;
          _checking = false;
          _needsAuthentication = false;
        });
        return;
      }

      _authInProgress = true;
      final authenticated = await _biometric.authenticate();
      _authInProgress = false;
      _lastAuthAt = DateTime.now();

      if (!mounted) return;

      setState(() {
        _unlocked = authenticated;
        _checking = false;
        _needsAuthentication = !authenticated;
      });
    } catch (e) {
      _authInProgress = false;
      debugPrint('Gagal memeriksa akses biometrik: $e');

      if (!mounted) return;

      setState(() {
        _unlocked = false;
        _checking = false;
        _needsAuthentication = true;
      });
    }
  }

  // Jalan keluar jika biometrik tidak bisa dipakai (mis. sidik jari dihapus).
  Future<void> _signOutToLogin() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    setState(() {
      _unlocked = false;
      _checking = false;
      _needsAuthentication = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginPage();
    }

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_unlocked) {
      return const DashboardPage();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 64),
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: _signOutToLogin,
                child: const Text('Keluar & masuk dengan password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
