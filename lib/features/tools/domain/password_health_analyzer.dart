import 'dart:math' as math;

import 'package:lockleaf/features/auth/domain/password_strength.dart';
import 'package:lockleaf/features/tools/domain/password_health_report.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';

/// Analyzes unlocked vault entries strictly in memory for weak or reused secrets.
class PasswordHealthAnalyzer {
  /// Evaluates [entries] locally and returns an aggregated [PasswordHealthReport].
  PasswordHealthReport analyze(List<VaultEntry> entries) {
    final audited = entries
        .where((VaultEntry entry) => entry.password.isNotEmpty)
        .toList();
    if (audited.isEmpty) {
      return const PasswordHealthReport.empty();
    }

    final frequencyMap = <String, int>{};
    for (final entry in audited) {
      frequencyMap[entry.password] = (frequencyMap[entry.password] ?? 0) + 1;
    }

    final weakFindings = <EntryHealthFinding>[];
    final reusedFindings = <EntryHealthFinding>[];
    var healthyCount = 0;
    var scoreAccumulator = 0;

    for (final entry in audited) {
      final strength = PasswordStrengthEvaluator.evaluate(entry.password);
      final reuseCount = frequencyMap[entry.password] ?? 1;
      final isWeak = strength.level == PasswordStrengthLevel.weak;
      final isReused = reuseCount >= 2;

      final issues = <PasswordHealthIssue>{};
      if (isWeak) {
        issues.add(PasswordHealthIssue.weak);
      }
      if (isReused) {
        issues.add(PasswordHealthIssue.reused);
      }

      final finding = EntryHealthFinding(
        entry: entry,
        strength: strength,
        issues: Set<PasswordHealthIssue>.unmodifiable(issues),
        reuseCount: reuseCount,
      );

      if (isWeak) {
        weakFindings.add(finding);
      }
      if (isReused) {
        reusedFindings.add(finding);
      }
      if (finding.isHealthy) {
        healthyCount++;
      }

      final basePoints = strength.score * 25;
      final reusePenalty = isReused ? 30 : 0;
      scoreAccumulator += math.max(0, math.min(100, basePoints - reusePenalty));
    }

    final reusedGroupCount = frequencyMap.values
        .where((int count) => count >= 2)
        .length;
    frequencyMap.clear();

    return PasswordHealthReport(
      overallScore: (scoreAccumulator / audited.length).round(),
      totalEntries: audited.length,
      weakFindings: List<EntryHealthFinding>.unmodifiable(weakFindings),
      reusedFindings: List<EntryHealthFinding>.unmodifiable(reusedFindings),
      healthyCount: healthyCount,
      reusedGroupCount: reusedGroupCount,
    );
  }
}
