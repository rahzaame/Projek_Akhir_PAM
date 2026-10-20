import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B50)),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF176B50),
          foregroundColor: Colors.white,
        ),
      ),
      home: Supabase.instance.client.auth.currentSession != null
          ? const DashboardPage()
          : const LoginPage(),
    );
  }
}
