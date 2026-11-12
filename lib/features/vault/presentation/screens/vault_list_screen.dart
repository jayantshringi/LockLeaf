import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/presentation/screens/security_settings_screen.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/tools/presentation/screens/tools_hub_screen.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/presentation/screens/add_edit_entry_screen.dart';
import 'package:lockleaf/features/vault/presentation/screens/entry_detail_screen.dart';
import 'package:lockleaf/features/vault/presentation/widgets/vault_entry_tile.dart';

/// Main unlocked vault view featuring real-time search, filters, and lock control.
class VaultListScreen extends StatefulWidget {
  /// Controller managing unlocked vault entries and theme.
  final VaultController controller;

  /// Optional controller managing device security policies.
  final SecurityController? securityController;

  /// Creates a [VaultListScreen].
  const VaultListScreen({
    super.key,
    required this.controller,
    this.securityController,
  });

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateEntry() async {
    await Navigator.of(context).push<VaultEntry>(
      MaterialPageRoute<VaultEntry>(
        builder: (BuildContext context) => AddEditEntryScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _openEntryDetail(VaultEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EntryDetailScreen(
          controller: widget.controller,
          entry: entry,
          securityController: widget.securityController,
        ),
      ),
    );
  }

  Future<void> _openSecuritySettings() async {
    final security = widget.securityController;
    if (security == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SecuritySettingsScreen(
          securityController: security,
        ),
      ),
    );
  }

  Future<void> _openTools() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ToolsHubScreen(
          controller: widget.controller,
          securityController: widget.securityController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final totalCount = widget.controller.entries.length;
        final visibleEntries = widget.controller.filteredEntries;
        final selectedCategory = widget.controller.selectedCategory;
        final favoritesOnly = widget.controller.favoritesOnly;

        return Scaffold(
          appBar: AppBar(
            title: const Text('LockLeaf Vault'),
            actions: [
              IconButton(
                key: const Key('vault_tools_button'),
                tooltip: 'Security tools',
                icon: const Icon(Icons.handyman_outlined),
                onPressed: _openTools,
              ),
              if (widget.securityController != null)
                IconButton(
                  key: const Key('vault_security_settings_button'),
                  tooltip: 'Device security',
                  icon: const Icon(Icons.security_outlined),
                  onPressed: _openSecuritySettings,
                ),
              IconButton(
                key: const Key('vault_theme_toggle'),
                tooltip: 'Toggle theme',
                icon: Icon(
                  widget.controller.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: widget.controller.toggleDarkMode,
              ),
              IconButton(
                key: const Key('vault_lock_button'),
                tooltip: 'Lock vault',
                icon: const Icon(Icons.lock_outline),
                onPressed: widget.controller.lock,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            key: const Key('vault_add_entry_fab'),
            tooltip: 'Add entry',
            onPressed: _openCreateEntry,
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    key: const Key('vault_search_field'),
                    controller: _searchController,
                    onChanged: widget.controller.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search title, username, or URL',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: widget.controller.searchQuery.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('vault_search_clear'),
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                widget.controller.setSearchQuery('');
                              },
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          key: const Key('filter_favorites_chip'),
                          label: const Text('Favorites'),
                          selected: favoritesOnly,
                          onSelected: (_) =>
                              widget.controller.toggleFavoritesOnly(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: const Key('filter_all_chip'),
                          label: const Text('All'),
                          selected: selectedCategory == null,
                          onSelected: (_) =>
                              widget.controller.setCategoryFilter(null),
                        ),
                      ),
                      ...VaultEntryCategory.values.map(
                        (VaultEntryCategory category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('filter_category_${category.id}'),
                            label: Text(category.label),
                            selected: selectedCategory == category,
                            onSelected: (_) =>
                                widget.controller.setCategoryFilter(category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visibleEntries.isEmpty
                      ? _VaultEmptyState(hasAnyEntries: totalCount > 0)
                      : ListView.builder(
                          itemCount: visibleEntries.length,
                          itemBuilder: (BuildContext context, int index) {
                            final entry = visibleEntries[index];
                            return VaultEntryTile(
                              key: ValueKey<String>(entry.id),
                              entry: entry,
                              onTap: () => _openEntryDetail(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VaultEmptyState extends StatelessWidget {
  final bool hasAnyEntries;

  const _VaultEmptyState({required this.hasAnyEntries});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasAnyEntries ? Icons.search_off_outlined : Icons.shield_outlined,
              size: 64,
              color: AppTheme.primaryGreen.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyEntries ? 'No matching entries' : 'Your vault is empty',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyEntries
                  ? 'Try adjusting your search query or category filter.'
                  : 'Tap + to encrypt and store your first credential locally.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
