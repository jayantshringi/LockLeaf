import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/diceware_wordlist.dart';
import 'package:lockleaf/features/tools/domain/passphrase_generator.dart';

void main() {
  late PassphraseGenerator generator;

  setUp(() {
    generator = PassphraseGenerator();
  });

  group('DicewareWordlist', () {
    test('contains 256 unique lowercase alphabetical words', () {
      expect(DicewareWordlist.words.length, equals(256));
      expect(DicewareWordlist.words.toSet().length, equals(256));
      expect(
        DicewareWordlist.words.every(
          (String word) => RegExp(r'^[a-z]+$').hasMatch(word),
        ),
        isTrue,
      );
    });
  });

  group('PassphraseGenerator', () {
    test('generates expected word count with custom separator', () {
      final standard = generator.generate();
      expect(standard.split('-').length, equals(6));

      final custom = generator.generate(
        PassphraseGeneratorOptions(
          wordCount: 8,
          separator: '_',
        ),
      );
      expect(custom.split('_').length, equals(8));
    });

    test('capitalizes words and appends two-digit number when configured', () {
      final phrase = generator.generate(
        PassphraseGeneratorOptions(
          wordCount: 5,
          separator: '.',
          capitalizeWords: true,
          appendNumber: true,
        ),
      );

      final parts = phrase.split('.');
      expect(parts.length, equals(5));
      for (final word in parts) {
        expect(RegExp('^[A-Z]').hasMatch(word), isTrue);
      }
      expect(RegExp(r'\d{2}').hasMatch(phrase), isTrue);
    });

    test('estimates entropy accurately for 256-word list', () {
      const standard = PassphraseGeneratorOptions.standard();
      expect(generator.estimateEntropyBits(standard), closeTo(48.0, 0.01));

      final withNumber = standard.copyWith(appendNumber: true);
      expect(generator.estimateEntropyBits(withNumber), greaterThan(54.0));
    });

    test('validates options and custom wordlists', () {
      expect(
        () => PassphraseGeneratorOptions(wordCount: 3),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PassphraseGeneratorOptions(wordCount: 21),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PassphraseGeneratorOptions(separator: '----'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PassphraseGenerator(wordList: const <String>['only', 'two']),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
