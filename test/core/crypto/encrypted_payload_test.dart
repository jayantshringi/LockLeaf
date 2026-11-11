import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

void main() {
  late SecureRandomService randomService;

  setUp(() {
    randomService = SecureRandomService();
  });

  group('EncryptedPayload', () {
    test('round-trips binary serialization for XChaCha20-Poly1305', () {
      final nonce = randomService.generateNonce(
        VaultCipherAlgorithm.xchacha20Poly1305.nonceLength,
      );
      final cipherText = randomService.generateBytes(48);
      final mac = randomService.generateBytes(
        VaultCipherAlgorithm.xchacha20Poly1305.macLength,
      );

      final original = EncryptedPayload(
        algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        nonce: nonce,
        cipherText: cipherText,
        mac: mac,
      );

      final parsed = EncryptedPayload.fromBytes(original.toBytes());

      expect(parsed.version, equals(EncryptedPayload.currentVersion));
      expect(parsed.algorithm, equals(VaultCipherAlgorithm.xchacha20Poly1305));
      expect(parsed.nonce, equals(nonce));
      expect(parsed.cipherText, equals(cipherText));
      expect(parsed.mac, equals(mac));
    });

    test('round-trips Base64 encoding for AES-256-GCM', () {
      final nonce = randomService.generateNonce(
        VaultCipherAlgorithm.aes256Gcm.nonceLength,
      );
      final cipherText = randomService.generateBytes(24);
      final mac = randomService.generateBytes(
        VaultCipherAlgorithm.aes256Gcm.macLength,
      );

      final original = EncryptedPayload(
        algorithm: VaultCipherAlgorithm.aes256Gcm,
        nonce: nonce,
        cipherText: cipherText,
        mac: mac,
      );

      final parsed = EncryptedPayload.fromBase64(original.toBase64());

      expect(parsed.algorithm, equals(VaultCipherAlgorithm.aes256Gcm));
      expect(parsed.nonce, equals(nonce));
      expect(parsed.cipherText, equals(cipherText));
      expect(parsed.mac, equals(mac));
    });

    test('rejects mismatched nonce or MAC lengths', () {
      final validMac = randomService.generateBytes(16);

      expect(
        () => EncryptedPayload(
          algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          nonce: randomService.generateNonce(12),
          cipherText: Uint8List(10),
          mac: validMac,
        ),
        throwsA(isA<CryptoException>()),
      );

      expect(
        () => EncryptedPayload(
          algorithm: VaultCipherAlgorithm.aes256Gcm,
          nonce: randomService.generateNonce(12),
          cipherText: Uint8List(10),
          mac: randomService.generateBytes(8),
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('rejects corrupted binary headers and malformed Base64', () {
      expect(
        () => EncryptedPayload.fromBytes(<int>[1]),
        throwsA(isA<CryptoException>()),
      );

      expect(
        () => EncryptedPayload.fromBytes(Uint8List(50)..[0] = 99),
        throwsA(isA<CryptoException>()),
      );

      expect(
        () => EncryptedPayload.fromBytes(
          Uint8List(50)
            ..[0] = 1
            ..[1] = 250,
        ),
        throwsA(isA<CryptoException>()),
      );

      expect(
        () => EncryptedPayload.fromBase64(''),
        throwsA(isA<CryptoException>()),
      );

      expect(
        () => EncryptedPayload.fromBase64('!!!not-valid-base64!!!'),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}

