import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_page.dart';
import 'splash_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.startUnlocked = false});

  final bool startUnlocked;

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const SplashPage();
    }

    return const DashboardPage();
  }
}
