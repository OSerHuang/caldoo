/// The data-backup screen (wired into the shell by task 27).
///
/// Three layers, from automatic to manual:
/// * **自动备份** — [AutoBackupService] writes a copy of the whole dataset to
///   the public downloads folder on every launch/background transition (see
///   `auto_backup_lifecycle.dart`). Kept outside the app's private directory on
///   purpose: an uninstall deletes the database, not the downloads folder, so
///   this is the layer that survives a reinstall. The screen lists those copies
///   and restores them additively.
/// * **导出 / 导入** — the share sheet / pasted JSON path over the same
///   [BackupService] (task 28).
/// * **从文件导入** — the system file picker, so a `data.json` from another
///   device (or a copy from before a reinstall) can be brought back in.
///
/// The API key is never part of a backup (it lives in secure storage), so no
/// action here can leak it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'auto_backup_data.dart';
import 'auto_backup_providers.dart';
import 'auto_backup_service.dart';
import 'backup_data.dart';
import 'backup_providers.dart';
import 'backup_share.dart';

/// Key of the backup screen scaffold.
const Key backupScreenKey = Key('backup_screen');

/// Key of the export action.
const Key backupExportKey = Key('backup_export_button');

/// Key of the import action.
const Key backupImportKey = Key('backup_import_button');

/// Key of the import dialog's text field.
const Key backupImportFieldKey = Key('backup_import_field');

/// Key of the import dialog's submit button.
const Key backupImportSubmitKey = Key('backup_import_submit');

/// Key of the result/error readout.
const Key backupResultKey = Key('backup_result');

/// Key of the automatic-backup switch.
const Key autoBackupToggleKey = Key('auto_backup_toggle');

/// Key of the "back up now" action.
const Key autoBackupNowKey = Key('auto_backup_now_button');

/// Key of the automatic-backup status line.
const Key autoBackupStatusKey = Key('auto_backup_status');

/// Key of the restore confirm dialog.
const Key autoBackupRestoreDialogKey = Key('auto_backup_restore_dialog');

/// Key of the restore confirm action.
const Key autoBackupRestoreConfirmKey = Key('auto_backup_restore_confirm');

/// Key of the "import from file" action.
const Key backupImportFileKey = Key('backup_import_file_button');

/// Key of one listed automatic backup.
Key autoBackupEntryKey(String fileName) =>
    ValueKey<String>('auto_backup_entry_$fileName');

/// The data backup / restore screen.
class BackupScreen extends ConsumerStatefulWidget {
  /// Creates the backup screen.
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String? _result;
  bool _busy = false;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final String json = await ref.read(backupServiceProvider).exportToJson();
      await shareBackupJson(json);
      if (mounted) {
        setState(() => _result = S.instance.backupGenerated(json.length));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _result = S.instance.backupExportFailed(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    final TextEditingController controller = TextEditingController();
    final String? source = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('backup_import_dialog'),
        title: Text(S.of(dialogContext).importBackupTitle),
        content: TextField(
          key: backupImportFieldKey,
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: S.of(dialogContext).pasteBackupHint,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: backupImportSubmitKey,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(S.of(dialogContext).importAction),
          ),
        ],
      ),
    );
    controller.dispose();
    if (source == null || source.trim().isEmpty || !mounted) {
      return;
    }
    await _applyImport(
      () => ref.read(backupServiceProvider).importFromJson(source),
    );
  }

  Future<void> _importFromFile() async {
    await _applyImport(() async {
      final ImportSummary? summary = await ref
          .read(autoBackupServiceProvider)
          .importPickedFile();
      if (summary == null) {
        throw const _CancelledImport();
      }
      return summary;
    });
  }

  /// Runs one import through the shared busy/result handling.
  Future<void> _applyImport(Future<ImportSummary> Function() import) async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final ImportSummary summary = await import();
      if (mounted) {
        setState(
          () => _result = S.instance.backupImported(
            summary.totalImported,
            summary.totalSkipped,
          ),
        );
      }
    } on _CancelledImport {
      if (mounted) {
        setState(() => _result = S.instance.backupImportFileCancelled);
      }
    } on BackupException catch (error) {
      if (mounted) {
        setState(() => _result = S.instance.backupImportFailed(error.message));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _result = S.instance.backupImportFailed(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runAutoBackupNow() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final AutoBackupResult result = await ref
          .read(autoBackupServiceProvider)
          .runNow();
      if (mounted) {
        setState(() => _result = _describeAutoBackup(result));
      }
      ref.invalidate(autoBackupStatusProvider);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _result = S.instance.autoBackupFailed(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _describeAutoBackup(AutoBackupResult result) =>
      switch (result.outcome) {
        AutoBackupOutcome.saved => S.instance.autoBackupSaved(
          result.fileName ?? '',
        ),
        AutoBackupOutcome.skippedEmpty => S.instance.autoBackupSkippedEmpty,
        AutoBackupOutcome.unavailable => S.instance.autoBackupUnavailable,
        AutoBackupOutcome.failed => S.instance.autoBackupFailed(result.error!),
        AutoBackupOutcome.disabled ||
        AutoBackupOutcome.throttled => S.instance.autoBackupSkippedEmpty,
      };

  Future<void> _restoreAutoBackup(AutoBackupEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: autoBackupRestoreDialogKey,
        title: Text(S.of(dialogContext).autoBackupRestoreTitle),
        content: Text(
          S
              .of(dialogContext)
              .autoBackupRestoreBody(
                AppFormat.dateTimeMinute(entry.savedAt),
                AppFormat.bytes(entry.sizeBytes),
              ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: autoBackupRestoreConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).autoBackupRestoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final ImportSummary summary = await ref
          .read(autoBackupServiceProvider)
          .restore(entry);
      if (mounted) {
        setState(
          () => _result = S.instance.backupImported(
            summary.totalImported,
            summary.totalSkipped,
          ),
        );
      }
    } on AutoBackupMissingException {
      if (mounted) {
        setState(() => _result = S.instance.autoBackupMissing(entry.fileName));
      }
    } on BackupException catch (error) {
      if (mounted) {
        setState(() => _result = S.instance.backupImportFailed(error.message));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setEnabled(bool value) async {
    await ref.read(autoBackupEnabledProvider.notifier).setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final S strings = S.of(context);
    final AsyncValue<AutoBackupStatus> status = ref.watch(
      autoBackupStatusProvider,
    );
    final AsyncValue<bool> enabled = ref.watch(autoBackupEnabledProvider);
    final AutoBackupStatus? current = status.value;
    final bool available = current?.available ?? false;
    final List<AutoBackupEntry> entries =
        current?.entries ?? const <AutoBackupEntry>[];
    final bool isEnabled = enabled.value ?? current?.enabled ?? true;

    return Scaffold(
      key: backupScreenKey,
      appBar: AppBar(title: Text(strings.backupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(strings.backupIntro),
          const SizedBox(height: 24),
          Text(
            strings.autoBackupTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(strings.autoBackupIntro),
          SwitchListTile(
            key: autoBackupToggleKey,
            contentPadding: EdgeInsets.zero,
            value: isEnabled,
            onChanged: available && !_busy ? _setEnabled : null,
            title: Text(strings.autoBackupToggle),
            subtitle: Text(strings.autoBackupLocation),
          ),
          Text(
            _statusLine(strings, available, entries),
            key: autoBackupStatusKey,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (available) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: autoBackupNowKey,
              onPressed: _busy ? null : _runAutoBackupNow,
              icon: const Icon(Icons.shield_outlined),
              label: Text(strings.autoBackupNow),
            ),
            for (final AutoBackupEntry entry in entries.take(5))
              ListTile(
                key: autoBackupEntryKey(entry.fileName),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore),
                title: Text(AppFormat.dateTimeMinute(entry.savedAt)),
                subtitle: Text(AppFormat.bytes(entry.sizeBytes)),
                trailing: Text(strings.autoBackupRestoreAction),
                onTap: _busy ? null : () => _restoreAutoBackup(entry),
              ),
          ],
          const Divider(height: 32),
          FilledButton.icon(
            key: backupExportKey,
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: Text(strings.exportBackup),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: backupImportFileKey,
            onPressed: _busy ? null : _importFromFile,
            icon: const Icon(Icons.folder_open),
            label: Text(strings.backupImportFromFile),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: backupImportKey,
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.download),
            label: Text(strings.importBackup),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_result!, key: backupResultKey),
            ),
        ],
      ),
    );
  }

  String _statusLine(S strings, bool available, List<AutoBackupEntry> entries) {
    if (!available) {
      return strings.autoBackupUnavailable;
    }
    if (entries.isEmpty) {
      return strings.autoBackupNever;
    }
    return strings.autoBackupLastAt(
      AppFormat.dateTimeMinute(entries.first.savedAt),
      entries.length,
    );
  }
}

/// Internal signal: the file picker was dismissed without a file.
class _CancelledImport implements Exception {
  const _CancelledImport();
}
