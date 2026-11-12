import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/tools/domain/password_generator.dart';
import 'package:lockleaf/features/tools/domain/password_generator_options.dart';
import 'package:lockleaf/features/tools/domain/password_health_analyzer.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';

void main() {
  late PasswordHealthAnalyzer analyzer;
  late PasswordGenerator generator;
  late SecureRandomService randomService;

  VaultEntry makeEntry({
    required String id,
    required String title,
    required String password,
  }) {
    final now = DateTime.now().toUtc();
    return VaultEntry(
      id: id,
      title: title,
      username: 'user_$id',
      password: password,
      createdAt: now,
      updatedAt: now,
    );
  }

  String generateWeakToken() {
    final codes = List<int>.generate(6, (_) => 97 + randomService.nextInt(26));
    return String.fromCharCodes(codes);
  }

  setUp(() {
    analyzer = PasswordHealthAnalyzer();
    randomService = SecureRandomService();
    generator = PasswordGenerator(randomService: randomService);
  });

  group('PasswordHealthAnalyzer', () {
    test('returns clean empty report when vault has no entries', () {
      final report = analyzer.analyze(const <VaultEntry>[]);

      expect(report.totalEntries, equals(0));
      expect(report.overallScore, equals(100));
      expect(report.hasIssues, isFalse);
    });

    test('scores unique strong generated passwords at 100%', () {
      final strongA = generator.generate(PasswordGeneratorOptions(length: 20));
      final strongB = generator.generate(PasswordGeneratorOptions(length: 20));

      final report = analyzer.analyze(<VaultEntry>[
        makeEntry(id: '1', title: 'Service A', password: strongA),
        makeEntry(id: '2', title: 'Service B', password: strongB),
      ]);

      expect(report.overallScore, equals(100));
      expect(report.healthyCount, equals(2));
      expect(report.weakFindings, isEmpty);
      expect(report.reusedFindings, isEmpty);
      expect(report.hasIssues, isFalse);
    });

    test('detects weak and reused passwords and redacts toString', () {
      final sharedStrong =
          generator.generate(PasswordGeneratorOptions(length: 20));
      final weakUnique = generateWeakToken();
      final weakShared = generateWeakToken();

      final report = analyzer.analyze(<VaultEntry>[
        makeEntry(id: '1', title: 'Shared Strong 1', password: sharedStrong),
        makeEntry(id: '2', title: 'Shared Strong 2', password: sharedStrong),
        makeEntry(id: '3', title: 'Weak Unique', password: weakUnique),
        makeEntry(id: '4', title: 'Weak Shared 1', password: weakShared),
        makeEntry(id: '5', title: 'Weak Shared 2', password: weakShared),
      ]);

      expect(report.totalEntries, equals(5));
      expect(report.healthyCount, equals(0));
      expect(report.weakFindings.length, equals(3));
      expect(report.reusedFindings.length, equals(4));
      expect(report.reusedGroupCount, equals(2));
      expect(report.hasIssues, isTrue);
      expect(report.overallScore, lessThan(50));

      final reportText = report.toString();
      expect(reportText, isNot(contains(sharedStrong)));
      expect(reportText, isNot(contains(weakUnique)));
      expect(reportText, isNot(contains(weakShared)));

      for (final finding in report.weakFindings) {
        expect(finding.toString(), isNot(contains(finding.entry.password)));
      }
    });
  });
}
