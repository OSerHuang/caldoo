/// Riverpod controller for the one-per-day exercise-burn entry.
///
/// Owns the editable kcal value and the persistence call against the
/// [DailyExerciseRepository] port. Nothing here touches Drift: the port comes
/// from `core/providers/app_providers.dart`, so tests override it with the
/// in-memory fake.
///
/// The row written is the one for the **selected** day
/// ([exerciseSelectedDayProvider]) — the screen may be backfilling yesterday
/// rather than editing today, so no call here assumes `today`.
///
/// ## Documented input handling
///
/// * [setKcal] rejects negative, `NaN` and infinite values with an
///   [ArgumentError] (fail-fast). The widget additionally ignores unparseable
///   text so a stray character cannot crash the form.
/// * [save] refuses a missing or non-positive value with a clear message: a
///   zero burn is not a loggable exercise. Use [clear] to remove the day.
/// * [clear] deletes the selected day's row (a `<= 0` upsert is a delete by
///   contract).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/repositories/daily_exercise_repository.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'exercise_providers.dart';

/// Immutable view state of the exercise-burn form.
class ExerciseEntryState {
  const ExerciseEntryState({
    this.day,
    this.kcal,
    this.loaded = false,
    this.loadFailed = false,
    this.saving = false,
    this.error,
  });

  /// The date-only key of the day being edited; `null` while the opening
  /// default resolves.
  final DateTime? day;

  /// The editable burn in **whole kcal**; `null` while the field is blank.
  final int? kcal;

  /// `true` once [day]'s stored burn has been read, so [kcal] reflects storage
  /// rather than "not read yet".
  final bool loaded;

  /// `true` when reading [day]'s stored burn failed.
  final bool loadFailed;

  /// `true` while a save/clear is in flight.
  final bool saving;

  /// Human-readable validation/failure message, or `null`.
  final String? error;

  /// `true` when there is a positive value to save.
  bool get hasValue => kcal != null && kcal! > 0;

  /// `true` when the form has a day and its stored value: it may be edited.
  bool get ready => day != null && loaded;

  @override
  String toString() =>
      'ExerciseEntryState(day: $day, kcal: $kcal, loaded: $loaded, '
      'loadFailed: $loadFailed, saving: $saving, error: $error)';
}

/// Drives the exercise-burn form and its repository writes.
class ExerciseEntryController extends Notifier<ExerciseEntryState> {
  @override
  ExerciseEntryState build() {
    final DateTime? day = ref.watch(exerciseSelectedDayProvider);
    if (day == null) {
      return const ExerciseEntryState();
    }
    // Re-derive from the selected day's live stream so an external change (or a
    // save) is reflected immediately, and a day switch re-seeds the field.
    final AsyncValue<ExerciseDaySnapshot> stored = ref.watch(
      exerciseDayProvider,
    );
    final ExerciseDaySnapshot? snapshot = stored.value;
    if (snapshot == null || snapshot.day != day) {
      return ExerciseEntryState(
        day: day,
        loadFailed: stored.hasError && !stored.hasValue,
      );
    }
    return ExerciseEntryState(
      day: day,
      kcal: snapshot.exercise?.kcal,
      loaded: true,
    );
  }

  /// Sets the editable burn, or clears the field when [kcal] is `null`.
  ///
  /// Energy is integer-only, so a fractional value can never be stored.
  /// Negative values are rejected with an [ArgumentError].
  void setKcal(int? kcal) {
    final DateTime? day = state.day;
    final bool loaded = state.loaded;
    if (kcal == null) {
      state = ExerciseEntryState(day: day, loaded: loaded);
      return;
    }
    if (kcal < 0) {
      throw ArgumentError.value(kcal, 'kcal', 'must not be negative');
    }
    state = ExerciseEntryState(day: day, kcal: kcal, loaded: loaded);
  }

  /// Validates and persists the selected day's burn.
  ///
  /// Returns `true` on success. Refuses a missing/non-positive value through
  /// [ExerciseEntryState.error].
  Future<bool> save() async {
    if (state.saving) {
      return false;
    }
    final DateTime? day = state.day;
    final int? kcal = state.kcal;
    if (day == null) {
      return false;
    }
    if (kcal == null || kcal <= 0) {
      state = ExerciseEntryState(
        day: day,
        kcal: kcal,
        loaded: state.loaded,
        error: S.instance.errorExerciseKcalPositive,
      );
      return false;
    }

    state = ExerciseEntryState(day: day, kcal: kcal, saving: true);
    try {
      final DailyExerciseRepository exercises = ref.read(
        exerciseRepositoryProvider,
      );
      await exercises.setKcal(dayKey: day, kcal: kcal);
    } catch (_) {
      state = ExerciseEntryState(
        day: day,
        kcal: kcal,
        loaded: state.loaded,
        error: S.instance.errorSaveFailed,
      );
      return false;
    }
    state = ExerciseEntryState(day: day, kcal: kcal, loaded: true);
    return true;
  }

  /// Clears the selected day's burn (deletes that day's row).
  Future<void> clear() async {
    final DateTime? day = state.day;
    if (day == null) {
      return;
    }
    final int? kcal = state.kcal;
    try {
      await ref.read(exerciseRepositoryProvider).setKcal(dayKey: day, kcal: 0);
    } catch (_) {
      state = ExerciseEntryState(
        day: day,
        kcal: kcal,
        loaded: state.loaded,
        error: S.instance.errorSaveFailed,
      );
      return;
    }
    state = ExerciseEntryState(day: day, loaded: true);
  }
}

/// The exercise-burn controller.
final exerciseEntryControllerProvider =
    NotifierProvider<ExerciseEntryController, ExerciseEntryState>(
      ExerciseEntryController.new,
    );
