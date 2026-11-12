import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../vault/in_memory_vault_storage.dart';

void main() {
  late InMemoryVaultStorage storage;
  late SecureRandomService randomService;
  late VaultService vaultService;
  late VaultController controller;

  String randomToken({int length = 18}) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    storage = InMemoryVaultStorage();
    randomService = SecureRandomService();
    vaultService = VaultService(
      storage: storage,
      randomService: randomService,
    );
    controller = VaultController(
      vaultService: vaultService,
      kdfParams: KdfParams(
        memoryKiB: 256,
        iterations: 1,
        parallelism: 1,
      ),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('VaultController', () {
    test('initializes to onboarding when uninitialized, then locked after lock',
        () async {
      await controller.initialize();
      expect(controller.stage, equals(AuthFlowStage.onboarding));

      final masterPass = randomToken();
      final created = await controller.createMasterPassword(masterPass);
      expect(created, isTrue);
      expect(controller.stage, equals(AuthFlowStage.unlocked));

      controller.lock();
      expect(controller.stage, equals(AuthFlowStage.locked));

      final reinitialized = VaultController(
        vaultService: VaultService(storage: storage),
        kdfParams: KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1),
      );
      addTearDown(reinitialized.dispose);

      await reinitialized.initialize();
      expect(reinitialized.stage, equals(AuthFlowStage.locked));
    });

    test('sets safe error message on failed unlock and succeeds on valid pass',
        () async {
      final masterPass = randomToken();
      await controller.createMasterPassword(masterPass);
      controller.lock();

      final badAttempt = await controller.unlock(randomToken());
      expect(badAttempt, isFalse);
      expect(controller.stage, equals(AuthFlowStage.locked));
      expect(controller.errorMessage, isNotNull);

      final goodAttempt = await controller.unlock(masterPass);
      expect(goodAttempt, isTrue);
      expect(controller.stage, equals(AuthFlowStage.unlocked));
      expect(controller.errorMessage, isNull);
    });

    test('filters entries by title/username/url without matching passwords',
        () async {
      await controller.createMasterPassword(randomToken());
      final secretOne = 'uniquepasswordmarker_${randomToken(length: 8)}';

      final loginEntry = await controller.addEntry(
        title: 'Alpha Mail',
        username: 'alpha_user',
        password: secretOne,
        url: 'https://mail.example.invalid',
        category: VaultEntryCategory.login,
        isFavorite: true,
      );
      final noteEntry = await controller.addEntry(
        title: 'Recovery Memo',
        username: 'local_only',
        password: randomToken(),
        category: VaultEntryCategory.secureNote,
      );

      expect(loginEntry, isNotNull);
      expect(noteEntry, isNotNull);
      expect(controller.entries, hasLength(2));

      // Search matches title, username, and URL
      controller.setSearchQuery('alpha');
      expect(controller.filteredEntries, hasLength(1));
      expect(controller.filteredEntries.first.id, equals(loginEntry!.id));

      controller.setSearchQuery('mail.example.invalid');
      expect(controller.filteredEntries, hasLength(1));

      // Search must NOT match password field
      controller.setSearchQuery('uniquepasswordmarker');
      expect(controller.filteredEntries, isEmpty);

      // Category and favorite filtering
      controller.setSearchQuery('');
      controller.setCategoryFilter(VaultEntryCategory.secureNote);
      expect(controller.filteredEntries, hasLength(1));
      expect(controller.filteredEntries.first.id, equals(noteEntry!.id));

      controller.setCategoryFilter(null);
      controller.toggleFavoritesOnly();
      expect(controller.filteredEntries, hasLength(1));
      expect(controller.filteredEntries.first.id, equals(loginEntry.id));

      // Locking wipes in-memory entries and resets filters
      controller.lock();
      expect(controller.entries, isEmpty);
      expect(controller.searchQuery, isEmpty);
      expect(controller.selectedCategory, isNull);
      expect(controller.favoritesOnly, isFalse);
    });

    test('toggles between dark and light theme modes', () {
      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.isDarkMode, isTrue);

      controller.toggleDarkMode();
      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.isDarkMode, isFalse);

      controller.toggleDarkMode();
      expect(controller.themeMode, equals(ThemeMode.dark));
    });
  });
}
