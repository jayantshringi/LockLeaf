import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/data/vault_database_schema.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and configures the SQLite database used for encrypted vault blobs.
class VaultDatabaseOpener {
  final String? _customPath;

  /// Creates an opener, optionally targeting a custom [databasePath].
  VaultDatabaseOpener({String? databasePath}) : _customPath = databasePath;

  /// Opens the SQLite database with `PRAGMA secure_delete = ON`.
  Future<Database> open() async {
    try {
      final path = _customPath ??
          p.join(
            await getDatabasesPath(),
            VaultDatabaseSchema.databaseName,
          );

      return await openDatabase(
        path,
        version: VaultDatabaseSchema.databaseVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          // Overwrite deleted pages with zeros immediately on delete/update.
          await db.execute('PRAGMA secure_delete = ON');
        },
        onCreate: (Database db, int version) async {
          await db.execute(VaultDatabaseSchema.createMetadataTableSql);
          await db.execute(VaultDatabaseSchema.createEntriesTableSql);
          await db.execute(VaultDatabaseSchema.createEntriesUpdatedAtIndexSql);
        },
      );
    } on DatabaseException catch (error) {
      throw StorageException(
        'Failed to open local vault database.',
        error.runtimeType.toString(),
      );
    }
  }
}
