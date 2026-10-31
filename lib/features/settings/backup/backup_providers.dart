/// Riverpod wiring for the backup feature (task 28).
///
/// A thin seam only: the settings screen (wired in a later task) reads
/// [backupServiceProvider] instead of constructing a [BackupService] itself,
/// so tests can override [appDatabaseProvider] with an in-memory database and
/// exercise the exact production graph.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/features/settings/backup/backup_service.dart';

/// The backup service over the app's single [appDatabaseProvider].
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);
