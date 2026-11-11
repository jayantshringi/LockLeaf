import 'package:lockleaf/features/vault/data/vault_storage_repository.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';

/// In-memory [VaultStorageRepository] test double simulating SQLite map storage.
class InMemoryVaultStorage implements VaultStorageRepository {
  Map<String, Object?>? _metadataRow;
  final Map<String, Map<String, Object?>> _entryRows =
      <String, Map<String, Object?>>{};

  /// Raw stored metadata row for zero-knowledge verification in tests.
  Map<String, Object?>? get rawMetadataRow =>
      _metadataRow == null ? null : Map<String, Object?>.from(_metadataRow!);

  /// Raw stored entry rows for zero-knowledge verification in tests.
  Map<String, Map<String, Object?>> get rawEntryRows =>
      Map<String, Map<String, Object?>>.unmodifiable(_entryRows);

  @override
  Future<bool> hasVault() async => _metadataRow != null;

  @override
  Future<VaultMetadata?> getMetadata() async {
    final row = _metadataRow;
    if (row == null) {
      return null;
    }
    return VaultMetadata.fromMap(row);
  }

  @override
  Future<void> saveMetadata(VaultMetadata metadata) async {
    _metadataRow = metadata.toMap();
  }

  @override
  Future<List<EncryptedEntryRecord>> getAllEntries() async {
    final records = _entryRows.values
        .map(EncryptedEntryRecord.fromMap)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  @override
  Future<EncryptedEntryRecord?> getEntryById(String id) async {
    final row = _entryRows[id];
    if (row == null) {
      return null;
    }
    return EncryptedEntryRecord.fromMap(row);
  }

  @override
  Future<void> upsertEntry(EncryptedEntryRecord record) async {
    _entryRows[record.id] = record.toMap();
  }

  @override
  Future<bool> deleteEntry(String id) async {
    return _entryRows.remove(id) != null;
  }

  @override
  Future<void> deleteAllData() async {
    _metadataRow = null;
    _entryRows.clear();
  }

  @override
  Future<void> close() async {}
}
