import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/diceware_wordlist.dart';

/// Immutable configuration for generating Diceware-style passphrases.
class PassphraseGeneratorOptions extends Equatable {
  /// Minimum number of words allowed in a generated passphrase.
  static const int minWords = 4;

  /// Maximum number of words allowed in a generated passphrase.
  static const int maxWords = 20;

  /// Default recommended word count.
  static const int defaultWords = 6;

  /// Number of words to select from the wordlist.
  final int wordCount;

  /// Separator placed between selected words.
  final String separator;

  /// Whether to capitalize the first character of each word.
  final bool capitalizeWords;

  /// Whether to append a random two-digit number to one random word.
  final bool appendNumber;

  const PassphraseGeneratorOptions._({
    required this.wordCount,
    required this.separator,
    required this.capitalizeWords,
    required this.appendNumber,
  });

  /// Creates validated [PassphraseGeneratorOptions].
  factory PassphraseGeneratorOptions({
    int wordCount = defaultWords,
    String separator = '-',
    bool capitalizeWords = false,
    bool appendNumber = false,
  }) {
    if (wordCount < minWords || wordCount > maxWords) {
      throw const ValidationException(
        'Passphrase word count must be between $minWords and $maxWords.',
      );
    }
    if (separator.length > 3) {
      throw const ValidationException(
        'Passphrase separator cannot exceed 3 characters.',
      );
    }
    return PassphraseGeneratorOptions._(
      wordCount: wordCount,
      separator: separator,
      capitalizeWords: capitalizeWords,
      appendNumber: appendNumber,
    );
  }

  /// Default 6-word hyphen-separated passphrase options.
  const PassphraseGeneratorOptions.standard()
    : wordCount = defaultWords,
      separator = '-',
      capitalizeWords = false,
      appendNumber = false;

  /// Returns an updated, validated copy.
  PassphraseGeneratorOptions copyWith({
    int? wordCount,
    String? separator,
    bool? capitalizeWords,
    bool? appendNumber,
  }) {
    return PassphraseGeneratorOptions(
      wordCount: wordCount ?? this.wordCount,
      separator: separator ?? this.separator,
      capitalizeWords: capitalizeWords ?? this.capitalizeWords,
      appendNumber: appendNumber ?? this.appendNumber,
    );
  }

  @override
  List<Object?> get props => [
    wordCount,
    separator,
    capitalizeWords,
    appendNumber,
  ];
}

/// Generates memorable Diceware passphrases using [SecureRandomService].
class PassphraseGenerator {
  final SecureRandomService _randomService;
  final List<String> _wordList;

  /// Creates a [PassphraseGenerator].
  PassphraseGenerator({
    SecureRandomService? randomService,
    List<String>? wordList,
  }) : _randomService = randomService ?? SecureRandomService(),
       _wordList = wordList ?? DicewareWordlist.words {
    if (_wordList.length < 64) {
      throw const ValidationException(
        'Word list must contain at least 64 words.',
      );
    }
  }

  /// Generates a passphrase matching [options].
  String generate([
    PassphraseGeneratorOptions options =
        const PassphraseGeneratorOptions.standard(),
  ]) {
    final chosen = <String>[];
    for (var i = 0; i < options.wordCount; i++) {
      var word = _wordList[_randomService.nextInt(_wordList.length)];
      if (options.capitalizeWords && word.isNotEmpty) {
        word = '${word[0].toUpperCase()}${word.substring(1)}';
      }
      chosen.add(word);
    }

    if (options.appendNumber) {
      final targetIndex = _randomService.nextInt(chosen.length);
      final number = 10 + _randomService.nextInt(90);
      chosen[targetIndex] = '${chosen[targetIndex]}$number';
    }

    return chosen.join(options.separator);
  }

  /// Estimates theoretical Shannon entropy in bits for [options].
  double estimateEntropyBits(PassphraseGeneratorOptions options) {
    final bitsPerWord = math.log(_wordList.length) / math.ln2;
    final numberBits = options.appendNumber ? (math.log(90) / math.ln2) : 0.0;
    return (options.wordCount * bitsPerWord) + numberBits;
  }
}
