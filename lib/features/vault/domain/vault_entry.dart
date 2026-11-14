import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

/// Decrypted in-memory representation of a single vault credential or secret.
class VaultEntry extends Equatable {
  /// Stable UUID v4 identifier for this entry.
  final String id;

  /// User-visible entry title (encrypted inside the vault payload on disk).
  final String title;

  /// Account username or email address.
  final String username;

  /// Sensitive password or secret value.
  final String password;

  /// Optional associated website URL or app identifier.
  final String? url;

  /// Optional freeform notes stored encrypted with the entry.
  final String? notes;

  /// Logical entry category.
  final VaultEntryCategory category;

  /// Whether the user starred this entry for quick access.
  final bool isFavorite;

  /// UTC timestamp when the entry was first created.
  final DateTime createdAt;

  /// UTC timestamp of the most recent modification.
  final DateTime updatedAt;

  /// Schema or sequence version for sync conflict resolution.
  final int schemaVersion;

  VaultEntry._({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    required this.category,
    required this.isFavorite,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.schemaVersion = 1,
  }) : createdAt = DateTime.fromMillisecondsSinceEpoch(
         createdAt.millisecondsSinceEpoch,
         isUtc: true,
       ),
       updatedAt = DateTime.fromMillisecondsSinceEpoch(
         updatedAt.millisecondsSinceEpoch,
         isUtc: true,
       );

  /// Creates and validates a [VaultEntry].
  factory VaultEntry({
    required String id,
    required String title,
    required String username,
    required String password,
    String? url,
    String? notes,
    VaultEntryCategory category = VaultEntryCategory.login,
    bool isFavorite = false,
    required DateTime createdAt,
    required DateTime updatedAt,
    int schemaVersion = 1,
  }) {
    if (id.trim().isEmpty) {
      throw const ValidationException('Entry ID cannot be empty.');
    }
    if (title.trim().isEmpty) {
      throw const ValidationException('Entry title cannot be empty.');
    }
    return VaultEntry._(
      id: id.trim(),
      title: title.trim(),
      username: username,
      password: password,
      url: url?.trim().isEmpty == true ? null : url?.trim(),
      notes: notes?.isEmpty == true ? null : notes,
      category: category,
      isFavorite: isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  /// Returns a modified copy of this entry while keeping unprovided fields.
  VaultEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? url,
    bool clearUrl = false,
    String? notes,
    bool clearNotes = false,
    VaultEntryCategory? category,
    bool? isFavorite,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return VaultEntry(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: clearUrl ? null : (url ?? this.url),
      notes: clearNotes ? null : (notes ?? this.notes),
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  /// Serializes all entry fields into JSON for authenticated encryption.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'category': category.id,
      'isFavorite': isFavorite,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'schemaVersion': schemaVersion,
    };
  }

  /// Parses a [VaultEntry] from decrypted JSON data.
  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final username = json['username'];
    final password = json['password'];
    final url = json['url'];
    final notes = json['notes'];
    final categoryId = json['category'];
    final isFavorite = json['isFavorite'];
    final createdAtMillis = json['createdAt'];
    final updatedAtMillis = json['updatedAt'];
    final schemaVersion =
        (json['schemaVersion'] as int?) ??
        (json['schema_version'] as int?) ??
        1;

    if (id is! String ||
        title is! String ||
        username is! String ||
        password is! String ||
        url is! String? ||
        notes is! String? ||
        categoryId is! String ||
        isFavorite is! bool ||
        createdAtMillis is! int ||
        updatedAtMillis is! int) {
      throw const ValidationException('Invalid vault entry JSON structure.');
    }

    return VaultEntry(
      id: id,
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      category: VaultEntryCategory.fromId(categoryId),
      isFavorite: isFavorite,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAtMillis,
        isUtc: true,
      ),
      schemaVersion: schemaVersion,
    );
  }

  /// Redacted string representation preventing accidental credential logging.
  @override
  String toString() =>
      'VaultEntry(id: $id, category: ${category.id}, isFavorite: $isFavorite)';

  @override
  List<Object?> get props => [
    id,
    title,
    username,
    password,
    url,
    notes,
    category,
    isFavorite,
    createdAt,
    updatedAt,
    schemaVersion,
  ];
}
