import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

/// List tile displaying non-secret summary details for a [VaultEntry].
class VaultEntryTile extends StatelessWidget {
  /// Decrypted entry to summarize.
  final VaultEntry entry;

  /// Callback invoked when the user taps the tile.
  final VoidCallback onTap;

  /// Creates a [VaultEntryTile].
  const VaultEntryTile({super.key, required this.entry, required this.onTap});

  /// Returns an icon appropriate for [category].
  static IconData iconForCategory(VaultEntryCategory category) {
    switch (category) {
      case VaultEntryCategory.login:
        return Icons.key_outlined;
      case VaultEntryCategory.card:
        return Icons.credit_card_outlined;
      case VaultEntryCategory.secureNote:
        return Icons.note_alt_outlined;
      case VaultEntryCategory.identity:
        return Icons.badge_outlined;
      case VaultEntryCategory.other:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = entry.username.trim().isNotEmpty
        ? entry.username
        : entry.category.label;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
          child: Icon(
            iconForCategory(entry.category),
            color: AppTheme.primaryGreen,
          ),
        ),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.star_rounded,
                  color: AppTheme.warning,
                  size: 20,
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
