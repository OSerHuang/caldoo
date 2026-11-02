/// The automatic off-app backup: capture, keep the newest copies, restore.
///
/// The rules this file enforces:
/// * **never overwrite a good copy with an empty database** — a fresh install
///   holds nothing, so a run then is skipped instead of rotating the only
///   surviving backups away;
/// * **bounded retention** — at most [keepCount] documents, newest kept, so
///   the downloads folder cannot grow without limit;
/// * **cheap lifecycle calls** — the trigger runs on every launch/background
///   transition but only actually captures once per [minInterval];
/// * **a backup failure never breaks the app** — every platform error is
///   turned into an [AutoBackupResult] instead of escaping to the UI thread.
library;

import 'package:clock/clock.dart';

import 'package:caldoo/data/settings/app_settings_store.dart';
import 'package:caldoo/features/settings/backup/backup_codec.dart';
import 'package:caldoo/features/settings/backup/backup_data.dart';
import 'package:caldoo/features/settings/backup/backup_service.dart';

import 'auto_backup_data.dart';
import 'auto_backup_storage.dart';

/// Captures the whole database into the durable, uninstall-surviving folder.
class AutoBackupService {
  /// Creates the service over the existing [BackupService] (capture/restore),
  /// the platform [storage] seam and the non-secret [settings] store.
  ///
  /// [clock] is injected so tests can pin file names and the throttle window.
  AutoBackupService({
    required BackupService backupService,
    required AutoBackupStorage autoBackupStorage,
    required AppSettingsStore settingsStore,
    Clock? clock,
  }) : _backup = backupService,
       _storage = autoBackupStorage,
       _settings = settingsStore,
       _clock = clock ?? const Clock();

  /// The `app_settings` key holding the user's on/off choice (default: on).
  static const String enabledSettingKey = 'auto_backup_enabled';

  /// How many documents the folder keeps; older copies are pruned.
  static const int keepCount = 10;

  /// Minimum time between two lifecycle-triggered captures.
  static const Duration minInterval = Duration(minutes: 5);

  /// File-name prefix, so a folder can hold other JSON documents safely.
  static const String filePrefix = 'data-';

  final BackupService _backup;
  final AutoBackupStorage _storage;
  final AppSettingsStore _settings;
  final Clock _clock;

  /// When this process last wrote a copy (in-memory; resets on restart).
  DateTime? _lastRunAt;

  /// Reads the switch; absent means on (the safety net is opt-out).
  Future<bool> isEnabled() =>
      _settings.readBool(enabledSettingKey, fallback: true);

  /// Persists the switch toggled from the backup screen.
  Future<void> setEnabled(bool value) =>
      _settings.writeBool(enabledSettingKey, value);

  /// Whether the current build can write a durable copy.
  Future<bool> isAvailable() => _storage.isAvailable();

  /// Everything the backup screen needs to render its status.
  Future<AutoBackupStatus> status() async {
    final bool enabled = await isEnabled();
    final bool available = await _storage.isAvailable();
    final List<AutoBackupEntry> entries = available
        ? await _storage.list()
        : const <AutoBackupEntry>[];
    return AutoBackupStatus(
      available: available,
      enabled: enabled,
      entries: entries,
    );
  }

  /// Captures now, unconditionally (the screen's 立即备份 button).
  Future<AutoBackupResult> runNow() async {
    if (!await _storage.isAvailable()) {
      return const AutoBackupResult(AutoBackupOutcome.unavailable);
    }
    try {
      final BackupData data = await _backup.capture();
      if (data.isEmpty) {
        // Fresh install: writing an empty snapshot would only push a real
        // backup out of the retention window.
        return const AutoBackupResult(AutoBackupOutcome.skippedEmpty);
      }
      final String fileName = fileNameFor(_clock.now());
      await _storage.save(fileName, encodeBackup(data));
      await _prune();
      _lastRunAt = _clock.now();
      return AutoBackupResult(AutoBackupOutcome.saved, fileName: fileName);
    } on Object catch (error) {
      return AutoBackupResult(AutoBackupOutcome.failed, error: error);
    }
  }

  /// The lifecycle trigger: runs only when the switch is on, the platform can
  /// write, and the throttle window has elapsed. Returns `null` when no run
  /// was attempted for a reason that is not worth surfacing.
  Future<AutoBackupResult?> maybeRun() async {
    if (!await isEnabled()) {
      return const AutoBackupResult(AutoBackupOutcome.disabled);
    }
    if (!await _storage.isAvailable()) {
      return const AutoBackupResult(AutoBackupOutcome.unavailable);
    }
    final DateTime now = _clock.now();
    final DateTime? last = _lastRunAt;
    if (last != null && now.difference(last) < minInterval) {
      return const AutoBackupResult(AutoBackupOutcome.throttled);
    }
    return runNow();
  }

  /// Applies the backup document [entry] additively (existing rows win).
  ///
  /// Throws [AutoBackupMissingException] when the document is no longer
  /// readable (e.g. it belongs to a previous install), and the typed
  /// [BackupException]s when its contents are rejected.
  Future<ImportSummary> restore(AutoBackupEntry entry) async {
    final String? json = await _storage.read(entry.fileName);
    if (json == null) {
      throw AutoBackupMissingException(entry.fileName);
    }
    return _backup.importFromJson(json);
  }

  /// Opens the system file picker and imports whatever JSON the user chooses.
  ///
  /// Returns `null` when the picker was cancelled (or unavailable), so the
  /// caller can stay silent instead of reporting a fake failure.
  Future<ImportSummary?> importPickedFile() async {
    final String? json = await _storage.pickJsonFile();
    if (json == null || json.trim().isEmpty) {
      return null;
    }
    return _backup.importFromJson(json);
  }

  /// Deletes the oldest documents beyond [keepCount].
  ///
  /// Deletion failures are deliberately ignored: a document written by another
  /// install is still a valid recovery copy, and pruning must never fail the
  /// backup that just succeeded.
  Future<void> _prune() async {
    final List<AutoBackupEntry> entries = await _storage.list();
    if (entries.length <= keepCount) {
      return;
    }
    final List<AutoBackupEntry> sorted = <AutoBackupEntry>[...entries]
      ..sort(
        (AutoBackupEntry a, AutoBackupEntry b) =>
            b.savedAt.compareTo(a.savedAt),
      );
    for (final AutoBackupEntry old in sorted.skip(keepCount)) {
      await _storage.delete(old.fileName);
    }
  }

  /// `data-20261030-211500.json` — the local wall-clock time, second
  /// resolution, so copies sort naturally and never collide.
  static String fileNameFor(DateTime localTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    final String date =
        '${localTime.year}${two(localTime.month)}${two(localTime.day)}';
    final String time =
        '${two(localTime.hour)}${two(localTime.minute)}'
        '${two(localTime.second)}';
    return '$filePrefix$date-$time.json';
  }
}

/// Thrown when a listed backup document can no longer be read.
class AutoBackupMissingException implements Exception {
  /// Creates the failure for [fileName].
  const AutoBackupMissingException(this.fileName);

  /// The document that could not be read.
  final String fileName;

  @override
  String toString() => 'AutoBackupMissingException: $fileName';
}
