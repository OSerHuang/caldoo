/// The Drift half of the versioned JSON backup (task 28): capture the whole
/// local dataset, and restore a decoded snapshot additively.
///
/// This class deliberately knows nothing about `share_plus`; `backup_share.dart`
/// owns the share sheet, and `backup_codec.dart` owns the JSON. That split is
/// what makes the round-trip testable without a platform channel.
///
/// Import policy (per the task):
/// * **additive by id** — only missing rows are written, never overwritten;
/// * on an id collision the EXISTING row wins and the incoming row is counted
///   as skipped in the [ImportSummary];
/// * when a parent meal is skipped, all of its items are skipped too, so no
///   orphaned `meal_items` row can survive its meal (the FK cascade would
///   otherwise reject the insert anyway).
library;

import 'package:clock/clock.dart';

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_food_repository.dart';
import 'package:caldoo/data/repositories/drift_meal_repository.dart';
import 'package:caldoo/data/repositories/drift_meal_template_repository.dart';
import 'package:caldoo/data/repositories/drift_profile_repository.dart';
import 'package:caldoo/data/repositories/mappers.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/models/meal_item.dart';
import 'package:caldoo/domain/models/meal_template.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/models/weight_entry.dart';

import 'backup_codec.dart';
import 'backup_data.dart';

/// Captures and restores a whole-database backup.
class BackupService {
  /// Creates the service over the app database (in tests: an in-memory one).
  ///
  /// [clock] is only used to convert a legacy age-based backup profile into a
  /// birthday on import; tests pin it, production reads the ambient time.
  BackupService(AppDatabase db, {Clock? clock})
    : _db = db,
      _profiles = DriftProfileRepository(db),
      _foods = DriftFoodRepository(db),
      _meals = DriftMealRepository(db),
      _templates = DriftMealTemplateRepository(db),
      _clock = clock ?? const Clock();

  /// A range wide enough to contain any row a personal app could hold, so the
  /// "day/week window" DAOs can be used as a whole-table read. The bounds are
  /// half-open instants, matching the DAO contract.
  static final DateTime _earliest = DateTime.utc(1900);
  static final DateTime _latest = DateTime.utc(2200);

  final AppDatabase _db;
  final Clock _clock;
  final DriftProfileRepository _profiles;
  final DriftFoodRepository _foods;
  final DriftMealRepository _meals;
  final DriftMealTemplateRepository _templates;

  /// Reads the entire local dataset into a [BackupData] snapshot.
  ///
  /// The API key is never read here (it lives in secure storage, not Drift),
  /// and [backupExcludedSettingsKeys] (`notice_seen`) is filtered out.
  Future<BackupData> capture() async {
    final UserProfile? profile = await _profiles.loadProfile();
    final List<Food> foods = await _foods.getAllFoods();

    final List<MealWithItems> meals = await _meals.getMealsWithItemsInRange(
      startInclusive: _earliest,
      endExclusive: _latest,
    );

    final List<DailyExercise> dailyExercises = <DailyExercise>[
      for (final DailyExerciseRow row
          in await _db.select(_db.dailyExercises).get())
        dailyExerciseFromRow(row),
    ];

    final List<WeightEntry> weightEntries = <WeightEntry>[
      for (final WeightEntryRow row
          in await _db.select(_db.weightEntries).get())
        weightEntryFromRow(row),
    ];

    final List<MealTemplate> templates = await _templates.getAllTemplates();

    final Map<String, String> settings = <String, String>{
      for (final AppSetting row in await _db.appSettingsDao.getAll())
        if (!backupExcludedSettingsKeys.contains(row.key)) row.key: row.value,
    };

    return BackupData(
      profile: profile,
      foods: foods,
      meals: meals,
      dailyExercises: dailyExercises,
      weightEntries: weightEntries,
      templates: templates,
      settings: settings,
    );
  }

  /// Captures and serializes the whole dataset to a backup JSON document.
  Future<String> exportToJson() async => encodeBackup(await capture());

  /// Parses [source] (validating its `schemaVersion`) and applies it
  /// additively. Decode failures surface as a failed [Future] (never a
  /// synchronous throw) before the database is touched.
  Future<ImportSummary> importFromJson(String source) async =>
      restore(decodeBackup(source, now: _clock.now()));

  /// Applies [data] to the database in one transaction, existing rows winning.
  Future<ImportSummary> restore(BackupData data) {
    return _db.transaction(() async {
      // --- profile (single row; "collision" == a row already exists) --------
      int profileImported = 0;
      int profileSkipped = 0;
      final UserProfile? incomingProfile = data.profile;
      if (incomingProfile != null) {
        if (await _profiles.loadProfile() == null) {
          await _profiles.saveProfile(incomingProfile);
          profileImported = 1;
        } else {
          profileSkipped = 1;
        }
      }

      // --- foods ------------------------------------------------------------
      int foodsImported = 0;
      int foodsSkipped = 0;
      for (final Food food in data.foods) {
        if (await _foods.getFood(food.id) != null) {
          foodsSkipped++;
        } else {
          await _foods.insertFood(food);
          foodsImported++;
        }
      }

      // --- meals + items ----------------------------------------------------
      int mealsImported = 0;
      int mealsSkipped = 0;
      int mealItemsImported = 0;
      int mealItemsSkipped = 0;

      // Item ids are a global primary key, so a child can collide even when
      // its (new) parent does not. Snapshot the existing ids once.
      final Set<String> existingItemIds = <String>{
        for (final MealItemRow row in await _db.select(_db.mealItems).get())
          row.id,
      };

      for (final MealWithItems group in data.meals) {
        if (await _db.mealDao.getMeal(group.meal.id) != null) {
          // Parent collision: existing meal wins and takes its children with
          // it — no orphaned items are written.
          mealsSkipped++;
          mealItemsSkipped += group.items.length;
          continue;
        }

        final List<MealItem> insertable = <MealItem>[];
        for (final MealItem item in group.items) {
          if (existingItemIds.contains(item.id)) {
            mealItemsSkipped++;
          } else {
            insertable.add(item);
            existingItemIds.add(item.id);
          }
        }

        // The owning meal id comes from the group's meal; a domain [MealItem]
        // carries no mealId.
        await _meals.saveMealWithItems(group.meal, insertable);
        mealsImported++;
        mealItemsImported += insertable.length;
      }

      // --- daily exercises --------------------------------------------------
      int dailyExercisesImported = 0;
      int dailyExercisesSkipped = 0;
      for (final DailyExercise exercise in data.dailyExercises) {
        if (await _db.exerciseDao.getDay(exercise.dayKey) != null) {
          dailyExercisesSkipped++;
        } else {
          await _db.exerciseDao.upsertKcal(
            dayKey: exercise.dayKey,
            kcal: exercise.kcal,
          );
          dailyExercisesImported++;
        }
      }

      // --- weight entries ---------------------------------------------------
      // Same additive-by-day policy as the exercises. The restore deliberately
      // writes the history rows only — it does NOT sync the profile's weight
      // the way DriftWeightRepository.saveWeight does: an import must never
      // quietly move the BMR input the way a user recording a weight does.
      int weightEntriesImported = 0;
      int weightEntriesSkipped = 0;
      for (final WeightEntry entry in data.weightEntries) {
        if (await _db.weightDao.getDay(entry.dayKey) != null) {
          weightEntriesSkipped++;
        } else {
          await _db.weightDao.upsertWeight(
            dayKey: entry.dayKey,
            weightKg: entry.weightKg,
          );
          weightEntriesImported++;
        }
      }

      // --- meal templates ---------------------------------------------------
      // Same additive-by-id policy. A template is a standalone snapshot (no
      // children), so a collision skips exactly one row.
      int templatesImported = 0;
      int templatesSkipped = 0;
      final Set<String> existingTemplateIds = <String>{
        for (final MealTemplate template in await _templates.getAllTemplates())
          template.id,
      };
      for (final MealTemplate template in data.templates) {
        if (existingTemplateIds.contains(template.id)) {
          templatesSkipped++;
        } else {
          await _templates.saveTemplate(template);
          existingTemplateIds.add(template.id);
          templatesImported++;
        }
      }

      // --- settings ---------------------------------------------------------
      int settingsImported = 0;
      int settingsSkipped = 0;
      for (final MapEntry<String, String> entry in data.settings.entries) {
        if (backupExcludedSettingsKeys.contains(entry.key)) {
          continue;
        }
        if (await _db.appSettingsDao.getValue(entry.key) != null) {
          settingsSkipped++;
        } else {
          await _db.appSettingsDao.setValue(entry.key, entry.value);
          settingsImported++;
        }
      }

      return ImportSummary(
        profileImported: profileImported,
        profileSkipped: profileSkipped,
        foodsImported: foodsImported,
        foodsSkipped: foodsSkipped,
        mealsImported: mealsImported,
        mealsSkipped: mealsSkipped,
        mealItemsImported: mealItemsImported,
        mealItemsSkipped: mealItemsSkipped,
        dailyExercisesImported: dailyExercisesImported,
        dailyExercisesSkipped: dailyExercisesSkipped,
        weightEntriesImported: weightEntriesImported,
        weightEntriesSkipped: weightEntriesSkipped,
        templatesImported: templatesImported,
        templatesSkipped: templatesSkipped,
        settingsImported: settingsImported,
        settingsSkipped: settingsSkipped,
      );
    });
  }
}
