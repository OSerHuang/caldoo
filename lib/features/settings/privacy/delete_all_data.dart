/// "Delete all local data": wipes every Drift table (including the non-secret
/// `app_settings`, hence the privacy-notice flag), the BYOK key from secure
/// storage, and the automatic backups in the public downloads folder.
///
/// The wipe is local-only — no account, no server round-trip. The UI action
/// ([DeleteAllDataButton]) always shows a confirm dialog first, so an
/// accidental tap can never destroy data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/features/settings/backup/auto_backup_data.dart';
import 'package:caldoo/features/settings/backup/auto_backup_providers.dart'
    show autoBackupStatusProvider, autoBackupStorageProvider;
import 'package:caldoo/features/settings/backup/auto_backup_storage.dart';
import 'package:caldoo/features/settings/display_settings_providers.dart';
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_providers.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Wipes all on-device user data.
class LocalDataWiper {
  /// Creates the wiper over the [db], the secret [keyStore] and the durable
  /// [autoBackupStorage].
  const LocalDataWiper({
    required this.db,
    required this.keyStore,
    required this.autoBackupStorage,
  });

  /// The Drift database holding every user table.
  final AppDatabase db;

  /// The only gateway to the BYOK key (`flutter_secure_storage`).
  final SecureKeyStore keyStore;

  /// The durable backup folder (the public downloads area on Android).
  final AutoBackupStorage autoBackupStorage;

  /// Deletes every row from every table, then clears the stored API key, then
  /// removes the automatic backups.
  ///
  /// Children are removed before parents because foreign keys are ON; the
  /// whole DB portion runs in a single transaction so a partial wipe cannot
  /// happen. The secret is cleared only after the DB commit succeeds.
  ///
  /// The backups are deleted last, best-effort: the confirm dialog promises
  /// they are gone, but a document the platform refuses to remove (e.g. one
  /// written by a previous install) must not fail the already-completed wipe —
  /// it stays visible in the file manager, where the user can delete it by
  /// hand.
  Future<void> wipe() async {
    await db.transaction(() async {
      await db.delete(db.mealItems).go();
      await db.delete(db.meals).go();
      await db.delete(db.dailyExercises).go();
      await db.delete(db.weightEntries).go();
      await db.delete(db.foods).go();
      await db.delete(db.userProfiles).go();
      await db.delete(db.appSettings).go();
    });
    await keyStore.delete();
    await _deleteAutoBackups();
  }

  /// Removes every document in the backup folder. The production store
  /// already degrades missing documents and platform errors to no-ops; the
  /// catch keeps even an unexpected store failure from failing the wipe.
  Future<void> _deleteAutoBackups() async {
    try {
      for (final AutoBackupEntry entry in await autoBackupStorage.list()) {
        await autoBackupStorage.delete(entry.fileName);
      }
    } on Exception {
      // Best effort only — see the wipe() doc above.
    }
  }
}

/// The [LocalDataWiper] wired to the app DB, the secret store and the durable
/// backup store.
final localDataWiperProvider = Provider<LocalDataWiper>(
  (ref) => LocalDataWiper(
    db: ref.watch(appDatabaseProvider),
    keyStore: ref.watch(secureKeyStoreProvider),
    autoBackupStorage: ref.watch(autoBackupStorageProvider),
  ),
);

/// Settings action that wipes all local data behind a confirm dialog.
///
/// Cancelling the dialog (or dismissing it) is a strict no-op.
class DeleteAllDataButton extends ConsumerWidget {
  /// Creates the destructive settings action.
  const DeleteAllDataButton({super.key});

  Future<void> _confirmAndWipe(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('privacy_delete_confirm_dialog'),
        title: Text(S.of(dialogContext).deleteConfirmTitle),
        content: Text(S.of(dialogContext).deleteConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('privacy_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: const Key('privacy_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(localDataWiperProvider).wipe();
    if (!context.mounted) {
      return;
    }
    // The wiped flag/key are now stale in memory: re-read them so the notice
    // reappears and the settings form shows an empty key.
    ref.invalidate(privacyNoticeSeenProvider);
    ref.invalidate(settingsControllerProvider);
    ref.invalidate(aiSettingsConfigProvider);
    // The wipe also deleted the display-unit rows; without this the session
    // keeps rendering the pre-wipe unit for rows that no longer exist, until
    // the next launch silently reverts it.
    ref.invalidate(displaySettingsProvider);
    // The backup folder is empty now; the backup screen must not show the
    // deleted documents until it re-lists.
    ref.invalidate(autoBackupStatusProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).dataDeletedSnack)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const Key('privacy_delete_all_button'),
      onPressed: () async {
        await _confirmAndWipe(context, ref);
      },
      icon: const Icon(Icons.delete_forever),
      label: Text(S.of(context).deleteAllData),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
