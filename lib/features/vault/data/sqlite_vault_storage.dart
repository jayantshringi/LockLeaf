import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/data/vault_database_opener.dart';
import 'package:lockleaf/features/vault/data/vault_database_schema.dart';
import 'package:lockleaf/features/vault/data/vault_storage_repository.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [VaultStorageRepository].
///
/// Stores exclusively encrypted entry blobs and public KDF metadata.
class SqliteVaultStorage implements VaultStorageRepository {
  final VaultDatabaseOpener _opener;
  Database? _database;

  /// Creates a [SqliteVaultStorage] instance.
  SqliteVaultStorage({VaultDatabaseOpener? opener})
    : _opener = opener ?? VaultDatabaseOpener();

  Future<Database> _getDb() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final opened = await _opener.open();
    _database = opened;
    return opened;
  }

  Future<T> _runDb<T>(Future<T> Function(Database db) action) async {
    try {
      final db = await _getDb();
      return await action(db);
    } on AppException {
      rethrow;
    } on DatabaseException catch (error) {
      throw StorageException(
        'Vault database operation failed.',
        error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<bool> hasVault() {
    return _runDb((Database db) async {
      final rows = await db.query(
        VaultDatabaseSchema.metadataTable,
        columns: const <String>['vault_id'],
        limit: 1,
      );
      return rows.isNotEmpty;
    });
  }

  @override
  Future<VaultMetadata?> getMetadata() {
    return _runDb((Database db) async {
      final rows = await db.query(VaultDatabaseSchema.metadataTable, limit: 1);
      if (rows.isEmpty) {
        return null;
      }
      return VaultMetadata.fromMap(rows.first);
    });
  }

  @override
  Future<void> saveMetadata(VaultMetadata metadata) {
    return _runDb((Database db) async {
      await db.transaction((Transaction txn) async {
        await txn.delete(VaultDatabaseSchema.metadataTable);
        await txn.insert(
          VaultDatabaseSchema.metadataTable,
          metadata.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    });
  }

  @override
  Future<List<EncryptedEntryRecord>> getAllEntries() {
    return _runDb((Database db) async {
      final rows = await db.query(
        VaultDatabaseSchema.entriesTable,
        orderBy: 'updated_at DESC',
      );
      return rows.map(EncryptedEntryRecord.fromMap).toList();
    });
  }

  @override
  Future<EncryptedEntryRecord?> getEntryById(String id) {
    return _runDb((Database db) async {
      final rows = await db.query(
        VaultDatabaseSchema.entriesTable,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return EncryptedEntryRecord.fromMap(rows.first);
    });
  }

  @override
  Future<void> upsertEntry(EncryptedEntryRecord record) {
    return _runDb((Database db) async {
      await db.insert(
        VaultDatabaseSchema.entriesTable,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<bool> deleteEntry(String id) {
    return _runDb((Database db) async {
      final deletedCount = await db.delete(
        VaultDatabaseSchema.entriesTable,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return deletedCount > 0;
    });
  }

  @override
  Future<void> deleteAllData() {
    return _runDb((Database db) async {
      await db.transaction((Transaction txn) async {
        await txn.delete(VaultDatabaseSchema.entriesTable);
        await txn.delete(VaultDatabaseSchema.metadataTable);
      });
    });
  }

  @override
  Future<void> close() async {
    final existing = _database;
    _database = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
  }
}
