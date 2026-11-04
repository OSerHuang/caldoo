/// Energy engine: a basal metabolic rate (Mifflin-St Jeor, user-overridable),
/// an optional user-set daily goal, an exercise-free daily baseline and an
/// explicit exercise add-back.
///
/// ## The baseline is the goal when one is set, else the BMR
///
/// The profile stores the anthropometrics the estimate needs
/// ([UserProfile.sex], `.birthDate`, `.heightCm`, `.weightKg`), an optional
/// [UserProfile.bmrKcalOverride] and an optional daily goal. Age is derived
/// from the birthday on a caller-supplied `today` ([UserProfile.ageOn]), so
/// there is no stored age to update every year. The daily baseline is the
/// user's goal when set and the resolved BMR otherwise; logged exercise is
/// **added on top** of it:
///
/// ```text
/// goal       = preset ? resolveBmrKcal(profile) + preset.deltaKcal
///                    : dailyKcalGoalOverride            // either, never both
/// baseBudget = goal ?? resolveBmrKcal(profile)          // goal wins, else BMR
/// budget     = baseBudget + exerciseKcal                // exercise added back
/// ```
///
/// There is deliberately **no activity multiplier and no hidden factor**: the
/// goal is either an explicit number the user typed (a **fixed** custom goal,
/// unaffected by later weight changes) or a [DailyGoalPreset] expressed
/// RELATIVE to the resolved BMR. The preset is re-derived on every read, so a
/// body-weight change flows through the anthropometrics → BMR → goal and the
/// daily budget follows it. Exercise stays a separate add-back that can never
/// be double-counted.
///
/// ## Every energy number is a whole kcal integer
///
/// BMR, budget, intake, exercise, surplus and deficit are all `int` kcal (see
/// `lib/core/units/nutrition_units.dart`): the Mifflin-St Jeor result is
/// rounded once, when it enters the domain, so no fraction ever reaches a day
/// total or the UI.
///
/// ## Sign convention (named explicitly, never implied)
///
/// * `energyBalanceKcal = intakeKcal - budgetKcal`
///   — **positive = surplus (盈余)**, negative = deficit.
/// * `deficitKcal = budgetKcal - intakeKcal`
///   — **positive = deficit (缺口)**, negative = surplus.
///
/// The two are exact negatives of each other. A variable called `deficit` must
/// never hold `intake - budget`.
library;

import 'package:caldoo/core/units/nutrition_units.dart' show roundKcal;
import 'package:caldoo/domain/models/user_profile.dart';

/// Outcome of [computeEnergyBudget]: either a full [EnergyBudget] or a typed
/// [ProfileIncomplete] refusal — the engine never invents numbers for a
/// missing profile.
sealed class EnergyBudgetResult {
  const EnergyBudgetResult();
}

/// The profile is missing (`null`): the engine refuses to guess and returns
/// this typed result instead of a wrong number.
final class ProfileIncomplete extends EnergyBudgetResult {
  const ProfileIncomplete();

  @override
  String toString() =>
      'ProfileIncomplete: a complete UserProfile is required to compute '
      'BMR / budget';
}

/// A complete energy budget for one day, with the sign convention made
/// explicit in the field names.
final class EnergyBudget extends EnergyBudgetResult {
  const EnergyBudget({
    required this.bmrKcal,
    required this.goalKcal,
    required this.baseBudgetKcal,
    required this.exerciseKcal,
    required this.budgetKcal,
    required this.intakeKcal,
  });

  /// Resolved basal metabolic rate, whole kcal/day: the user's override when
  /// set, otherwise the rounded Mifflin-St Jeor estimate.
  final int bmrKcal;

  /// The user's daily energy goal in whole kcal/day, or `null` when no goal is
  /// set (the budget then means "maintain": the resolved BMR).
  final int? goalKcal;

  /// Exercise-free daily baseline: the user's goal when one is set, otherwise
  /// exactly [bmrKcal]. Exercise is added on top in [budgetKcal].
  final int baseBudgetKcal;

  /// Logged exercise energy for the day, whole kcal — added back on top of
  /// [baseBudgetKcal], never folded into the baseline.
  final int exerciseKcal;

  /// Total daily budget: `baseBudgetKcal + exerciseKcal`.
  final int budgetKcal;

  /// Energy eaten today, whole kcal.
  final int intakeKcal;

  /// **`intakeKcal - budgetKcal`**.
  ///
  /// Positive = surplus (盈余); negative = deficit (缺口). This is NOT the
  /// deficit — see [deficitKcal].
  int get energyBalanceKcal => intakeKcal - budgetKcal;

  /// **`budgetKcal - intakeKcal`**.
  ///
  /// Positive = deficit (缺口); negative = surplus (盈余). This is NOT
  /// `intake - budget`.
  int get deficitKcal => budgetKcal - intakeKcal;

  /// True when today ends in a surplus (盈余): [energyBalanceKcal] > 0.
  bool get isSurplus => energyBalanceKcal > 0;

  /// True when today ends in a deficit (缺口): [deficitKcal] > 0.
  bool get isDeficit => deficitKcal > 0;

  @override
  String toString() =>
      'EnergyBudget(bmr: $bmrKcal, goal: $goalKcal, base: $baseBudgetKcal, '
      'exercise: $exerciseKcal, budget: $budgetKcal, intake: $intakeKcal, '
      'energyBalance: $energyBalanceKcal, deficit: $deficitKcal)';
}

/// Mifflin-St Jeor basal metabolic rate in whole kcal/day (Mifflin et al.,
/// 1990).
///
/// * men: `10*w + 6.25*h - 5*a + 5`
/// * women: `10*w + 6.25*h - 5*a - 161`
///
/// [weightKg] in kilograms, [heightCm] in centimetres, [age] in whole years.
/// The formula's fractional result is rounded once with [roundKcal], because
/// energy is integer-only. Non-positive or non-finite anthropometrics throw an
/// [ArgumentError].
int mifflinStJeorBmr({
  required Sex sex,
  required int age,
  required double heightCm,
  required double weightKg,
}) {
  _checkPositive(age.toDouble(), 'age');
  _checkPositive(heightCm, 'heightCm');
  _checkPositive(weightKg, 'weightKg');
  final double resting = 10 * weightKg + 6.25 * heightCm - 5 * age;
  final double estimate = switch (sex) {
    Sex.male => resting + 5,
    Sex.female => resting - 161,
  };
  return roundKcal(estimate);
}

/// Resolves the profile's basal metabolic rate in whole kcal/day on [today].
///
/// A user-set [UserProfile.bmrKcalOverride] wins over the estimate; when it is
/// `null` the Mifflin-St Jeor equation is computed from the anthropometrics,
/// with the age derived from [UserProfile.birthDate] via
/// [UserProfile.ageOn]. A non-positive override throws an [ArgumentError] —
/// the engine never lets a malformed number poison a day total.
int resolveBmrKcal(UserProfile profile, {required DateTime today}) {
  final int? override = profile.bmrKcalOverride;
  if (override != null) {
    if (override <= 0) {
      throw ArgumentError.value(
        override,
        'bmrKcalOverride',
        'must be positive',
      );
    }
    return override;
  }
  return mifflinStJeorBmr(
    sex: profile.sex,
    age: profile.ageOn(today),
    heightCm: profile.heightCm,
    weightKg: profile.weightKg,
  );
}

/// Resolves the profile's daily energy goal in whole kcal/day, or `null` when
/// no goal is set.
///
/// Two mutually exclusive goals exist:
///
/// * [UserProfile.dailyGoalPreset] — a deficit/surplus RELATIVE to [bmrKcal],
///   so `bmrKcal + preset.deltaKcal`. Re-derived on every call, which is what
///   makes a preset follow the body weight.
/// * [UserProfile.dailyKcalGoalOverride] — a fixed absolute number the user
///   typed, returned verbatim.
///
/// [bmrKcal] must be the resolved BMR for the same profile ([resolveBmrKcal]).
/// A profile that carries both is malformed (the goal sheet never writes both)
/// and throws an [ArgumentError]; so does a goal that resolves to zero or less
/// — the engine never lets a malformed number poison a day total.
int? resolveDailyGoalKcal(UserProfile profile, {required int bmrKcal}) {
  final DailyGoalPreset? preset = profile.dailyGoalPreset;
  final int? override = profile.dailyKcalGoalOverride;
  if (preset != null && override != null) {
    throw ArgumentError(
      'dailyKcalGoalOverride and dailyGoalPreset are mutually exclusive: '
      'the daily goal is either a fixed number or a BMR-relative preset',
    );
  }
  if (preset != null) {
    final int goal = bmrKcal + preset.deltaKcal;
    if (goal <= 0) {
      throw ArgumentError.value(
        goal,
        'dailyGoalPreset',
        'must resolve to a positive goal (BMR $bmrKcal '
            '${preset.deltaKcal >= 0 ? '+' : '−'} ${preset.deltaKcal.abs()})',
      );
    }
    return goal;
  }
  if (override != null && override <= 0) {
    throw ArgumentError.value(
      override,
      'dailyKcalGoalOverride',
      'must be positive',
    );
  }
  return override;
}

/// Computes the full daily energy budget for [profile] on [today].
///
/// `budgetKcal = (goal ?? resolveBmrKcal(profile, today: today)) +
/// exerciseKcal` — [exerciseKcal] is an **input** (the caller supplies the
/// day's exercise burn); the engine never derives it and never folds it into
/// the baseline. The goal is read from the profile
/// ([UserProfile.dailyGoalPreset] first, then
/// [UserProfile.dailyKcalGoalOverride]): `null` keeps the "maintain" budget
/// (the resolved BMR). A preset therefore tracks the weight, while a custom
/// goal stays where the user put it. [today] is also the reference date the
/// profile's age is derived on, so a birthday can never go stale.
///
/// Returns [ProfileIncomplete] when [profile] is `null`. Negative
/// [intakeKcal] / [exerciseKcal] throw an [ArgumentError] rather than poisoning
/// a day total.
EnergyBudgetResult computeEnergyBudget({
  required UserProfile? profile,
  required int intakeKcal,
  int exerciseKcal = 0,
  required DateTime today,
}) {
  _checkNonNegative(intakeKcal, 'intakeKcal');
  _checkNonNegative(exerciseKcal, 'exerciseKcal');
  if (profile == null) {
    return const ProfileIncomplete();
  }
  final int bmr = resolveBmrKcal(profile, today: today);
  final int? goal = resolveDailyGoalKcal(profile, bmrKcal: bmr);
  return EnergyBudget(
    bmrKcal: bmr,
    goalKcal: goal,
    baseBudgetKcal: goal ?? bmr,
    exerciseKcal: exerciseKcal,
    budgetKcal: (goal ?? bmr) + exerciseKcal,
    intakeKcal: intakeKcal,
  );
}

/// Rejects negative values with an [ArgumentError].
void _checkNonNegative(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must not be negative');
  }
}

/// Rejects zero, negative, NaN and infinite values with an [ArgumentError].
void _checkPositive(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      name,
      'must be a finite number (got NaN or infinity)',
    );
  }
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive');
  }
}
