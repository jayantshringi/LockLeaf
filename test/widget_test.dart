import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/app.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import 'features/vault/in_memory_vault_storage.dart';

void main() {
  testWidgets('LockLeafApp launches onboarding when no vault exists',
      (WidgetTester tester) async {
    final controller = VaultController(
      vaultService: VaultService(storage: InMemoryVaultStorage()),
      kdfParams: KdfParams(
        memoryKiB: 256,
        iterations: 1,
        parallelism: 1,
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(LockLeafApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('LockLeaf'), findsOneWidget);
    expect(find.text('Zero-Knowledge Vault'), findsOneWidget);
  });
}
