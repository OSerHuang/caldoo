/// Riverpod wiring for the one-per-day exercise-burn entry.
///
/// Widgets never touch Drift or a repository implementation directly: they
/// watch the providers below, which project the [DailyExerciseRepository] port
/// from `core/providers/app_providers.dart`. Tests override that port with the
/// in-memory fake, so no database is opened under `flutter test`.
///
/// ## Which day does the form edit?
///
/// The day the 概览 day page was showing when its quick-add was tapped: the
/// route pushes that date-only day key and the screen edits exactly it. A deep
/// link without a day falls back to today. Any earlier day remains reachable
/// from the screen's date picker (a future day records nothing and is not
/// offered).
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
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';

/// The time seam; production reads the ambient [clock], tests fix it.
final exerciseClockProvider = Provider<Clock>((ref) => clock);

/// The device's current UTC offset as minutes east of Greenwich.
///
/// Re-read on every [dayTickProvider] signal, like every other offset seam:
/// a plain `Provider` caches for the whole process lifetime, so without the
/// watch a timezone change while the app is alive (travel, DST) kept the
/// launch offset forever and [exerciseDayKeyProvider] re-derived its key with
/// the stale zone.
final exerciseOffsetProvider = Provider<LocalOffset>((ref) {
  ref.watch(dayTickProvider);
  return LocalOffset(DateTime.now().timeZoneOffset.inMinutes);
});

/// Today's date-only day key (`dayKeyOf(now, offset)`).
///
/// Re-derived on every [dayTickProvider] signal (app resume, the minute poll),
/// like the other current-day seams: an app left open across midnight must not
/// keep offering the launch day to the date picker or the no-day deep link.
final exerciseDayKeyProvider = Provider<DateTime>((ref) {
  ref.watch(dayTickProvider);
  final Clock clk = ref.watch(exerciseClockProvider);
  final LocalOffset offset = ref.watch(exerciseOffsetProvider);
  return dayKeyOf(clk.now(), offset);
});

/// The day currently being edited, as a date-only key.
///
/// The screen selects the day explicitly on entry (the pushed day, or today
/// for a deep link without one), so this is `null` only in the first frame
/// before that selection lands — the form waits rather than flashing a day.
final exerciseSelectedDayProvider =
    NotifierProvider<ExerciseSelectedDay, DateTime?>(ExerciseSelectedDay.new);

/// Owns the edited day; the screen selects it explicitly on every entry.
class ExerciseSelectedDay extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Selects [dayKey] as the day being edited (screen entry or date picker).
  void select(DateTime dayKey) => state = dayKey;
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
