import 'package:local_auth/local_auth.dart';

enum BiometricStatus { available, notEnrolled, notSupported }

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<BiometricStatus> status() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return BiometricStatus.notSupported;

      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isEmpty
          ? BiometricStatus.notEnrolled
          : BiometricStatus.available;
    } catch (_) {
      return BiometricStatus.notSupported;
    }
  }

  Future<bool> isBiometricAvailable() async {
    return await status() == BiometricStatus.available;
  }

  String messageFor(BiometricStatus status) {
    switch (status) {
      case BiometricStatus.available:
        return '';
      case BiometricStatus.notEnrolled:
        return 'Belum ada sidik jari atau wajah yang terdaftar di perangkat. '
            'Daftarkan dulu di Pengaturan perangkat.';
      case BiometricStatus.notSupported:
        return 'Perangkat ini tidak mendukung biometrik.';
    }
  }

  Future<bool> authenticate({
    String reason = 'Verifikasi biometrik untuk membuka SafarMate',
  }) async {
    try {
      if (!await isBiometricAvailable()) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
