import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Active unlocked vault session holding the in-memory Data Encryption Key.
///
/// Locking the session immediately zeroes and destroys the DEK from memory.
class VaultSession {
  /// Identifier of the unlocked vault.
  final String vaultId;

  /// Cipher algorithm configured for this vault's entries.
  final VaultCipherAlgorithm cipherAlgorithm;

  /// UTC timestamp when this session was unlocked.
  final DateTime unlockedAt;

  final ManagedSecretKey _dek;

  /// Creates an active [VaultSession] wrapping an unlocked [dek].
  VaultSession({
    required this.vaultId,
    required ManagedSecretKey dek,
    required this.cipherAlgorithm,
    DateTime? unlockedAt,
  })  : _dek = dek,
        unlockedAt = (unlockedAt ?? DateTime.now()).toUtc();

  /// Whether the session still holds a live, non-destroyed DEK.
  bool get isActive => !_dek.isDestroyed;

  /// Returns the active DEK or throws [VaultLockedException] if locked.
  ManagedSecretKey get activeKey {
    if (_dek.isDestroyed) {
      throw const VaultLockedException();
    }
    return _dek;
  }

  /// Canonical AAD context string binding a wrapped DEK to [vaultId].
  static String dekWrapAad(String vaultId) => 'lockleaf:dek:v1:$vaultId';

  /// Canonical AAD context string binding an encrypted blob to an entry ID.
  String entryAad(String entryId) => 'lockleaf:entry:v1:$vaultId:$entryId';

  /// Locks the session and immediately scrubs the DEK from memory.
  void lock() {
    _dek.destroy();
  }
}
