import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:caldoo/data/db/app_database.dart';

/// Opens a fresh in-memory [AppDatabase] for tests.
///
/// Every DB test MUST go through this helper:
/// - `NativeDatabase.memory()` never touches the on-disk `caldoo.sqlite`.
/// - `closeStreamsSynchronously: true` makes [AppDatabase.close] end query
///   streams synchronously, so a leaked `watch` subscription can never keep a
///   test (or a widget test's teardown) hanging.
///
/// The caller owns the returned database and must `await db.close()`.
AppDatabase testDb() {
  // Tests deliberately open several independent in-memory databases at once
  // (e.g. an export -> import round-trip); that is safe because each has its
  // own executor. Silence drift's heuristic warning so real issues stay visible.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  return AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}
