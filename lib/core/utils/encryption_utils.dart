import 'dart:convert';

/// Encryption utilities (AES-256 / XOR for demo).
/// Use proper AES in production.
class EncryptionUtils {
  static String encrypt(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);

    final encrypted = <int>[];
    for (var i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(encrypted);
  }

  static String decrypt(String encrypted, String key) {
    final keyBytes = utf8.encode(key);
    final encryptedBytes = base64.decode(encrypted);

    final decrypted = <int>[];
    for (var i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(decrypted);
  }
}
