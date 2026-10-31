/// Local-time calendar windows and day/week rollups.
///
/// The **day key** of a timestamp is the calendar date (y/m/d) it falls on in
/// an explicitly supplied [LocalOffset] — never the UTC date and never the
/// machine's timezone. A **week** is fixed to Monday 00:00 -> Sunday 24:00
/// local (ISO-8601 week start) and is deliberately not configurable. A
/// **month** is the local calendar month, identified by the date-only key of
/// its first day (so a month key looks like `2026-01-01` and its 28..31 day
/// length is derived from the calendar, never stored).
///
/// Determinism: every function here is pure given `(instant, offset)`; the
/// only clock read happens through the injected `package:clock` [Clock] in
/// [currentDayKey], [currentWeekDayKeys] and [rollupWeek]. No function here
/// reads an ambient clock or the process timezone.
library;

import 'package:clock/clock.dart';

import '../../domain/models/daily_exercise.dart';
import '../../domain/models/day_rollup.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/meal_item.dart';
import '../units/nutrition_units.dart';

/// A meal record paired with its [MealItem]s, the unit of work a rollup
/// consumes.
typedef MealWithItems = ({Meal meal, List<MealItem> items});

/// A fixed offset from UTC, in minutes east of Greenwich (`+08:00` = `480`).
///
/// The offset is a constructor argument, not an ambient property, so a test
/// can pin `Asia/Shanghai` on a machine running in any timezone.
final class LocalOffset {
  const LocalOffset(this.minutesEast)
    : assert(
        minutesEast >= -840 && minutesEast <= 840,
        'minutesEast must be within UTC-14:00..UTC+14:00',
      );

  /// UTC (`+00:00`).
  static const LocalOffset utc = LocalOffset(0);

  /// Minutes east of Greenwich; `Asia/Shanghai` is `480`.
  final int minutesEast;

  /// The offset as a [Duration] (`480` -> `8h`).
  Duration get duration => Duration(minutes: minutesEast);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalOffset && other.minutesEast == minutesEast;

  @override
  int get hashCode => minutesEast.hashCode;

  @override
  String toString() => 'LocalOffset($minutesEast min)';
}

/// The local calendar date of [instant] at [offset], as a date-only key.
///
/// The returned [DateTime] is UTC-flagged midnight, so it is a stable,
/// machine-independent key; only its year/month/day are meaningful.
DateTime dayKeyOf(DateTime instant, LocalOffset offset) {
  final shifted = instant.toUtc().add(offset.duration);
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}

/// The local-flagged calendar date of a date-only day key.
///
/// [dayKeyOf] returns a UTC-flagged midnight because that is a stable,
/// machine-independent row key. Widgets that speak the *local* calendar (a
/// Material date picker, for instance) need the same year/month/day as a local
/// [DateTime]:
///
/// ```dart
/// localDateOfKey(DateTime.utc(2026, 9, 21)); // DateTime(2026, 9, 21)
/// ```
DateTime localDateOfKey(DateTime dayKey) =>
    DateTime(dayKey.year, dayKey.month, dayKey.day);

/// The date-only key of the local calendar date [localDate] — the inverse of
/// [localDateOfKey]. The time of day (and the UTC flag) on [localDate] are
/// ignored, so a date-picker result maps straight onto a storage key.
DateTime dayKeyFromLocalDate(DateTime localDate) =>
    DateTime.utc(localDate.year, localDate.month, localDate.day);

/// The date key of the Monday that starts the local week containing [instant].
DateTime mondayKeyOf(DateTime instant, LocalOffset offset) =>
    _mondayOf(dayKeyOf(instant, offset));

/// The seven date keys Monday..Sunday of the local week containing [instant].
List<DateTime> weekDayKeysOf(DateTime instant, LocalOffset offset) {
  final monday = mondayKeyOf(instant, offset);
  return List<DateTime>.generate(
    7,
    (i) => monday.add(Duration(days: i)),
    growable: false,
  );
}

/// Today's date key according to the injected [clock] and [offset].
DateTime currentDayKey({required Clock clock, required LocalOffset offset}) =>
    dayKeyOf(clock.now(), offset);

/// The current Monday..Sunday date keys according to the injected [clock].
List<DateTime> currentWeekDayKeys({
  required Clock clock,
  required LocalOffset offset,
}) => weekDayKeysOf(clock.now(), offset);

/// The date key of the first day of the local calendar month containing
/// [instant].
///
/// Every month helper is keyed the same way — by the month's first day — so a
/// "month key" round-trips through the calendar without storing a day count:
///
/// ```dart
/// monthKeyOf(DateTime.utc(2026, 1, 20), shanghai); // DateTime.utc(2026, 1, 1)
/// ```
DateTime monthKeyOf(DateTime instant, LocalOffset offset) =>
    monthFirstDayKey(dayKeyOf(instant, offset));

/// The date-only first-day key of the calendar month [monthKey] belongs to.
///
/// Any day component on [monthKey] is ignored, so a mid-month date means its
/// month. This is the normaliser every month helper and provider goes through,
/// so a family key such as `2026-01-20` can never produce a window that starts
/// on the 20th while the month's day list starts on the 1st.
DateTime monthFirstDayKey(DateTime monthKey) =>
    DateTime.utc(monthKey.year, monthKey.month);

/// The 28..31 date keys of the local calendar month starting on [monthKey], in
/// calendar order.
///
/// The length comes from [daysInMonth], so February is right on leap years and
/// no caller ever hard-codes 31 (or 30).
List<DateTime> monthDayKeysFor(DateTime monthKey) {
  final key = monthFirstDayKey(monthKey);
  final count = daysInMonth(key);
  return List<DateTime>.generate(
    count,
    (i) => key.add(Duration(days: i)),
    growable: false,
  );
}

/// The date key of the first day of the month [monthsAfter] months after
/// [monthKey]; negative values step into the past.
///
/// Any day component on [monthKey] is ignored (a mid-month date means that
/// month), so callers may pass a day key without normalising it first. The year
/// boundary is handled by the [DateTime] constructor's own month normalisation.
DateTime monthKeyAfter(DateTime monthKey, int monthsAfter) =>
    DateTime.utc(monthKey.year, monthKey.month + monthsAfter);

/// The number of calendar days (28..31) in the month starting on [monthKey].
int daysInMonth(DateTime monthKey) =>
    DateTime.utc(monthKey.year, monthKey.month + 1, 0).day;

/// Sums the meals and exercises that fall on the local calendar day [date].
///
/// [date]'s year/month/day are read as the target local date; the flag and the
/// time of day on it are ignored. Sodium is summed in canonical **mg**: each
/// [MealItem] stores salt grams, so the boundary conversion goes through
/// [saltGToSodiumMg]. Returns a zeroed [DayRollup] when nothing matches, so an
/// empty day is a valid record rather than an error.
///
/// Meals are matched by resolving their instant through [offset]; exercises
/// already carry a date-only [DailyExercise.dayKey], so they are matched with a
/// direct `==` and no offset conversion.
DayRollup rollupDay({
  required DateTime date,
  required Iterable<MealWithItems> meals,
  required Iterable<DailyExercise> exercises,
  required LocalOffset offset,
}) {
  final key = _dateKey(date);
  var intakeKcal = 0;
  var carbG = 0.0;
  var proteinG = 0.0;
  var fatG = 0.0;
  var sodiumMg = 0.0;
  var exerciseKcal = 0;
  var mealCount = 0;

  for (final entry in meals) {
    if (dayKeyOf(entry.meal.timestamp, offset) != key) {
      continue;
    }
    mealCount++;
    for (final item in entry.items) {
      intakeKcal += item.kcal;
      carbG += item.carbG;
      proteinG += item.proteinG;
      fatG += item.fatG;
      sodiumMg += saltGToSodiumMg(item.saltG);
    }
  }

  for (final exercise in exercises) {
    if (exercise.dayKey == key) {
      exerciseKcal += exercise.kcal;
    }
  }

  return DayRollup(
    date: key,
    intakeKcal: intakeKcal,
    carbG: carbG,
    proteinG: proteinG,
    fatG: fatG,
    sodiumMg: sodiumMg,
    exerciseKcal: exerciseKcal,
    mealCount: mealCount,
  );
}

/// The seven [DayRollup]s Monday..Sunday of the week containing `clock.now()`.
///
/// The week window is fixed (Monday start) and cannot be configured; the
/// injected [clock] and [offset] make the result reproducible.
List<DayRollup> rollupWeek({
  required Clock clock,
  required LocalOffset offset,
  required Iterable<MealWithItems> meals,
  required Iterable<DailyExercise> exercises,
}) {
  final monday = mondayKeyOf(clock.now(), offset);
  return List<DayRollup>.generate(
    7,
    (i) => rollupDay(
      date: monday.add(Duration(days: i)),
      meals: meals,
      exercises: exercises,
      offset: offset,
    ),
    growable: false,
  );
}

DateTime _mondayOf(DateTime dateKey) {
  final key = _dateKey(dateKey);
  return key.subtract(Duration(days: key.weekday - DateTime.monday));
}

DateTime _dateKey(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
