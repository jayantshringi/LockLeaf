import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/constants/security_constants.dart';

/// Qualitative strength classification for passwords.
enum PasswordStrengthLevel {
  /// Under minimum length or low character diversity.
  weak(label: 'Weak', progress: 0.25),

  /// Meets basic length or diversity but needs strengthening.
  fair(label: 'Fair', progress: 0.50),

  /// Solid length and character mix suitable for standard accounts.
  good(label: 'Good', progress: 0.75),

  /// High entropy and length recommended for master passwords.
  strong(label: 'Strong', progress: 1.0);

  /// User-facing label for badges and accessibility labels.
  final String label;

  /// Normalized progress bar fraction in `[0.0, 1.0]`.
  final double progress;

  const PasswordStrengthLevel({
    required this.label,
    required this.progress,
  });
}

/// Evaluation result returned by [PasswordStrengthEvaluator].
class PasswordStrengthResult extends Equatable {
  /// Qualitative strength bucket.
  final PasswordStrengthLevel level;

  /// Numeric score from `0` (empty) to `4` (strong).
  final int score;

  /// Estimated character-pool entropy in bits.
  final int estimatedEntropyBits;

  /// Actionable suggestions for strengthening the password.
  final List<String> feedback;

  /// Creates an immutable [PasswordStrengthResult].
  const PasswordStrengthResult({
    required this.level,
    required this.score,
    required this.estimatedEntropyBits,
    required this.feedback,
  });

  @override
  List<Object?> get props => [
        level,
        score,
        estimatedEntropyBits,
        feedback,
      ];
}

/// Evaluates password strength locally using length, diversity, and entropy.
abstract class PasswordStrengthEvaluator {
  static final RegExp _lowerRegex = RegExp('[a-z]');
  static final RegExp _upperRegex = RegExp('[A-Z]');
  static final RegExp _digitRegex = RegExp('[0-9]');
  static final RegExp _symbolRegex = RegExp(r'[^a-zA-Z0-9\s]');
  static final RegExp _repeatRegex = RegExp(r'(.)\1{2,}');

  /// Evaluates [password] locally without storing or transmitting it.
  static PasswordStrengthResult evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.weak,
        score: 0,
        estimatedEntropyBits: 0,
        feedback: <String>['Enter a master password'],
      );
    }

    final hasLower = _lowerRegex.hasMatch(password);
    final hasUpper = _upperRegex.hasMatch(password);
    final hasDigit = _digitRegex.hasMatch(password);
    final hasSymbol = _symbolRegex.hasMatch(password);
    final hasRepeats = _repeatRegex.hasMatch(password);

    var poolSize = 0;
    if (hasLower) poolSize += 26;
    if (hasUpper) poolSize += 26;
    if (hasDigit) poolSize += 10;
    if (hasSymbol) poolSize += 32;
    if (poolSize == 0) poolSize = 16;

    final rawEntropy = password.length * (math.log(poolSize) / math.ln2);
    final penalty = hasRepeats ? 15 : 0;
    final entropyBits = math.max(0, rawEntropy.round() - penalty);

    final feedback = <String>[];
    if (password.length < SecurityConstants.minMasterPasswordLength) {
      feedback.add(
        'Use at least ${SecurityConstants.minMasterPasswordLength} characters',
      );
    }
    if (!hasLower || !hasUpper) {
      feedback.add('Mix uppercase and lowercase letters');
    }
    if (!hasDigit && !hasSymbol) {
      feedback.add('Add numbers or symbols');
    }
    if (hasRepeats) {
      feedback.add('Avoid repeated characters');
    }

    final int score;
    if (password.length < SecurityConstants.minMasterPasswordLength ||
        entropyBits < 45) {
      score = 1;
    } else if (entropyBits < 65) {
      score = 2;
    } else if (entropyBits < 85 || password.length < 16) {
      score = 3;
    } else {
      score = 4;
    }

    final level = switch (score) {
      1 => PasswordStrengthLevel.weak,
      2 => PasswordStrengthLevel.fair,
      3 => PasswordStrengthLevel.good,
      _ => PasswordStrengthLevel.strong,
    };

    return PasswordStrengthResult(
      level: level,
      score: score,
      estimatedEntropyBits: entropyBits,
      feedback: List<String>.unmodifiable(feedback),
    );
  }
}
