import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/presentation/screens/add_edit_entry_screen.dart';
import 'package:lockleaf/features/vault/presentation/widgets/vault_entry_tile.dart';

/// Read-only detail view for inspecting, copying, editing, or deleting an entry.
class EntryDetailScreen extends StatefulWidget {
  /// Controller managing vault encryption and persistence.
  final VaultController controller;

  /// Initial decrypted entry to display.
  final VaultEntry entry;

  /// Optional device security controller for 30s clipboard auto-clear.
  final SecurityController? securityController;

  /// Creates an [EntryDetailScreen].
  const EntryDetailScreen({
    super.key,
    required this.controller,
    required this.entry,
    this.securityController,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late VaultEntry _entry;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _copyToClipboard(
    String label,
    String value, {
    bool isSensitive = false,
  }) async {
    final security = widget.securityController;
    final String message;
    if (isSensitive && security != null) {
      await security.copySecret(value);
      message = '$label copied — clears in '
          '${SecurityConstants.clipboardClearDelaySeconds}s';
    } else {
      await Clipboard.setData(ClipboardData(text: value));
      message = '$label copied to clipboard';
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<VaultEntry>(
      MaterialPageRoute<VaultEntry>(
        builder: (BuildContext context) => AddEditEntryScreen(
          controller: widget.controller,
          existingEntry: _entry,
        ),
      ),
    );
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _entry = updated;
    });
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Entry'),
          content: Text(
            'Permanently delete "${_entry.title}" from your encrypted vault?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_delete_button'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final deleted = await widget.controller.deleteEntry(_entry.id);
    if (!mounted) {
      return;
    }
    if (deleted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _entry.url;
    final notes = _entry.notes;

    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.title),
        actions: [
          IconButton(
            key: const Key('detail_edit_button'),
            tooltip: 'Edit entry',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEdit,
          ),
          IconButton(
            key: const Key('detail_delete_button'),
            tooltip: 'Delete entry',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmAndDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    VaultEntryTile.iconForCategory(_entry.category),
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                  label: Text(_entry.category.label),
                ),
                const SizedBox(width: 8),
                if (_entry.isFavorite)
                  const Chip(
                    avatar: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppTheme.warning,
                    ),
                    label: Text('Favorite'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailFieldCard(
              label: 'Username',
              value: _entry.username.isEmpty ? '(none)' : _entry.username,
              trailing: _entry.username.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('detail_copy_username_button'),
                      tooltip: 'Copy username',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () =>
                          _copyToClipboard('Username', _entry.username),
                    ),
            ),
            const SizedBox(height: 12),
            _DetailFieldCard(
              label: 'Password',
              value: _passwordVisible ? _entry.password : '••••••••••••',
              monospace: _passwordVisible,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('detail_reveal_password_button'),
                    tooltip:
                        _passwordVisible ? 'Hide password' : 'Reveal password',
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                  IconButton(
                    key: const Key('detail_copy_password_button'),
                    tooltip: 'Copy password',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => _copyToClipboard(
                      'Password',
                      _entry.password,
                      isSensitive: true,
                    ),
                  ),
                ],
              ),
            ),
            if (url != null) ...[
              const SizedBox(height: 12),
              _DetailFieldCard(
                label: 'Website URL',
                value: url,
                trailing: IconButton(
                  key: const Key('detail_copy_url_button'),
                  tooltip: 'Copy URL',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => _copyToClipboard('URL', url),
                ),
              ),
            ],
            if (notes != null) ...[
              const SizedBox(height: 12),
              _DetailFieldCard(
                label: 'Notes',
                value: notes,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Updated: ${_entry.updatedAt.toIso8601String()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailFieldCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final bool monospace;

  const _DetailFieldCard({
    required this.label,
    required this.value,
    this.trailing,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: monospace ? 'monospace' : null,
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
