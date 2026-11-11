import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/app.dart';

void main() {
  testWidgets('LockLeafApp smoke test verifies brand title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LockLeafApp());

    expect(find.text('LockLeaf'), findsOneWidget);
    expect(find.text('LockLeaf Vault'), findsOneWidget);
  });
}
