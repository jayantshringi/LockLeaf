import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/argon2id_kdf_service.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

void main() {
  late Argon2idKdfService kdfService;
  late SecureRandomService randomService;
  late KdfParams fastTestParams;

  String generateEphemeralInput() {
    final codes = List<int>.generate(
      20,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    kdfService = Argon2idKdfService();
    randomService = SecureRandomService();
    fastTestParams = KdfParams(
      memoryKiB: 256,
      iterations: 1,
      parallelism: 1,
      hashLength: 32,
    );
  });

  group('Argon2idKdfService', () {
    test('derives deterministic key for identical input and salt', () async {
      final input = generateEphemeralInput();
      final salt = randomService.generateSalt();

      final key1 = await kdfService.deriveMasterKey(
        masterPassword: input,
        salt: salt,
        params: fastTestParams,
      );
      final key2 = await kdfService.deriveMasterKey(
        masterPassword: input,
        salt: salt,
        params: fastTestParams,
      );

      final bytes1 = key1.copyBytes();
      final bytes2 = key2.copyBytes();
      try {
        expect(bytes1.length, equals(32));
        expect(bytes1, equals(bytes2));
      } finally {
        SecureMemory.wipeBytes(bytes1);
        SecureMemory.wipeBytes(bytes2);
        key1.destroy();
        key2.destroy();
      }
    });

    test('derives distinct keys when salt changes', () async {
      final input = generateEphemeralInput();
      final salt1 = randomService.generateSalt();
      final salt2 = randomService.generateSalt();

      final key1 = await kdfService.deriveMasterKey(
        masterPassword: input,
        salt: salt1,
        params: fastTestParams,
      );
      final key2 = await kdfService.deriveMasterKey(
        masterPassword: input,
        salt: salt2,
        params: fastTestParams,
      );

      final bytes1 = key1.copyBytes();
      final bytes2 = key2.copyBytes();
      try {
        expect(bytes1, isNot(equals(bytes2)));
      } finally {
        SecureMemory.wipeBytes(bytes1);
        SecureMemory.wipeBytes(bytes2);
        key1.destroy();
        key2.destroy();
      }
    });

    test('derives distinct keys when input changes', () async {
      final input1 = generateEphemeralInput();
      final input2 = generateEphemeralInput();
      final salt = randomService.generateSalt();

      final key1 = await kdfService.deriveMasterKey(
        masterPassword: input1,
        salt: salt,
        params: fastTestParams,
      );
      final key2 = await kdfService.deriveMasterKey(
        masterPassword: input2,
        salt: salt,
        params: fastTestParams,
      );

      final bytes1 = key1.copyBytes();
      final bytes2 = key2.copyBytes();
      try {
        expect(bytes1, isNot(equals(bytes2)));
      } finally {
        SecureMemory.wipeBytes(bytes1);
        SecureMemory.wipeBytes(bytes2);
        key1.destroy();
        key2.destroy();
      }
    });

    test('rejects empty password or short salt', () async {
      final validSalt = randomService.generateSalt();
      final shortSalt = Uint8List.fromList(List<int>.generate(8, (i) => i));

      await expectLater(
        kdfService.deriveMasterKey(
          masterPassword: '',
          salt: validSalt,
          params: fastTestParams,
        ),
        throwsA(isA<CryptoException>()),
      );

      await expectLater(
        kdfService.deriveMasterKey(
          masterPassword: generateEphemeralInput(),
          salt: shortSalt,
          params: fastTestParams,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('derives domain-separated subkeys via HKDF', () async {
      final salt = randomService.generateSalt();
      final master = await kdfService.deriveMasterKey(
        masterPassword: generateEphemeralInput(),
        salt: salt,
        params: fastTestParams,
      );

      final encSubkey = await kdfService.deriveSubkey(
        masterKey: master,
        context: 'lockleaf-vault-enc-v1',
      );
      final authSubkey = await kdfService.deriveSubkey(
        masterKey: master,
        context: 'lockleaf-auth-verifier-v1',
      );

      final encBytes = encSubkey.copyBytes();
      final authBytes = authSubkey.copyBytes();
      try {
        expect(encBytes.length, equals(32));
        expect(authBytes.length, equals(32));
        expect(encBytes, isNot(equals(authBytes)));
      } finally {
        SecureMemory.wipeBytes(encBytes);
        SecureMemory.wipeBytes(authBytes);
        encSubkey.destroy();
        authSubkey.destroy();
        master.destroy();
      }
    });

    test('rejects subkey derivation from destroyed master key', () async {
      final salt = randomService.generateSalt();
      final master = await kdfService.deriveMasterKey(
        masterPassword: generateEphemeralInput(),
        salt: salt,
        params: fastTestParams,
      );
      master.destroy();

      await expectLater(
        kdfService.deriveSubkey(
          masterKey: master,
          context: 'lockleaf-vault-enc-v1',
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}
