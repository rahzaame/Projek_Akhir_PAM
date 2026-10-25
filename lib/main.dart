
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/biometric_service.dart';
import 'services/biometric_preferences.dart';
import 'supabase_config.dart';
import 'pages/reset_password_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

StreamSubscription<AuthState>? _authSubscription;
bool _resetPageOpening = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Dengarkan event autentikasi, termasuk pemulihan password.
  _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
    (authState) {
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        _openResetPasswordPage();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      debugPrint('Auth state error: $error');
    },
  );

  await NotificationService.instance.init();

  runApp(const SafarMateApp());
}

void _openResetPasswordPage() {
  if (_resetPageOpening) return;

  _resetPageOpening = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;

    if (navigator == null) {
      debugPrint(
        'Navigator belum siap. Event reset password diterima.',
      );
      _resetPageOpening = false;
      return;
    }

    navigator
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const ResetPasswordPage(),
          ),
        )
        .whenComplete(() {
          _resetPageOpening = false;
        });
  });
}

class SafarMateApp extends StatelessWidget {
  const SafarMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
  final BiometricPreferences _preferences =
      BiometricPreferences();

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
    final session =
        Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginPage();
    }

    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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
            ],
          ),
        ),
      ),
    );
  }
}
