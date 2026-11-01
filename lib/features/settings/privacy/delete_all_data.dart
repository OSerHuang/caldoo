/// "Delete all local data": wipes every Drift table (including the non-secret
/// `app_settings`, hence the privacy-notice flag) and the BYOK key from secure
/// storage.
///
/// The wipe is local-only — no account, no server round-trip. The UI action
/// ([DeleteAllDataButton]) always shows a confirm dialog first, so an
/// accidental tap can never destroy data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_providers.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Wipes all on-device user data.
class LocalDataWiper {
  /// Creates the wiper over the [db] and the secret [keyStore].
  const LocalDataWiper({required this.db, required this.keyStore});

  /// The Drift database holding every user table.
  final AppDatabase db;

  /// The only gateway to the BYOK key (`flutter_secure_storage`).
  final SecureKeyStore keyStore;

  /// Deletes every row from every table, then clears the stored API key.
  ///
  /// Children are removed before parents because foreign keys are ON; the
  /// whole DB portion runs in a single transaction so a partial wipe cannot
  /// happen. The secret is cleared only after the DB commit succeeds.
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
  }
}

/// The [LocalDataWiper] wired to the app DB and the secret store.
final localDataWiperProvider = Provider<LocalDataWiper>(
  (ref) => LocalDataWiper(
    db: ref.watch(appDatabaseProvider),
    keyStore: ref.watch(secureKeyStoreProvider),
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
