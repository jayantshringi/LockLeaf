import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Immutable configuration for generating cryptographically random passwords.
class PasswordGeneratorOptions extends Equatable {
  /// Minimum allowed generated password length.
  static const int minLength = 8;

  /// Maximum allowed generated password length.
  static const int maxLength = 128;

  /// Recommended default length for strong random passwords.
  static const int defaultLength = 20;

  /// Target character count.
  final int length;

  /// Whether lowercase ASCII letters (`a-z`) are included.
  final bool includeLowercase;

  /// Whether uppercase ASCII letters (`A-Z`) are included.
  final bool includeUppercase;

  /// Whether ASCII digits (`0-9`) are included.
  final bool includeDigits;

  /// Whether special symbol characters are included.
  final bool includeSymbols;

  /// Whether visually ambiguous characters (`0, O, o, 1, l, I, |`) are excluded.
  final bool excludeAmbiguous;

  const PasswordGeneratorOptions._({
    required this.length,
    required this.includeLowercase,
    required this.includeUppercase,
    required this.includeDigits,
    required this.includeSymbols,
    required this.excludeAmbiguous,
  });

  /// Creates validated [PasswordGeneratorOptions].
  factory PasswordGeneratorOptions({
    int length = defaultLength,
    bool includeLowercase = true,
    bool includeUppercase = true,
    bool includeDigits = true,
    bool includeSymbols = true,
    bool excludeAmbiguous = false,
  }) {
    if (length < minLength || length > maxLength) {
      throw const ValidationException(
        'Password length must be between $minLength and $maxLength characters.',
      );
    }
    if (!includeLowercase &&
        !includeUppercase &&
        !includeDigits &&
        !includeSymbols) {
      throw const ValidationException(
        'Select at least one character set for password generation.',
      );
    }
    return PasswordGeneratorOptions._(
      length: length,
      includeLowercase: includeLowercase,
      includeUppercase: includeUppercase,
      includeDigits: includeDigits,
      includeSymbols: includeSymbols,
      excludeAmbiguous: excludeAmbiguous,
    );
  }

  /// Default high-entropy 20-character mixed password options.
  const PasswordGeneratorOptions.standard()
      : length = defaultLength,
        includeLowercase = true,
        includeUppercase = true,
        includeDigits = true,
        includeSymbols = true,
        excludeAmbiguous = false;

  /// Returns an updated, validated copy.
  PasswordGeneratorOptions copyWith({
    int? length,
    bool? includeLowercase,
    bool? includeUppercase,
    bool? includeDigits,
    bool? includeSymbols,
    bool? excludeAmbiguous,
  }) {
    return PasswordGeneratorOptions(
      length: length ?? this.length,
      includeLowercase: includeLowercase ?? this.includeLowercase,
      includeUppercase: includeUppercase ?? this.includeUppercase,
      includeDigits: includeDigits ?? this.includeDigits,
      includeSymbols: includeSymbols ?? this.includeSymbols,
      excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
    );
  }

  @override
  List<Object?> get props => [
        length,
        includeLowercase,
        includeUppercase,
        includeDigits,
        includeSymbols,
        excludeAmbiguous,
      ];
}
