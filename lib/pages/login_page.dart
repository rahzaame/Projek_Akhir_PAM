import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/biometric_credentials.dart';
import '../services/biometric_preferences.dart';
import '../services/biometric_service.dart';
import '../services/supabase_service.dart';
import 'auth_gate.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();

  final _biometric = BiometricService();
  final _biometricPrefs = BiometricPreferences();
  final _credentials = BiometricCredentials();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _rememberMe = true;
  bool _biometricBusy = false;
  BiometricStatus _biometricStatus = BiometricStatus.notSupported;

  static const Color _green = Color(0xFF176B50);
  static const Color _softGreen = Color(0xFFEAF4EF);

  static const String _rememberKey = 'login_remember_me';
  static const String _emailKey = 'login_remembered_email';
  static const String _promptedKey = 'biometric_prompted';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? true;
    final email = prefs.getString(_emailKey) ?? '';
    final status = await _biometric.status();

    if (!mounted) return;

    setState(() {
      _rememberMe = remember;
      if (remember && email.isNotEmpty && _emailController.text.isEmpty) {
        _emailController.text = email;
      }
      _biometricStatus = status;
    });
  }

  Future<BiometricStatus> _refreshBiometricStatus() async {
    final status = await _biometric.status();
    if (mounted) setState(() => _biometricStatus = status);
    return status;
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : null,
        ),
      );
  }

  Future<void> _saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  void _goToApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(startUnlocked: true)),
      (route) => false,
    );
  }

  Future<void> _syncBiometric(String email, String password) async {
    try {
      final status = await _biometric.status();
      if (status != BiometricStatus.available) return;

      if (await _biometricPrefs.isEnabled()) {
        await _credentials.save(email: email, password: password);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_promptedKey) ?? false) return;
      if (!mounted) return;

      final agree = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aktifkan login biometrik?'),
          content: const Text(
            'Lain kali kamu bisa masuk cukup dengan sidik jari atau wajah, '
            'tanpa mengetik password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Nanti saja'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      );

      await prefs.setBool(_promptedKey, true);
      if (agree != true) return;

      final ok = await _biometric.authenticate(
        reason: 'Verifikasi untuk mengaktifkan login biometrik',
      );

      if (!mounted) return;

      if (!ok) {
        _snack('Verifikasi biometrik gagal. Bisa diaktifkan lagi dari Profil.');
        return;
      }

      await _credentials.save(email: email, password: password);
      await _biometricPrefs.setEnabled(true);

      if (!mounted) return;
      _snack('Login biometrik diaktifkan.');
    } catch (e) {
      debugPrint('Gagal menyiapkan biometrik: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await _supabaseService.signIn(email: email, password: password);

      await _saveRememberedEmail(email);
      await _syncBiometric(email, password);

      if (!mounted) return;
      _goToApp();
    } on AuthException catch (error) {
      if (!mounted) return;
      _snack('Login gagal: ${error.message}', error: true);
    } catch (error) {
      if (!mounted) return;
      _snack(
        'Terjadi kesalahan. Periksa koneksi dan konfigurasi.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_biometricBusy || _isLoading) return;

    setState(() => _biometricBusy = true);

    try {
      final status = await _refreshBiometricStatus();
      if (status != BiometricStatus.available) {
        if (!mounted) return;
        _snack(_biometric.messageFor(status));
        return;
      }

      final enabled = await _biometricPrefs.isEnabled();
      final saved = await _credentials.read();

      if (!enabled || saved == null) {
        if (!mounted) return;
        _snack(
          'Login biometrik belum aktif. Masuk dengan password sekali, '
          'lalu aktifkan biometrik.',
        );
        return;
      }

      final ok = await _biometric.authenticate(
        reason: 'Verifikasi untuk masuk ke SafarMate',
      );

      if (!mounted) return;

      if (!ok) {
        _snack('Verifikasi biometrik dibatalkan atau gagal.');
        return;
      }

      setState(() => _isLoading = true);

      await _supabaseService.signIn(
        email: saved.email,
        password: saved.password,
      );

      if (!mounted) return;
      _goToApp();
    } on AuthApiException catch (error) {
      if (error.message.toLowerCase().contains('invalid')) {
        await _credentials.clear();
        if (!mounted) return;
        _snack(
          'Data login tersimpan sudah tidak valid. Masuk dengan password.',
          error: true,
        );
      } else {
        if (!mounted) return;
        _snack('Login gagal: ${error.message}', error: true);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      _snack('Login gagal: ${error.message}', error: true);
    } catch (error) {
      if (!mounted) return;
      _snack(
        'Terjadi kesalahan. Periksa koneksi dan konfigurasi.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _biometricBusy = false;
          _isLoading = false;
        });
      }
    }
  }

  void _openRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: border(Colors.grey.shade300),
      enabledBorder: border(Colors.grey.shade300),
      focusedBorder: border(_green),
    );
  }

  Widget _buildBiometricButton() {
    return Material(
      color: _softGreen,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (_isLoading || _biometricBusy) ? null : _loginWithBiometric,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_biometricBusy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                )
              else
                const Icon(Icons.fingerprint, color: _green, size: 26),
              const SizedBox(width: 10),
              const Text(
                'Masuk dengan biometrik',
                style: TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCF9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Image.asset(
                    'lib/assets/logo_safarmate.png',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.mosque_rounded,
                      size: 84,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SafarMate',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Masuk ke akun Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: _decoration(
                      hint: 'Email',
                      icon: Icons.mail_outline_rounded,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Email wajib diisi';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email)) {
                        return 'Masukkan email yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _login();
                    },
                    decoration: _decoration(
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _isLoading
                            ? null
                            : () => setState(() => _rememberMe = !_rememberMe),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: _green,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: _isLoading
                                      ? null
                                      : (v) => setState(
                                          () => _rememberMe = v ?? false,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ingat saya',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Lupa password?',
                          style: TextStyle(color: _green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: (_isLoading || _biometricBusy) ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'atau',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: (_isLoading || _biometricBusy)
                        ? null
                        : _openRegister,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Daftar akun',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBiometricButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
