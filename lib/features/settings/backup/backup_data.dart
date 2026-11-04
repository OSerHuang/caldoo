/// Value types for the versioned JSON backup (task 28).
///
/// The backup is split into three parts so the round-trip is testable without
/// any platform channel:
/// * [BackupData] — a plain, immutable snapshot of the user's local data;
/// * `backup_codec.dart` — a PURE `BackupData <-> String` codec (no Drift, no
///   `share_plus`), plus the typed error taxonomy;
/// * `backup_service.dart` — the Drift capture/restore half;
/// * `backup_share.dart` — the only part that touches the share sheet.
///
/// SECURITY: [BackupData] has no field for the API key by construction. The
/// key lives exclusively in secure storage and is never read by the capture
/// path, so it cannot leak into an export (see the task-28 security test).
library;

import 'package:flutter/foundation.dart';

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/models/weight_entry.dart';

/// On-disk schema version stamped into every export.
///
/// Bump this whenever the JSON shape changes in a non-additive way; an import
/// of any other version is rejected with a [BackupSchemaVersionException]
/// (never a silent, best-effort parse).
///
/// History:
/// * 1 — MET-session exercise rows (no longer supported: the exercise feature
///   changed shape).
/// * 2 — one daily exercise-burn kcal per day; the profile still stored
///   `age`.
/// * 3 — the profile stores a canonical `birthDate` instead of `age` (age is
///   derived). Version-2 files are still importable: the stored age is
///   converted to a birthday in [decodeBackup].
/// * 4 — energy is integer-only: `foods.kcal`, `meal_items.kcal`,
///   `daily_exercises.kcal` and the profile's `bmrKcalOverride` are written as
///   whole-kcal integers. Versions 2 and 3 remain importable: their fractional
///   energy numbers are rounded at the JSON boundary by the model parsers.
/// * 5 — adds the `weightEntries` section (the one-per-day body-weight
///   history) and the profile's `dailyKcalGoalOverride` field. Versions 2–4
///   remain importable: a missing section decodes as empty and a missing
///   profile field decodes as `null` (no goal).
/// * 6 — the profile's daily goal may now be a BMR-relative preset
///   (`dailyGoalPreset`: slowCut / fastCut / gain) that follows the body
///   weight, next to the fixed `dailyKcalGoalOverride`. Bumped rather than
///   slipped into version 5: an older build would import a version-5 file
///   happily and silently DROP the preset (the budget would fall back to the
///   BMR), so the version stamp makes the incompatibility explicit. Versions
///   2–5 remain importable — their profile simply has no preset.
const int backupSchemaVersion = 6;

/// Versions [decodeBackup] can still read (the current one plus the legacy
/// age-based profile shapes). Anything else is rejected outright.
const Set<int> supportedBackupSchemaVersions = <int>{2, 3, 4, 5, 6};

/// `app_settings` keys that are transient UI state or device preferences, not
/// user data.
///
/// `notice_seen` is a per-install privacy-notice flag (task 29), so it is
/// EXCLUDED from the export and ignored on import. `auto_backup_enabled` is
/// the automatic-backup switch: it belongs to the DEVICE (and must not travel
/// into a `data.json` restored on a new phone, where it should simply start
/// on). `baseUrl`/`model` stay: they are non-secret preferences the user
/// actually chose.
const Set<String> backupExcludedSettingsKeys = <String>{
  'notice_seen',
  'auto_backup_enabled',
};

/// A full, portable snapshot of the user's local data.
///
/// Equality is deep (including each meal's item list) so a
/// `capture -> encode -> decode` round-trip can be asserted with `==`.
@immutable
class BackupData {
  /// Creates a snapshot. Omitted collections default to empty.
  const BackupData({
    this.profile,
    this.foods = const <Food>[],
    this.meals = const <MealWithItems>[],
    this.dailyExercises = const <DailyExercise>[],
    this.weightEntries = const <WeightEntry>[],
    this.settings = const <String, String>{},
  });

  /// The single user profile, or `null` before onboarding.
  final UserProfile? profile;

  /// Every saved food.
  final List<Food> foods;

  /// Every logged meal with its items.
  final List<MealWithItems> meals;

  /// The one-per-day exercise-burn values.
  final List<DailyExercise> dailyExercises;

  /// The one-per-day body-weight values.
  final List<WeightEntry> weightEntries;

  /// Non-secret `app_settings` entries (excludes [backupExcludedSettingsKeys]).
  final Map<String, String> settings;

  /// `true` when there is nothing at all to back up.
  bool get isEmpty =>
      profile == null &&
      foods.isEmpty &&
      meals.isEmpty &&
      dailyExercises.isEmpty &&
      weightEntries.isEmpty &&
      settings.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BackupData &&
        other.profile == profile &&
        listEquals(other.foods, foods) &&
        _mealsEqual(other.meals, meals) &&
        listEquals(other.dailyExercises, dailyExercises) &&
        listEquals(other.weightEntries, weightEntries) &&
        mapEquals(other.settings, settings);
  }

  @override
  int get hashCode => Object.hash(
    profile,
    Object.hashAll(foods),
    Object.hashAll(
      meals.map(
        (group) => Object.hash(group.meal, Object.hashAll(group.items)),
      ),
    ),
    Object.hashAll(dailyExercises),
    Object.hashAll(weightEntries),
    Object.hashAll(
      settings.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  @override
  String toString() =>
      'BackupData(profile: ${profile != null}, foods: ${foods.length}, '
      'meals: ${meals.length}, dailyExercises: ${dailyExercises.length}, '
      'weightEntries: ${weightEntries.length}, settings: ${settings.length})';

  static bool _mealsEqual(List<MealWithItems> a, List<MealWithItems> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i].meal != b[i].meal) {
        return false;
      }
      if (!listEquals(a[i].items, b[i].items)) {
        return false;
      }
    }
    return true;
  }
}

/// Per-category tally of an import, so the caller can report exactly what was
/// kept and what was skipped instead of guessing.
///
/// "Skipped" covers two cases, both resolved in favour of the EXISTING row:
/// * the id already exists locally, so the incoming row is dropped;
/// * a skipped parent (meal) drags its children down with it, so no orphaned
///   `meal_items` row can ever be written.
@immutable
class ImportSummary {
  /// Creates a summary; every counter defaults to zero.
  const ImportSummary({
    this.profileImported = 0,
    this.profileSkipped = 0,
    this.foodsImported = 0,
    this.foodsSkipped = 0,
    this.mealsImported = 0,
    this.mealsSkipped = 0,
    this.mealItemsImported = 0,
    this.mealItemsSkipped = 0,
    this.dailyExercisesImported = 0,
    this.dailyExercisesSkipped = 0,
    this.weightEntriesImported = 0,
    this.weightEntriesSkipped = 0,
    this.settingsImported = 0,
    this.settingsSkipped = 0,
  });

  /// `profile` counters (0 or 1 each).
  final int profileImported;
  final int profileSkipped;

  /// `foods` counters.
  final int foodsImported;
  final int foodsSkipped;

  /// `meals` counters.
  final int mealsImported;
  final int mealsSkipped;

  /// `meal_items` counters.
  final int mealItemsImported;
  final int mealItemsSkipped;

  /// `daily_exercises` counters.
  final int dailyExercisesImported;
  final int dailyExercisesSkipped;

  /// `weight_entries` counters.
  final int weightEntriesImported;
  final int weightEntriesSkipped;

  /// `app_settings` counters.
  final int settingsImported;
  final int settingsSkipped;

  /// Rows written to the local database.
  int get totalImported =>
      profileImported +
      foodsImported +
      mealsImported +
      mealItemsImported +
      dailyExercisesImported +
      weightEntriesImported +
      settingsImported;

  /// Rows dropped because an identical id/key already existed (or the parent
  /// meal was dropped).
  int get totalSkipped =>
      profileSkipped +
      foodsSkipped +
      mealsSkipped +
      mealItemsSkipped +
      dailyExercisesSkipped +
      weightEntriesSkipped +
      settingsSkipped;

  /// `true` when the file carried nothing importable.
  bool get isEmpty => totalImported == 0 && totalSkipped == 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ImportSummary &&
        other.profileImported == profileImported &&
        other.profileSkipped == profileSkipped &&
        other.foodsImported == foodsImported &&
        other.foodsSkipped == foodsSkipped &&
        other.mealsImported == mealsImported &&
        other.mealsSkipped == mealsSkipped &&
        other.mealItemsImported == mealItemsImported &&
        other.mealItemsSkipped == mealItemsSkipped &&
        other.dailyExercisesImported == dailyExercisesImported &&
        other.dailyExercisesSkipped == dailyExercisesSkipped &&
        other.weightEntriesImported == weightEntriesImported &&
        other.weightEntriesSkipped == weightEntriesSkipped &&
        other.settingsImported == settingsImported &&
        other.settingsSkipped == settingsSkipped;
  }

  @override
  int get hashCode => Object.hash(
    profileImported,
    profileSkipped,
    foodsImported,
    foodsSkipped,
    mealsImported,
    mealsSkipped,
    mealItemsImported,
    mealItemsSkipped,
    dailyExercisesImported,
    dailyExercisesSkipped,
    weightEntriesImported,
    weightEntriesSkipped,
    settingsImported,
    settingsSkipped,
  );

  @override
  String toString() =>
      'ImportSummary(imported: $totalImported, skipped: $totalSkipped, '
      'profile: $profileImported/$profileSkipped, '
      'foods: $foodsImported/$foodsSkipped, '
      'meals: $mealsImported/$mealsSkipped, '
      'mealItems: $mealItemsImported/$mealItemsSkipped, '
      'dailyExercises: $dailyExercisesImported/$dailyExercisesSkipped, '
      'weightEntries: $weightEntriesImported/$weightEntriesSkipped, '
      'settings: $settingsImported/$settingsSkipped)';
}

/// Base type for every backup failure the codec/service can surface.
///
/// Callers switch on the concrete type, so a rejected file never masquerades
/// as a generic parse error.
sealed class BackupException implements Exception {
  /// Creates a failure with a human-readable [message].
  const BackupException(this.message);

  /// What went wrong, safe to show to the user.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The payload is not parseable as the expected JSON shape.
///
/// Covers both invalid JSON text and valid JSON with the wrong types/keys.
final class BackupFormatException extends BackupException {
  /// Creates a format failure.
  const BackupFormatException(super.message);
}

/// The payload is well-formed JSON but stamped with an unsupported version.
final class BackupSchemaVersionException extends BackupException {
  /// Creates a version failure recording what was found vs. expected.
  const BackupSchemaVersionException({
    required this.found,
    required this.expected,
  }) : super(
         'Unsupported backup schemaVersion: found $found, expected $expected',
       );

  /// The `schemaVersion` read from the file.
  final int found;

  /// The [backupSchemaVersion] this build understands.
  final int expected;
}
