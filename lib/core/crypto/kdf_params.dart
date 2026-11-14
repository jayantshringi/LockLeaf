import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Immutable Argon2id key derivation parameters.
class KdfParams extends Equatable {
  /// Memory cost in kibibytes (1 KiB blocks).
  final int memoryKiB;

  /// Time cost (number of passes over memory).
  final int iterations;

  /// Degree of parallelism (number of lanes).
  final int parallelism;

  /// Derived key length in bytes.
  final int hashLength;

  const KdfParams._({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  /// Creates validated Argon2id parameters following RFC 9106 constraints.
  factory KdfParams({
    required int memoryKiB,
    required int iterations,
    required int parallelism,
    int hashLength = SecurityConstants.derivedKeyLengthBytes,
  }) {
    if (parallelism < 1 || parallelism > 16) {
      throw const CryptoException(
        'Argon2id parallelism must be between 1 and 16.',
      );
    }
    if (iterations < 1) {
      throw const CryptoException('Argon2id iterations must be at least 1.');
    }
    if (memoryKiB < 8 * parallelism) {
      throw const CryptoException(
        'Argon2id memory must be at least 8 * parallelism KiB.',
      );
    }
    if (hashLength < 16 || hashLength > 64) {
      throw const CryptoException(
        'Derived key length must be between 16 and 64 bytes.',
      );
    }
    return KdfParams._(
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
  }

  /// Production OWASP-aligned baseline parameters (64 MiB, 3 iterations, 4 lanes).
  const KdfParams.standard()
    : memoryKiB = SecurityConstants.argon2MemoryKiB,
      iterations = SecurityConstants.argon2Iterations,
      parallelism = SecurityConstants.argon2Parallelism,
      hashLength = SecurityConstants.derivedKeyLengthBytes;

  /// Whether these parameters meet LockLeaf's minimum production security policy.
  bool get meetsProductionBaseline =>
      memoryKiB >= SecurityConstants.argon2MemoryKiB &&
      iterations >= SecurityConstants.argon2Iterations &&
      parallelism >= 1 &&
      hashLength >= SecurityConstants.derivedKeyLengthBytes;

  /// Serializes parameters for storage in vault metadata or backup headers.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'memoryKiB': memoryKiB,
      'iterations': iterations,
      'parallelism': parallelism,
      'hashLength': hashLength,
    };
  }

  /// Parses and validates [KdfParams] from decoded JSON metadata.
  factory KdfParams.fromJson(Map<String, dynamic> json) {
    final memoryKiB = json['memoryKiB'];
    final iterations = json['iterations'];
    final parallelism = json['parallelism'];
    final hashLength = json['hashLength'];

    if (memoryKiB is! int ||
        iterations is! int ||
        parallelism is! int ||
        hashLength is! int) {
      throw const CryptoException('Invalid or incomplete KDF parameters.');
    }

    return KdfParams(
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
  }

  @override
  List<Object?> get props => [memoryKiB, iterations, parallelism, hashLength];
}
