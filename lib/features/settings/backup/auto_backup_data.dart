/// Value types for the automatic off-app backup (the "保险" layer).
///
/// A manual export goes through the share sheet, which needs the user in the
/// loop. That is not enough protection: the App's private data directory is
/// deleted by an uninstall, and the app declares `allowBackup="false"`, so a
/// normal reinstall (or a bad tooling command) can destroy every record with
/// no recovery path. [AutoBackupEntry] models one automatically written copy,
/// kept OUTSIDE the app's private storage (see `auto_backup_storage.dart`).
///
/// Everything here is immutable and platform-free, so the copy/retention rules
/// are unit-testable without a MethodChannel.
library;

import 'package:flutter/foundation.dart';

/// One automatically saved backup file, as reported by the platform store.
@immutable
class AutoBackupEntry {
  /// Creates an entry for [fileName] (a `data-*.json` document).
  const AutoBackupEntry({
    required this.fileName,
    required this.sizeBytes,
    required this.savedAt,
  });

  /// The document name inside the backup folder (e.g. `data-20261030-211500.json`).
  final String fileName;

  /// The document size in bytes.
  final int sizeBytes;

  /// When the platform recorded the document (local time on this device).
  final DateTime savedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AutoBackupEntry &&
        other.fileName == fileName &&
        other.sizeBytes == sizeBytes &&
        other.savedAt == savedAt;
  }

  @override
  int get hashCode => Object.hash(fileName, sizeBytes, savedAt);

  @override
  String toString() => 'AutoBackupEntry($fileName, $sizeBytes bytes, $savedAt)';
}

/// What one run of the automatic backup did.
///
/// [throttled] and [disabled] are "not due yet" outcomes, not failures: the
/// lifecycle trigger runs on every launch/background transition and must stay
/// cheap.
enum AutoBackupOutcome {
  /// A new copy was written and the retention window pruned.
  saved,

  /// The database held nothing to back up (fresh install), so no file was
  /// written and no old copy was touched.
  skippedEmpty,

  /// The minimum interval since the last run has not elapsed.
  throttled,

  /// The user turned automatic backup off.
  disabled,

  /// This platform/build has no durable backup target.
  unavailable,

  /// The platform store refused the write (or the channel failed).
  failed,
}

/// The result of [AutoBackupService.runNow] / [AutoBackupService.maybeRun].
@immutable
class AutoBackupResult {
  /// Creates a result; [fileName] is set only for [AutoBackupOutcome.saved].
  const AutoBackupResult(this.outcome, {this.fileName, this.error});

  /// What happened.
  final AutoBackupOutcome outcome;

  /// The written document's name, when [didSave].
  final String? fileName;

  /// The underlying error for [AutoBackupOutcome.failed].
  final Object? error;

  /// `true` when a new backup file was written.
  bool get didSave => outcome == AutoBackupOutcome.saved;

  @override
  String toString() =>
      'AutoBackupResult($outcome${fileName == null ? '' : ', $fileName'})';
}

/// Snapshot of the backup feature's state for the backup screen.
@immutable
class AutoBackupStatus {
  /// Creates a status; [entries] are newest first.
  const AutoBackupStatus({
    required this.available,
    required this.enabled,
    this.entries = const <AutoBackupEntry>[],
  });

  /// Whether the platform offers a durable backup target.
  final bool available;

  /// Whether automatic backup is switched on.
  final bool enabled;

  /// Saved copies, newest first.
  final List<AutoBackupEntry> entries;

  /// The newest copy, or `null` when none exists.
  AutoBackupEntry? get latest => entries.isEmpty ? null : entries.first;

  @override
  String toString() =>
      'AutoBackupStatus(available: $available, enabled: $enabled, '
      'entries: ${entries.length})';
}
