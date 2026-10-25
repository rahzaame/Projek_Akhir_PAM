import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    final isSupported = await _auth.isDeviceSupported();
    final biometrics = await _auth.getAvailableBiometrics();

    return isSupported && biometrics.isNotEmpty;
  }

  Future<bool> authenticate() async {
    try {
      if (!await isBiometricAvailable()) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Verifikasi biometrik untuk membuka SafarMate',
        biometricOnly: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
