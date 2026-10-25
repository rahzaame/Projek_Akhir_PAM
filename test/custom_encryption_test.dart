
import 'package:flutter_test/flutter_test.dart';
import 'package:projek_akhir_pam/services/custom_encryption.dart';

void main() {
  test('Enkripsi dan dekripsi mengembalikan teks semula', () {
    const original = 'SafarMate123';

    final encrypted = CustomEncryption.encrypt(original);
    final decrypted = CustomEncryption.decrypt(encrypted);

    expect(encrypted, isNot(original));
    expect(decrypted, original);
  });
}
