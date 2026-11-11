import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

void main() {
  late SecureRandomService randomService;
  late CipherService cipherService;
  late ManagedSecretKey activeKey;

  ManagedSecretKey createEphemeralKey({int bytes = 32}) {
    final raw = randomService.generateBytes(bytes);
    try {
      return ManagedSecretKey.fromBytes(raw);
    } finally {
      SecureMemory.wipeBytes(raw);
    }
  }

  setUp(() {
    randomService = SecureRandomService();
    cipherService = CipherService(randomService: randomService);
    activeKey = createEphemeralKey();
  });

  tearDown(() {
    activeKey.destroy();
  });

  group('CipherService AEAD round-trip', () {
    test('encrypts and decrypts bytes with XChaCha20-Poly1305', () async {
      final plaintext = randomService.generateBytes(128);

      final encrypted = await cipherService.encryptBytes(
        plaintext: plaintext,
        key: activeKey,
        algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
      );

      final roundTripped = EncryptedPayload.fromBase64(encrypted.toBase64());
      final decrypted = await cipherService.decryptBytes(
        payload: roundTripped,
        key: activeKey,
      );

      expect(encrypted.algorithm, equals(VaultCipherAlgorithm.xchacha20Poly1305));
      expect(encrypted.nonce.length, equals(24));
      expect(decrypted, equals(plaintext));
    });

    test('encrypts and decrypts bytes with AES-256-GCM', () async {
      final plaintext = randomService.generateBytes(96);

      final encrypted = await cipherService.encryptBytes(
        plaintext: plaintext,
        key: activeKey,
        algorithm: VaultCipherAlgorithm.aes256Gcm,
      );

      final decrypted = await cipherService.decryptBytes(
        payload: encrypted,
        key: activeKey,
      );

      expect(encrypted.algorithm, equals(VaultCipherAlgorithm.aes256Gcm));
      expect(encrypted.nonce.length, equals(12));
      expect(decrypted, equals(plaintext));
    });

    test('encrypts and decrypts UTF-8 strings with AAD binding', () async {
      const sampleText = 'Leaf entry \u{1F343} unicode payload';
      const contextAad = 'vault:entry:v1:0001';

      final encrypted = await cipherService.encryptString(
        plaintext: sampleText,
        key: activeKey,
        associatedData: contextAad,
      );

      final decrypted = await cipherService.decryptString(
        payload: encrypted,
        key: activeKey,
        associatedData: contextAad,
      );

      expect(decrypted, equals(sampleText));
    });
  });

  group('CipherService security guarantees', () {
    test('uses a unique random nonce for every encryption call', () async {
      final plaintext = randomService.generateBytes(32);
      final seenNonces = <String>{};
      final seenCiphertexts = <String>{};

      for (var i = 0; i < 20; i++) {
        final payload = await cipherService.encryptBytes(
          plaintext: plaintext,
          key: activeKey,
        );
        seenNonces.add(payload.nonce.join(','));
        seenCiphertexts.add(payload.cipherText.join(','));
      }

      expect(seenNonces.length, equals(20));
      expect(seenCiphertexts.length, equals(20));
    });

    test('rejects tampered ciphertext, MAC, and nonce', () async {
      final plaintext = randomService.generateBytes(40);
      final payload = await cipherService.encryptBytes(
        plaintext: plaintext,
        key: activeKey,
      );

      final tamperedCipher = payload.cipherText;
      tamperedCipher[0] ^= 0x01;
      await expectLater(
        cipherService.decryptBytes(
          payload: EncryptedPayload(
            algorithm: payload.algorithm,
            nonce: payload.nonce,
            cipherText: tamperedCipher,
            mac: payload.mac,
          ),
          key: activeKey,
        ),
        throwsA(isA<CryptoException>()),
      );

      final tamperedMac = payload.mac;
      tamperedMac[0] ^= 0x01;
      await expectLater(
        cipherService.decryptBytes(
          payload: EncryptedPayload(
            algorithm: payload.algorithm,
            nonce: payload.nonce,
            cipherText: payload.cipherText,
            mac: tamperedMac,
          ),
          key: activeKey,
        ),
        throwsA(isA<CryptoException>()),
      );

      final tamperedNonce = payload.nonce;
      tamperedNonce[0] ^= 0x01;
      await expectLater(
        cipherService.decryptBytes(
          payload: EncryptedPayload(
            algorithm: payload.algorithm,
            nonce: tamperedNonce,
            cipherText: payload.cipherText,
            mac: payload.mac,
          ),
          key: activeKey,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('rejects decryption with wrong key or mismatched AAD', () async {
      final wrongKey = createEphemeralKey();
      final aad = Uint8List.fromList(<int>[10, 20, 30]);
      final otherAad = Uint8List.fromList(<int>[10, 20, 31]);

      try {
        final payload = await cipherService.encryptBytes(
          plaintext: randomService.generateBytes(32),
          key: activeKey,
          associatedData: aad,
        );

        await expectLater(
          cipherService.decryptBytes(
            payload: payload,
            key: wrongKey,
            associatedData: aad,
          ),
          throwsA(isA<CryptoException>()),
        );

        await expectLater(
          cipherService.decryptBytes(
            payload: payload,
            key: activeKey,
            associatedData: otherAad,
          ),
          throwsA(isA<CryptoException>()),
        );
      } finally {
        wrongKey.destroy();
      }
    });

    test('rejects destroyed keys and invalid key lengths', () async {
      final shortKey = createEphemeralKey(bytes: 16);
      try {
        await expectLater(
          cipherService.encryptBytes(
            plaintext: randomService.generateBytes(16),
            key: shortKey,
          ),
          throwsA(isA<CryptoException>()),
        );
      } finally {
        shortKey.destroy();
      }

      activeKey.destroy();
      await expectLater(
        cipherService.encryptBytes(
          plaintext: randomService.generateBytes(16),
          key: activeKey,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}

