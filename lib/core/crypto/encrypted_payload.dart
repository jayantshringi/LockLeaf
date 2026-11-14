import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Versioned, self-describing container for authenticated ciphertext.
///
/// Binary layout (`v1`):
/// `[version (1B)] [algorithm wireId (1B)] [nonce] [cipherText] [mac (16B)]`
class EncryptedPayload {
  /// Current binary envelope format version.
  static const int currentVersion = 1;
  static const int _headerLengthBytes = 2;

  /// Format version embedded in the envelope header.
  final int version;

  /// AEAD cipher algorithm used to produce this payload.
  final VaultCipherAlgorithm algorithm;

  final Uint8List _nonce;
  final Uint8List _cipherText;
  final Uint8List _mac;

  EncryptedPayload._({
    required this.version,
    required this.algorithm,
    required Uint8List nonce,
    required Uint8List cipherText,
    required Uint8List mac,
  }) : _nonce = nonce,
       _cipherText = cipherText,
       _mac = mac;

  /// Creates a validated [EncryptedPayload] from raw cryptographic components.
  factory EncryptedPayload({
    int version = currentVersion,
    required VaultCipherAlgorithm algorithm,
    required List<int> nonce,
    required List<int> cipherText,
    required List<int> mac,
  }) {
    if (version != currentVersion) {
      throw const CryptoException('Unsupported encrypted payload version.');
    }
    if (nonce.length != algorithm.nonceLength) {
      throw const CryptoException(
        'Nonce length does not match cipher algorithm.',
      );
    }
    if (mac.length != algorithm.macLength) {
      throw const CryptoException(
        'MAC tag length does not match cipher algorithm.',
      );
    }
    return EncryptedPayload._(
      version: version,
      algorithm: algorithm,
      nonce: Uint8List.fromList(nonce),
      cipherText: Uint8List.fromList(cipherText),
      mac: Uint8List.fromList(mac),
    );
  }

  /// Constructs an [EncryptedPayload] from a `package:cryptography` [SecretBox].
  factory EncryptedPayload.fromSecretBox({
    required VaultCipherAlgorithm algorithm,
    required SecretBox secretBox,
  }) {
    return EncryptedPayload(
      algorithm: algorithm,
      nonce: secretBox.nonce,
      cipherText: secretBox.cipherText,
      mac: secretBox.mac.bytes,
    );
  }

  /// Defensive copy of the unique cryptographic nonce.
  Uint8List get nonce => Uint8List.fromList(_nonce);

  /// Defensive copy of the encrypted payload bytes.
  Uint8List get cipherText => Uint8List.fromList(_cipherText);

  /// Defensive copy of the Poly1305 or GHASH authentication tag.
  Uint8List get mac => Uint8List.fromList(_mac);

  /// Converts this envelope back into a [SecretBox] for decryption.
  SecretBox toSecretBox() {
    return SecretBox(_cipherText, nonce: _nonce, mac: Mac(_mac));
  }

  /// Serializes the version header, algorithm ID, nonce, ciphertext, and MAC.
  Uint8List toBytes() {
    final totalLength =
        _headerLengthBytes + _nonce.length + _cipherText.length + _mac.length;
    final buffer = Uint8List(totalLength);

    var offset = 0;
    buffer[offset++] = version;
    buffer[offset++] = algorithm.wireId;

    buffer.setRange(offset, offset + _nonce.length, _nonce);
    offset += _nonce.length;

    buffer.setRange(offset, offset + _cipherText.length, _cipherText);
    offset += _cipherText.length;

    buffer.setRange(offset, offset + _mac.length, _mac);
    return buffer;
  }

  /// Parses and validates an [EncryptedPayload] from serialized [bytes].
  factory EncryptedPayload.fromBytes(List<int> bytes) {
    if (bytes.length < _headerLengthBytes) {
      throw const CryptoException('Encrypted payload is truncated.');
    }

    final version = bytes[0];
    if (version != currentVersion) {
      throw const CryptoException('Unsupported encrypted payload version.');
    }

    final algorithm = VaultCipherAlgorithm.fromWireId(bytes[1]);
    final minExpectedLength =
        _headerLengthBytes + algorithm.nonceLength + algorithm.macLength;
    if (bytes.length < minExpectedLength) {
      throw const CryptoException(
        'Encrypted payload is shorter than minimum header and MAC size.',
      );
    }

    const nonceStart = _headerLengthBytes;
    final nonceEnd = nonceStart + algorithm.nonceLength;
    final macStart = bytes.length - algorithm.macLength;

    return EncryptedPayload._(
      version: version,
      algorithm: algorithm,
      nonce: Uint8List.fromList(bytes.sublist(nonceStart, nonceEnd)),
      cipherText: Uint8List.fromList(bytes.sublist(nonceEnd, macStart)),
      mac: Uint8List.fromList(bytes.sublist(macStart)),
    );
  }

  /// Encodes the serialized payload as a URL-safe Base64 string.
  String toBase64() => base64Url.encode(toBytes());

  /// Decodes a Base64-encoded [EncryptedPayload] string.
  factory EncryptedPayload.fromBase64(String encoded) {
    final trimmed = encoded.trim();
    if (trimmed.isEmpty) {
      throw const CryptoException('Encoded payload string cannot be empty.');
    }
    try {
      final decoded = base64Url.decode(trimmed);
      return EncryptedPayload.fromBytes(decoded);
    } on FormatException {
      throw const CryptoException('Invalid Base64 encrypted payload.');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedPayload &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          algorithm == other.algorithm &&
          _listEquals(_nonce, other._nonce) &&
          _listEquals(_cipherText, other._cipherText) &&
          _listEquals(_mac, other._mac);

  static bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    version,
    algorithm,
    Object.hashAll(_nonce),
    Object.hashAll(_cipherText),
    Object.hashAll(_mac),
  );
}
