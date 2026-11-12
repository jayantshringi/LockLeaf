import 'package:flutter/material.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

/// Top-level authentication flow states driving app navigation.
enum AuthFlowStage {
  /// Checking local storage for an existing encrypted vault.
  loading,

  /// First-run experience when no vault exists on device.
  onboarding,

  /// Vault exists on disk and requires master password unlock.
  locked,

  /// Active unlocked vault session with decrypted entries in memory.
  unlocked,
}

/// Reactive application controller managing auth state, theme, and vault state.
class VaultController extends ChangeNotifier {
  final VaultService _vaultService;
  final KdfParams _kdfParams;

  AuthFlowStage _stage = AuthFlowStage.loading;
  ThemeMode _themeMode;
  bool _isBusy = false;
  String? _errorMessage;

  List<VaultEntry> _entries = <VaultEntry>[];
  String _searchQuery = '';
  VaultEntryCategory? _selectedCategory;
  bool _favoritesOnly = false;

  /// Creates a [VaultController] backed by [vaultService].
  VaultController({
    required VaultService vaultService,
    KdfParams kdfParams = const KdfParams.standard(),
    ThemeMode initialThemeMode = ThemeMode.dark,
  })  : _vaultService = vaultService,
        _kdfParams = kdfParams,
        _themeMode = initialThemeMode;

  /// Current authentication stage.
  AuthFlowStage get stage => _stage;

  /// Active app theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Convenience getter indicating whether dark theme is active.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Whether an asynchronous KDF or storage operation is in progress.
  bool get isBusy => _isBusy;

  /// User-safe error message from the last failed operation, if any.
  String? get errorMessage => _errorMessage;

  /// Unmodifiable snapshot of decrypted entries while unlocked.
  List<VaultEntry> get entries => List<VaultEntry>.unmodifiable(_entries);

  /// Current search filter query.
  String get searchQuery => _searchQuery;

  /// Active category filter, or null when showing all categories.
  VaultEntryCategory? get selectedCategory => _selectedCategory;

  /// Whether the vault list shows favorite entries only.
  bool get favoritesOnly => _favoritesOnly;

  /// Filtered list matching category, favorites, and search query.
  ///
  /// Intentionally matches `title`, `username`, and `url` only, never `password`.
  List<VaultEntry> get filteredEntries {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    return List<VaultEntry>.unmodifiable(
      _entries.where((VaultEntry entry) {
        if (_selectedCategory != null && entry.category != _selectedCategory) {
          return false;
        }
        if (_favoritesOnly && !entry.isFavorite) {
          return false;
        }
        if (normalizedQuery.isEmpty) {
          return true;
        }
        final matchesTitle =
            entry.title.toLowerCase().contains(normalizedQuery);
        final matchesUser =
            entry.username.toLowerCase().contains(normalizedQuery);
        final matchesUrl =
            entry.url?.toLowerCase().contains(normalizedQuery) ?? false;
        return matchesTitle || matchesUser || matchesUrl;
      }),
    );
  }

  /// Inspects local storage to determine onboarding vs lock screen launch.
  Future<void> initialize() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final initialized = await _vaultService.isVaultInitialized();
      if (!initialized) {
        _stage = AuthFlowStage.onboarding;
      } else if (_vaultService.isUnlocked) {
        _entries = await _vaultService.getAllEntries();
        _stage = AuthFlowStage.unlocked;
      } else {
        _stage = AuthFlowStage.locked;
      }
    } on AppException catch (error) {
      _errorMessage = error.message;
      _stage = AuthFlowStage.locked;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Creates a new zero-knowledge vault protected by [masterPassword].
  Future<bool> createMasterPassword(String masterPassword) async {
    return _runBusyAction(() async {
      await _vaultService.createVault(
        masterPassword: masterPassword,
        kdfParams: _kdfParams,
      );
      _entries = <VaultEntry>[];
      _stage = AuthFlowStage.unlocked;
    });
  }

  /// Attempts to unlock the existing vault with [masterPassword].
  Future<bool> unlock(String masterPassword) async {
    return _runBusyAction(() async {
      await _vaultService.unlockVault(masterPassword);
      _entries = await _vaultService.getAllEntries();
      _stage = AuthFlowStage.unlocked;
    });
  }

  /// Immediately locks the vault, clears in-memory entries, and zeroes keys.
  void lock() {
    _vaultService.lockVault();
    _clearInMemoryEntries();
    _errorMessage = null;
    _stage = AuthFlowStage.locked;
    notifyListeners();
  }

  /// Reloads decrypted entries from encrypted storage.
  Future<void> refreshEntries() async {
    await _runBusyAction(() async {
      _entries = await _vaultService.getAllEntries();
    });
  }

  /// Encrypts and persists a new vault entry, returning it on success.
  Future<VaultEntry?> addEntry({
    required String title,
    required String username,
    required String password,
    String? url,
    String? notes,
    VaultEntryCategory category = VaultEntryCategory.login,
    bool isFavorite = false,
  }) async {
    VaultEntry? created;
    final ok = await _runBusyAction(() async {
      created = await _vaultService.createEntry(
        title: title,
        username: username,
        password: password,
        url: url,
        notes: notes,
        category: category,
        isFavorite: isFavorite,
      );
      _entries = await _vaultService.getAllEntries();
    });
    return ok ? created : null;
  }

  /// Encrypts and updates an existing [entry], returning the updated version.
  Future<VaultEntry?> editEntry(VaultEntry entry) async {
    VaultEntry? updated;
    final ok = await _runBusyAction(() async {
      updated = await _vaultService.updateEntry(entry);
      _entries = await _vaultService.getAllEntries();
    });
    return ok ? updated : null;
  }

  /// Deletes the entry with [id] and refreshes the list.
  Future<bool> deleteEntry(String id) async {
    var deleted = false;
    final ok = await _runBusyAction(() async {
      deleted = await _vaultService.deleteEntry(id);
      _entries = await _vaultService.getAllEntries();
    });
    return ok && deleted;
  }

  /// Updates the real-time search query.
  void setSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets or clears the category filter.
  void setCategoryFilter(VaultEntryCategory? category) {
    if (_selectedCategory == category) {
      return;
    }
    _selectedCategory = category;
    notifyListeners();
  }

  /// Toggles filtering by favorite entries only.
  void toggleFavoritesOnly() {
    _favoritesOnly = !_favoritesOnly;
    notifyListeners();
  }

  void _clearInMemoryEntries() {
    _entries = <VaultEntry>[];
    _searchQuery = '';
    _selectedCategory = null;
    _favoritesOnly = false;
  }

  /// Toggles between dark and light theme modes.
  void toggleDarkMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  /// Explicitly updates [themeMode].
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  /// Clears any displayed error banner.
  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runBusyAction(Future<void> Function() action) async {
    if (_isBusy) {
      return false;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on AppException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _clearInMemoryEntries();
    _vaultService.lockVault();
    super.dispose();
  }
}
