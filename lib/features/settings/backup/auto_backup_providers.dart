/// Riverpod wiring for the automatic off-app backup.
///
/// [autoBackupStorageProvider] is the platform seam: tests (and the golden
/// render harness) override it with an in-memory store so no MethodChannel is
/// ever touched; production uses [ChannelAutoBackupStorage].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show appSettingsStoreProvider;
import 'package:caldoo/features/settings/backup/auto_backup_data.dart';
import 'package:caldoo/features/settings/backup/auto_backup_service.dart';
import 'package:caldoo/features/settings/backup/auto_backup_storage.dart';
import 'package:caldoo/features/settings/backup/backup_providers.dart';

/// The durable document store: public downloads area on Android, an
/// in-memory fake in tests.
final autoBackupStorageProvider = Provider<AutoBackupStorage>(
  (ref) => ChannelAutoBackupStorage(),
);

/// The capture/retain/restore service behind the backup screen.
final autoBackupServiceProvider = Provider<AutoBackupService>(
  (ref) => AutoBackupService(
    backupService: ref.watch(backupServiceProvider),
    autoBackupStorage: ref.watch(autoBackupStorageProvider),
    settingsStore: ref.watch(appSettingsStoreProvider),
  ),
);

/// The state shown by the backup screen. Invalidated after a manual backup,
/// a toggle or a restore.
final autoBackupStatusProvider = FutureProvider<AutoBackupStatus>(
  (ref) => ref.watch(autoBackupServiceProvider).status(),
);

/// The 开启自动备份 switch, backed by the `app_settings` table.
class AutoBackupEnabledController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(autoBackupServiceProvider).isEnabled();

  /// Persists [value] and refreshes the screen's status block.
  Future<void> setEnabled(bool value) async {
    await ref.read(autoBackupServiceProvider).setEnabled(value);
    state = AsyncData(value);
    ref.invalidate(autoBackupStatusProvider);
  }
}

/// The automatic-backup switch.
final autoBackupEnabledProvider =
    AsyncNotifierProvider<AutoBackupEnabledController, bool>(
      AutoBackupEnabledController.new,
    );

/// Whether [AutoBackupLifecycle] may run its launch/background capture.
///
/// A test seam, like the dashboard clock providers: the golden render harness
/// boots the whole app and needs a screenshot that does not depend on how far
/// an asynchronous capture got before the frame was captured. Overridden to
/// `false` there; production never touches it.
final autoBackupLifecycleEnabledProvider = Provider<bool>((ref) => true);
