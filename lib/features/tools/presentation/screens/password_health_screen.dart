import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/tools/domain/password_health_analyzer.dart';
import 'package:lockleaf/features/tools/domain/password_health_report.dart';
import 'package:lockleaf/features/vault/presentation/screens/entry_detail_screen.dart';
import 'package:lockleaf/features/vault/presentation/widgets/vault_entry_tile.dart';

/// Displays local, in-memory vault password health diagnostics (weak & reused).
class PasswordHealthScreen extends StatelessWidget {
  /// Controller providing unlocked vault entries.
  final VaultController controller;

  /// Optional security controller forwarded when inspecting an entry.
  final SecurityController? securityController;

  /// Analyzer instance computing health metrics locally.
  final PasswordHealthAnalyzer analyzer;

  /// Creates a [PasswordHealthScreen].
  PasswordHealthScreen({
    super.key,
    required this.controller,
    this.securityController,
    PasswordHealthAnalyzer? analyzer,
  }) : analyzer = analyzer ?? PasswordHealthAnalyzer();

  Color _scoreColor(int score) {
    if (score >= 80) {
      return AppTheme.success;
    }
    if (score >= 50) {
      return AppTheme.warning;
    }
    return AppTheme.danger;
  }

  Future<void> _openEntry(
    BuildContext context,
    EntryHealthFinding finding,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EntryDetailScreen(
          controller: controller,
          entry: finding.entry,
          securityController: securityController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final report = analyzer.analyze(controller.entries);
        final scoreColor = _scoreColor(report.overallScore);

        return Scaffold(
          appBar: AppBar(title: const Text('Password Health')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          '${report.overallScore}%',
                          key: const Key('health_overall_score'),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vault Health Score',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: report.overallScore / 100.0,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatBadge(
                              key: const Key('health_weak_count'),
                              label: 'Weak',
                              count: report.weakFindings.length,
                              color: AppTheme.danger,
                            ),
                            _StatBadge(
                              key: const Key('health_reused_count'),
                              label: 'Reused',
                              count: report.reusedFindings.length,
                              color: AppTheme.warning,
                            ),
                            _StatBadge(
                              key: const Key('health_healthy_count'),
                              label: 'Healthy',
                              count: report.healthyCount,
                              color: AppTheme.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (report.totalEntries == 0)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Add entries to your vault to run a local password health audit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else if (!report.hasIssues)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.success,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All audited entries use strong, unique passwords.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (report.weakFindings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Text(
                      'Weak Passwords',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...report.weakFindings.map(
                    (EntryHealthFinding finding) => _FindingCard(
                      finding: finding,
                      badgeText:
                          'Weak (${finding.strength.estimatedEntropyBits} bits)',
                      badgeColor: AppTheme.danger,
                      onTap: () => _openEntry(context, finding),
                    ),
                  ),
                ],
                if (report.reusedFindings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Text(
                      'Reused Passwords',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...report.reusedFindings.map(
                    (EntryHealthFinding finding) => _FindingCard(
                      finding: finding,
                      badgeText: 'Used ${finding.reuseCount}x',
                      badgeColor: AppTheme.warning,
                      onTap: () => _openEntry(context, finding),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}

class _FindingCard extends StatelessWidget {
  final EntryHealthFinding finding;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;

  const _FindingCard({
    required this.finding,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry = finding.entry;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: badgeColor.withOpacity(0.14),
          child: Icon(
            VaultEntryTile.iconForCategory(entry.category),
            color: badgeColor,
          ),
        ),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          entry.username.isEmpty ? entry.category.label : entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
