import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';

/// Visual strength bar and feedback indicator for password creation screens.
class PasswordStrengthMeter extends StatelessWidget {
  /// Evaluation result to render.
  final PasswordStrengthResult result;

  /// Creates a [PasswordStrengthMeter] for [result].
  const PasswordStrengthMeter({
    super.key,
    required this.result,
  });

  Color _colorForLevel(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.weak:
        return AppTheme.danger;
      case PasswordStrengthLevel.fair:
        return AppTheme.warning;
      case PasswordStrengthLevel.good:
        return AppTheme.accentGreen;
      case PasswordStrengthLevel.strong:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor =
        result.score == 0 ? Colors.grey : _colorForLevel(result.level);
    final progressValue = result.score == 0 ? 0.0 : result.level.progress;
    final labelText = result.score == 0 ? 'Empty' : result.level.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 8,
            backgroundColor: Theme.of(context).colorScheme.surface,
            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Strength: $labelText',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              '~${result.estimatedEntropyBits} bits',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        if (result.feedback.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            result.feedback.join(' • '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ],
    );
  }
}
