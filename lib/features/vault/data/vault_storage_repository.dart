import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';

/// Storage abstraction for persisting vault metadata and encrypted entries.
///
/// Implementations must store exclusively encrypted ciphertext blobs for entries
/// and never receive plaintext passwords or decrypted keys.
abstract class VaultStorageRepository {
  /// Returns true if vault metadata has already been initialized on this device.
  Future<bool> hasVault();

  /// Loads the persisted [VaultMetadata], or null if no vault exists.
  Future<VaultMetadata?> getMetadata();

  /// Saves or updates [metadata] atomically.
  Future<void> saveMetadata(VaultMetadata metadata);

  /// Fetches all persisted [EncryptedEntryRecord] blobs.
  Future<List<EncryptedEntryRecord>> getAllEntries();

  /// Fetches a single [EncryptedEntryRecord] by [id], or null if missing.
  Future<EncryptedEntryRecord?> getEntryById(String id);

  /// Inserts or replaces an [EncryptedEntryRecord].
  Future<void> upsertEntry(EncryptedEntryRecord record);

  /// Deletes the entry with [id], returning true if a record was removed.
  Future<bool> deleteEntry(String id);

  /// Permanently wipes all vault metadata and encrypted entries.
  Future<void> deleteAllData();

  /// Releases underlying storage resources.
  Future<void> close();
}
