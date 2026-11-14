import 'package:lockleaf/features/sync/domain/encrypted_sync_record.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';

/// Outcome decision for a conflicting sync record.
enum ConflictDecision {
  /// The local entry should be preserved and scheduled to overwrite the remote state.
  keepLocal,

  /// The decrypted remote entry should overwrite the local state.
  applyRemote,

  /// The local entry was deleted remotely and should be removed locally.
  deleteLocal,

  /// The remote record is outdated or irrelevant and should be ignored.
  ignoreRemote,
}

/// Result detailing the resolution decision and rationale.
class ConflictResolutionResult {
  final ConflictDecision decision;
  final String reason;

  const ConflictResolutionResult({
    required this.decision,
    required this.reason,
  });
}

/// Deterministic Last-Write-Wins (LWW) conflict resolver with timestamp,
/// version, and deviceId tie-breaking.
class SyncConflictResolver {
  final String localDeviceId;

  const SyncConflictResolver({required this.localDeviceId});

  /// Resolves the conflict between [localEntry] (or null if absent) and [remoteRecord].
  ///
  /// [decryptedRemoteEntry] is provided when [remoteRecord.isDeleted] is false.
  ConflictResolutionResult resolve({
    required VaultEntry? localEntry,
    required EncryptedSyncRecord remoteRecord,
    VaultEntry? decryptedRemoteEntry,
  }) {
    // Case 1: Entry does not exist locally
    if (localEntry == null) {
      if (remoteRecord.isDeleted) {
        return const ConflictResolutionResult(
          decision: ConflictDecision.ignoreRemote,
          reason: 'Entry already absent locally and marked deleted on remote.',
        );
      }
      return const ConflictResolutionResult(
        decision: ConflictDecision.applyRemote,
        reason: 'New entry received from remote.',
      );
    }

    // Case 2: Remote record is a deletion tombstone
    if (remoteRecord.isDeleted) {
      if (remoteRecord.updatedAt.isAfter(localEntry.updatedAt) ||
          remoteRecord.updatedAt.isAtSameMomentAs(localEntry.updatedAt)) {
        return const ConflictResolutionResult(
          decision: ConflictDecision.deleteLocal,
          reason: 'Remote deletion timestamp is newer or equal to local update.',
        );
      } else {
        return const ConflictResolutionResult(
          decision: ConflictDecision.keepLocal,
          reason: 'Local entry was modified after remote deletion.',
        );
      }
    }

    // Case 3: Remote record is an active entry modification
    if (decryptedRemoteEntry == null) {
      return const ConflictResolutionResult(
        decision: ConflictDecision.ignoreRemote,
        reason: 'Decrypted remote entry missing for non-tombstone record.',
      );
    }

    // Compare update timestamps
    if (decryptedRemoteEntry.updatedAt.isAfter(localEntry.updatedAt)) {
      return const ConflictResolutionResult(
        decision: ConflictDecision.applyRemote,
        reason: 'Remote update timestamp is newer than local.',
      );
    }

    if (localEntry.updatedAt.isAfter(decryptedRemoteEntry.updatedAt)) {
      return const ConflictResolutionResult(
        decision: ConflictDecision.keepLocal,
        reason: 'Local update timestamp is newer than remote.',
      );
    }

    // Timestamps are equal: compare sequence version
    if (remoteRecord.version > localEntry.schemaVersion) {
      return const ConflictResolutionResult(
        decision: ConflictDecision.applyRemote,
        reason: 'Remote version is higher on timestamp tie.',
      );
    }

    if (localEntry.schemaVersion > remoteRecord.version) {
      return const ConflictResolutionResult(
        decision: ConflictDecision.keepLocal,
        reason: 'Local version is higher on timestamp tie.',
      );
    }

    // Timestamp & version are identical: deterministic deviceId tie-breaking
    if (remoteRecord.deviceId.compareTo(localDeviceId) > 0) {
      return const ConflictResolutionResult(
        decision: ConflictDecision.applyRemote,
        reason: 'Remote deviceId won tie-breaker.',
      );
    } else {
      return const ConflictResolutionResult(
        decision: ConflictDecision.keepLocal,
        reason: 'Local deviceId won tie-breaker.',
      );
    }
  }
}
