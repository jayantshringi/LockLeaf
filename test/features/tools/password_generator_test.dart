import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/password_generator.dart';
import 'package:lockleaf/features/tools/domain/password_generator_options.dart';

void main() {
  late PasswordGenerator generator;

  setUp(() {
    generator = PasswordGenerator();
  });

  group('PasswordGenerator', () {
    test('generates password of exact default and custom lengths', () {
      final standard = generator.generate();
      expect(
        standard.length,
        equals(PasswordGeneratorOptions.defaultLength),
      );

      final custom = generator.generate(
        PasswordGeneratorOptions(length: 48),
      );
      expect(custom.length, equals(48));
    });

    test('includes at least one character from every enabled class', () {
      for (var i = 0; i < 20; i++) {
        final generated = generator.generate(
          PasswordGeneratorOptions(length: 12),
        );
        expect(RegExp('[a-z]').hasMatch(generated), isTrue);
        expect(RegExp('[A-Z]').hasMatch(generated), isTrue);
        expect(RegExp('[0-9]').hasMatch(generated), isTrue);
        expect(RegExp('[^a-zA-Z0-9]').hasMatch(generated), isTrue);
      }
    });

    test('respects disabled character classes', () {
      final digitsOnly = generator.generate(
        PasswordGeneratorOptions(
          length: 16,
          includeLowercase: false,
          includeUppercase: false,
          includeDigits: true,
          includeSymbols: false,
        ),
      );

      expect(digitsOnly.length, equals(16));
      expect(RegExp(r'^[0-9]+$').hasMatch(digitsOnly), isTrue);
    });

    test('excludes ambiguous characters when configured', () {
      final ambiguous = RegExp('[0Oo1lI|]');
      final options = PasswordGeneratorOptions(
        length: 32,
        excludeAmbiguous: true,
      );

      for (var i = 0; i < 30; i++) {
        final generated = generator.generate(options);
        expect(ambiguous.hasMatch(generated), isFalse);
      }
    });

    test('produces unique passwords across consecutive runs', () {
      final seen = <String>{};
      for (var i = 0; i < 25; i++) {
        seen.add(generator.generate());
      }
      expect(seen.length, equals(25));
    });

    test('validates bounds and character set selection', () {
      expect(
        () => PasswordGeneratorOptions(length: 7),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PasswordGeneratorOptions(length: 129),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => PasswordGeneratorOptions(
          includeLowercase: false,
          includeUppercase: false,
          includeDigits: false,
          includeSymbols: false,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
