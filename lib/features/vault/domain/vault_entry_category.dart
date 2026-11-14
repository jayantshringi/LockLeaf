/// Categories for organizing entries inside a LockLeaf vault.
enum VaultEntryCategory {
  /// Website or application login credentials.
  login(id: 'login', label: 'Login'),

  /// Payment or banking card credentials.
  card(id: 'card', label: 'Card'),

  /// Arbitrary sensitive text notes.
  secureNote(id: 'secure_note', label: 'Secure Note'),

  /// Personal identity or passport details.
  identity(id: 'identity', label: 'Identity'),

  /// Uncategorized or custom entry type.
  other(id: 'other', label: 'Other');

  /// Stable serialized identifier stored inside encrypted entry blobs.
  final String id;

  /// Human-readable category label for UI display.
  final String label;

  const VaultEntryCategory({required this.id, required this.label});

  /// Resolves a [VaultEntryCategory] from its serialized [id].
  static VaultEntryCategory fromId(String id) {
    for (final category in VaultEntryCategory.values) {
      if (category.id == id) {
        return category;
      }
    }
    return VaultEntryCategory.other;
  }
}
