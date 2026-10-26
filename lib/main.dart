import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'pages/auth_gate.dart';
import 'pages/reset_password_page.dart';
import 'services/notification_service.dart';
import 'tema/tema_app.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

StreamSubscription<AuthState>? _authSubscription;
bool _resetPageOpening = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );

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
      debugPrint('Navigator belum siap. Event reset password diterima.');
      _resetPageOpening = false;
      return;
    }

    navigator
        .push(
          MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
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
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
