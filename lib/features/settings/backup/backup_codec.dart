/// The PURE, platform-free JSON codec for a backup (task 28).
///
/// Nothing here touches Drift or `share_plus`: it maps [BackupData] to/from a
/// canonical JSON string, so the whole round-trip is unit-testable without a
/// share sheet or a database. All decode failures are surfaced as the typed
/// [BackupException]s from `backup_data.dart`.
library;

import 'dart:convert';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/models/meal.dart';
import 'package:caldoo/domain/models/meal_item.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/domain/services/label_priority.dart'
    show migrateLegacyNotes;

import 'backup_data.dart';

const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

/// Serializes [data] to a `schemaVersion`-stamped JSON document.
///
/// The API key has no field to serialize, and [backupExcludedSettingsKeys]
/// (`notice_seen`) is filtered here as well as at capture time, so a transient
/// UI flag can never reach a shared file. Image binaries are never part of
/// [BackupData] at all.
String encodeBackup(BackupData data) {
  final Map<String, String> settings = <String, String>{
    for (final MapEntry<String, String> entry in data.settings.entries)
      if (!backupExcludedSettingsKeys.contains(entry.key))
        entry.key: entry.value,
  };

  final Map<String, Object?> root = <String, Object?>{
    'schemaVersion': backupSchemaVersion,
    'profile': data.profile?.toJson(),
    'foods': <Object?>[for (final Food food in data.foods) food.toJson()],
    'meals': <Object?>[
      for (final MealWithItems group in data.meals)
        <String, Object?>{
          'meal': group.meal.toJson(),
          'items': <Object?>[
            for (final MealItem item in group.items) item.toJson(),
          ],
        },
    ],
    'dailyExercises': <Object?>[
      for (final DailyExercise exercise in data.dailyExercises)
        exercise.toJson(),
    ],
    'weightEntries': <Object?>[
      for (final WeightEntry entry in data.weightEntries) entry.toJson(),
    ],
    'settings': settings,
  };

  return _encoder.convert(root);
}

/// Parses [source] back into [BackupData].
///
/// Validation order matters: the version is checked BEFORE any section is
/// parsed, so a file from a future schema is rejected wholesale with
/// [BackupSchemaVersionException] rather than half-imported.
///
/// [now] is the reference date used to convert a legacy version-2 profile's
/// stored `age` into a birthday that preserves that age today (the app has no
/// ambient-clock reads in pure code; callers pass their clock).
///
/// Throws [BackupFormatException] when the text is not valid JSON or does not
/// match the expected shape, and [BackupSchemaVersionException] when the
/// stamped version is not in [supportedBackupSchemaVersions].
BackupData decodeBackup(String source, {required DateTime now}) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException catch (error) {
    throw BackupFormatException('Not valid JSON: ${error.message}');
  }

  if (root is! Map<String, dynamic>) {
    throw const BackupFormatException('Backup root must be a JSON object');
  }

  final Object? rawVersion = root['schemaVersion'];
  if (rawVersion is! int) {
    throw const BackupFormatException('Missing or non-integer schemaVersion');
  }
  if (!supportedBackupSchemaVersions.contains(rawVersion)) {
    throw BackupSchemaVersionException(
      found: rawVersion,
      expected: backupSchemaVersion,
    );
  }

  try {
    return BackupData(
      profile: _decodeProfile(root['profile'], now: now),
      // Older backups still carry the retired free-text 补充说明; fold it into
      // the structured fields and drop it, exactly like the v9 data migration.
      foods: <Food>[
        for (final Food food in _decodeList<Food>(
          root['foods'],
          'foods',
          Food.fromJson,
        ))
          migrateLegacyNotes(food),
      ],
      meals: _decodeMeals(root['meals']),
      dailyExercises: _decodeList<DailyExercise>(
        root['dailyExercises'],
        'dailyExercises',
        DailyExercise.fromJson,
      ),
      weightEntries: _decodeList<WeightEntry>(
        root['weightEntries'],
        'weightEntries',
        WeightEntry.fromJson,
      ),
      settings: _decodeSettings(root['settings']),
    );
  } on BackupException {
    rethrow;
  } on Object catch (error) {
    throw BackupFormatException('Malformed backup contents: $error');
  }
}

UserProfile? _decodeProfile(Object? value, {required DateTime now}) {
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw const BackupFormatException('profile must be a JSON object');
  }
  final UserProfile profile;
  if (value.containsKey('birthDate')) {
    profile = UserProfile.fromJson(value);
  } else {
    // Legacy (schema 2): the profile stored `age` in whole years. Back-project
    // a birthday as of [now] so the imported age is exactly the stored one;
    // from then on the age follows the birthday (no yearly edit).
    final Object? rawAge = value['age'];
    if (rawAge is! num || rawAge <= 0) {
      throw const BackupFormatException(
        'legacy profile.age must be a positive number',
      );
    }
    final int age = rawAge.toInt();
    profile = UserProfile.fromJson(<String, dynamic>{
      ...value,
      'age': null,
      'birthDate': DateTime.utc(
        now.year - age,
        now.month,
        now.day,
      ).toIso8601String(),
    });
  }
  _checkProfileGoals(profile, now: now);
  return profile;
}

/// Rejects a decoded profile the energy engine cannot interpret.
///
/// A backup is untrusted input: `UserProfile.fromJson` happily accepts both
/// goal fields at once, and a preset may resolve to a non-positive goal on its
/// own BMR. Letting either reach the database would make every budget read
/// throw (the pages would be unusable, with no in-app way to fix the profile),
/// so both are rejected here as typed format errors instead.
void _checkProfileGoals(UserProfile profile, {required DateTime now}) {
  if (profile.dailyGoalPreset != null &&
      profile.dailyKcalGoalOverride != null) {
    throw const BackupFormatException(
      'profile carries both dailyGoalPreset and dailyKcalGoalOverride; '
      'the two daily-goal representations are mutually exclusive',
    );
  }
  final EnergyBudgetResult budget;
  try {
    budget = computeEnergyBudget(profile: profile, intakeKcal: 0, today: now);
  } on ArgumentError catch (error) {
    throw BackupFormatException('profile is not usable: ${error.message}');
  }
  if (profile.dailyGoalPreset != null &&
      budget is EnergyBudget &&
      budget.goalKcal == null) {
    throw const BackupFormatException(
      'profile dailyGoalPreset resolves to a non-positive daily goal',
    );
  }
}

List<T> _decodeList<T>(
  Object? value,
  String field,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null) {
    return <T>[];
  }
  if (value is! List<Object?>) {
    throw BackupFormatException('$field must be a JSON array');
  }
  final List<T> result = <T>[];
  for (final Object? element in value) {
    if (element is! Map<String, dynamic>) {
      throw BackupFormatException('$field elements must be JSON objects');
    }
    result.add(fromJson(element));
  }
  return result;
}

List<MealWithItems> _decodeMeals(Object? value) {
  if (value == null) {
    return <MealWithItems>[];
  }
  if (value is! List<Object?>) {
    throw const BackupFormatException('meals must be a JSON array');
  }
  final List<MealWithItems> result = <MealWithItems>[];
  for (final Object? element in value) {
    if (element is! Map<String, dynamic>) {
      throw const BackupFormatException('meals elements must be JSON objects');
    }
    final Object? rawMeal = element['meal'];
    if (rawMeal is! Map<String, dynamic>) {
      throw const BackupFormatException('each meal entry needs a meal object');
    }
    result.add((
      meal: Meal.fromJson(rawMeal),
      items: _decodeList<MealItem>(
        element['items'],
        'meal items',
        MealItem.fromJson,
      ),
    ));
  }
  return result;
}

Map<String, String> _decodeSettings(Object? value) {
  if (value == null) {
    return <String, String>{};
  }
  if (value is! Map<String, dynamic>) {
    throw const BackupFormatException('settings must be a JSON object');
  }
  final Map<String, String> result = <String, String>{};
  for (final MapEntry<String, dynamic> entry in value.entries) {
    final Object? settingValue = entry.value;
    if (settingValue is! String) {
      throw const BackupFormatException('settings values must be strings');
    }
    if (backupExcludedSettingsKeys.contains(entry.key)) {
      continue;
    }
    result[entry.key] = settingValue;
  }
  return result;
}
