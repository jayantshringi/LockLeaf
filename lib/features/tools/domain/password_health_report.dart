import 'package:equatable/equatable.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';

/// Issue types detected by the local vault password health audit.
enum PasswordHealthIssue {
  /// Password is too short or lacks sufficient entropy.
  weak,

  /// Identical password is shared across two or more vault entries.
  reused,
}

/// Per-entry health audit finding without exposing raw passwords in logs.
class EntryHealthFinding extends Equatable {
  /// Audited vault entry.
  final VaultEntry entry;

  /// Evaluated local strength result.
  final PasswordStrengthResult strength;

  /// Non-empty when weak and/or reused issues were found.
  final Set<PasswordHealthIssue> issues;

  /// Total number of vault entries sharing this entry's password.
  final int reuseCount;

  /// Creates an [EntryHealthFinding].
  const EntryHealthFinding({
    required this.entry,
    required this.strength,
    required this.issues,
    required this.reuseCount,
  });

  /// Whether this entry has a weak password.
  bool get isWeak => issues.contains(PasswordHealthIssue.weak);

  /// Whether this entry reuses a password used by another entry.
  bool get isReused => issues.contains(PasswordHealthIssue.reused);

  /// Whether no issues were found for this entry.
  bool get isHealthy => issues.isEmpty;

  @override
  String toString() =>
      'EntryHealthFinding(entryId: ${entry.id}, issues: $issues, reuseCount: $reuseCount)';

  @override
  List<Object?> get props => [entry, strength, issues, reuseCount];
}

/// Aggregated health report computed locally across unlocked vault entries.
class PasswordHealthReport extends Equatable {
  /// Overall vault health percentage in `[0, 100]`.
  final int overallScore;

  /// Total number of audited entries containing passwords.
  final int totalEntries;

  /// Entries flagged with weak passwords.
  final List<EntryHealthFinding> weakFindings;

  /// Entries flagged for password reuse.
  final List<EntryHealthFinding> reusedFindings;

  /// Count of entries free of weak or reused issues.
  final int healthyCount;

  /// Number of distinct duplicate password groups detected.
  final int reusedGroupCount;

  /// Creates an immutable [PasswordHealthReport].
  const PasswordHealthReport({
    required this.overallScore,
    required this.totalEntries,
    required this.weakFindings,
    required this.reusedFindings,
    required this.healthyCount,
    required this.reusedGroupCount,
  });

  /// Empty report for vaults with zero password entries.
  const PasswordHealthReport.empty()
      : overallScore = 100,
        totalEntries = 0,
        weakFindings = const <EntryHealthFinding>[],
        reusedFindings = const <EntryHealthFinding>[],
        healthyCount = 0,
        reusedGroupCount = 0;

  /// Whether any weak or reused passwords exist.
  bool get hasIssues => weakFindings.isNotEmpty || reusedFindings.isNotEmpty;

  @override
  String toString() =>
      'PasswordHealthReport(score: $overallScore, total: $totalEntries, weak: ${weakFindings.length}, reused: ${reusedFindings.length})';

  @override
  List<Object?> get props => [
        overallScore,
        totalEntries,
        weakFindings,
        reusedFindings,
        healthyCount,
        reusedGroupCount,
      ];
}
