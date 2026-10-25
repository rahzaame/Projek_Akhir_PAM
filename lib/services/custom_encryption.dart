import 'dart:convert';

class CustomEncryption {
  static const int _key = 7;

  static String encrypt(String input) {
    final bytes = utf8.encode(input);

    final encryptedBytes = bytes.map((byte) => (byte + _key) % 256).toList();

    return base64Encode(encryptedBytes);
  }

  static String decrypt(String encryptedText) {
    final bytes = base64Decode(encryptedText);

    final decryptedBytes = bytes
        .map((byte) => (byte - _key + 256) % 256)
        .toList();

    return utf8.decode(decryptedBytes);
  }
}
