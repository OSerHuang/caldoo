/// Riverpod wiring for the one-per-day exercise-burn entry.
///
/// Widgets never touch Drift or a repository implementation directly: they
/// watch the providers below, which project the [DailyExerciseRepository] port
/// from `core/providers/app_providers.dart`. Tests override that port with the
/// in-memory fake, so no database is opened under `flutter test`.
///
/// ## Which day does the form open on?
///
/// Exercise is normally copied off a watch the morning after, so the form opens
/// on **yesterday**. Once yesterday already has a burn there is nothing left to
/// backfill, so the default moves to **today**. The user may still pick any
/// earlier day from the screen's date picker (a future day records nothing and
/// is not offered).
///
/// The daily budget is computed ONLY by the energy engine
/// (`computeEnergyBudget`): the baseline is the resolved BMR (user override or
/// Mifflin-St Jeor) and the day's exercise burn is added on top — exercise is
/// never folded into the baseline here or anywhere else.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';

/// The time seam; production reads the ambient [clock], tests fix it.
final exerciseClockProvider = Provider<Clock>((ref) => clock);

/// The device's current UTC offset as minutes east of Greenwich.
final exerciseOffsetProvider = Provider<LocalOffset>(
  (ref) => LocalOffset(DateTime.now().timeZoneOffset.inMinutes),
);

/// Today's date-only day key (`dayKeyOf(now, offset)`).
final exerciseDayKeyProvider = Provider<DateTime>((ref) {
  final Clock clk = ref.watch(exerciseClockProvider);
  final LocalOffset offset = ref.watch(exerciseOffsetProvider);
  return dayKeyOf(clk.now(), offset);
});

/// Yesterday's date-only day key.
final exerciseYesterdayKeyProvider = Provider<DateTime>(
  (ref) => ref.watch(exerciseDayKeyProvider).subtract(const Duration(days: 1)),
);

/// The day the form opens on: yesterday, or today when yesterday is recorded.
///
/// The "already recorded" test is a synchronous point read of yesterday's row;
/// an unreadable store (a corrupted or unavailable database) falls back to the
/// documented yesterday default instead of blocking the form.
final exerciseDefaultDayProvider = FutureProvider<DateTime>((ref) async {
  final DateTime yesterday = ref.watch(exerciseYesterdayKeyProvider);
  final DateTime today = ref.watch(exerciseDayKeyProvider);
  try {
    final DailyExercise? stored = await ref
        .watch(exerciseRepositoryProvider)
        .getDay(yesterday);
    return stored != null && stored.kcal > 0 ? today : yesterday;
  } catch (_) {
    return yesterday;
  }
});

/// The day currently being edited, as a date-only key.
///
/// `null` while [exerciseDefaultDayProvider] resolves — the form waits for the
/// answer rather than flashing one day and then the other.
final exerciseSelectedDayProvider =
    NotifierProvider<ExerciseSelectedDay, DateTime?>(ExerciseSelectedDay.new);

/// Owns the edited day; re-applies the opening default when the screen enters.
class ExerciseSelectedDay extends Notifier<DateTime?> {
  /// The user's explicit choice, if any. `null` means "still using the default".
  DateTime? _picked;

  @override
  DateTime? build() {
    // Always watch the default: [reset] invalidates it and relies on this
    // dependency to rebuild into the re-resolved day.
    final AsyncValue<DateTime> initial = ref.watch(exerciseDefaultDayProvider);
    final DateTime? picked = _picked;
    if (picked != null) {
      return picked;
    }
    return initial.isLoading ? null : initial.value;
  }

  /// Selects [dayKey] explicitly (date picker or the 昨天/今天 shortcut).
  void select(DateTime dayKey) {
    _picked = dayKey;
    state = dayKey;
  }

  /// Drops the explicit choice and re-reads the opening default.
  ///
  /// The screen calls this on entry, so a burn recorded for yesterday flips the
  /// next visit to today exactly as the default rule describes. The clock is
  /// re-read too: an app kept alive overnight must not keep resolving
  /// "yesterday" against the day before.
  void reset() {
    _picked = null;
    ref.invalidate(exerciseDayKeyProvider);
    ref.invalidate(exerciseDefaultDayProvider);
    state = null;
  }
}

/// The selected day's stored burn, live, tagged with the day it belongs to.
///
/// The tag matters when the selection changes: the previous day's emission can
/// still be visible while the newly selected day's read is in flight, and a
/// consumer must never mistake it for the new day's value.
typedef ExerciseDaySnapshot = ({DateTime day, DailyExercise? exercise});

/// Emits the selected day's row on every write (set or cleared), tagged with
/// the day it belongs to, so the readout and the field stay live.
final exerciseDayProvider = StreamProvider<ExerciseDaySnapshot>((ref) {
  final DateTime? day = ref.watch(exerciseSelectedDayProvider);
  if (day == null) {
    return const Stream<ExerciseDaySnapshot>.empty();
  }
  return ref
      .watch(exerciseRepositoryProvider)
      .watchDay(day)
      .map((DailyExercise? exercise) => (day: day, exercise: exercise));
});
