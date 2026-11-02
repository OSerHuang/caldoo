/// Period-neutral value layer for the dashboard summaries (a week, a month).
///
/// A **period** is any calendar-contiguous, ordered list of local
/// [DayRollup]s: seven for a Mon..Sun week, 28..31 for a calendar month. The
/// merge of 汇总 into 概览 is what made the layer period-neutral: the week and
/// month views are the same dashboard at different zoom levels, so they must
/// share the metric definitions here, in exactly one place, and can never
/// drift:
///
/// * **logged day** — a [DayRollup] with `mealCount >= 1` (at least one MEAL).
///   An exercise-only day is **not** logged.
/// * **total intake** — the sum of the logged days' intake kcal: the period's
///   running food energy.
/// * **total burn** — the sum of the logged days' expenditure
///   (`bmr + exercise`): the resolved BMR with each logged day's exercise
///   added on top, the same number the chart's burn bars and the dashed
///   基础代谢 target line are drawn at. The user's goal is deliberately NOT
///   part of the burn — a goal is a diet target, not expended energy — so it
///   can never drift from the chart when the two differ.
/// * **difference** — `total intake - total burn`. Negative = 缺口 (deficit),
///   positive = 盈余 (surplus), exactly the task-7 sign convention. It is the
///   physiological balance (intake vs BMR + exercise), NOT the daily
///   dashboard's 缺口(相对额度); goal adherence is the separate 热量达标
///   metric below.
///
/// These are **cumulative totals for the period so far, never averages**; only
/// the logged days contribute, so an exercise-only day adds nothing (matching
/// its empty bar in the chart).
///
/// * **salt adherence** — `adherentDays / loggedDays`, where an adherent day is
///   a logged day whose sodium total is `<=` the WHO 2000 mg ceiling.
/// * **target line** — the profile's resolved basal metabolic rate (the user's
///   own BMR override, or the Mifflin-St Jeor estimate — **excluding**
///   exercise, and regardless of any set goal). A single flat line cannot
///   represent the per-day exercise-varying budgets, so the line is
///   deliberately the exercise-free baseline; the week/month dashboards label
///   it distinctly from the daily dashboard's `今日额度(含运动)`.
/// * **weight change** — the signed delta between the period's last and first
///   weight entries (see [periodWeightDeltaKg]); `null` with fewer than two
///   in-period entries, and profile-independent like the salt adherence.
///
/// The balance/budget numbers come ONLY from the energy engine
/// ([computeEnergyBudget]); this file never re-derives BMR or the budget.
library;

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/models/weight_entry.dart';

/// WHO daily sodium ceiling in mg, derived from the canonical
/// [dailySaltTargetG] (`5 g salt == 2000 mg Na`) so the two can never diverge.
final double dailySodiumTargetMg = saltGToSodiumMg(dailySaltTargetG);

/// The signed body-weight change over a period: the LAST entry in the
/// (already period-bounded, day-ordered) list minus the FIRST.
///
/// `null` with fewer than two entries — a single data point has no direction,
/// and a "0.0" from one recording would read as a measured fact.
double? periodWeightDeltaKg(List<WeightEntry> entries) =>
    entries.length < 2 ? null : entries.last.weightKg - entries.first.weightKg;

/// One period's running (cumulative) totals.
final class PeriodSummary {
  /// Creates a period summary from already-computed metrics.
  const PeriodSummary({
    required this.days,
    required this.bmrKcal,
    required this.loggedDays,
    required this.adherentDays,
    required this.totalIntakeKcal,
    required this.totalBurnKcal,
    required this.totalBalanceKcal,
    this.goalKcal,
    this.goalAdherentDays = 0,
    this.weightEntries = const <WeightEntry>[],
  });

  /// One rollup per day of the period, in calendar order (seven for a week,
  /// 28..31 for a month — the chart plots these in order).
  final List<DayRollup> days;

  /// The resolved basal metabolic rate (the user's BMR override, or the
  /// Mifflin-St Jeor estimate) in **whole kcal**, drawn as the dashed target
  /// line and used as the base of the burn bars and the burn totals. The
  /// user's goal — however much it differs from the BMR — is deliberately NOT
  /// this number: a goal is a diet target, not expended energy. Never `null`:
  /// a [PeriodSummary] only exists for a complete profile.
  final int bmrKcal;

  /// The user's daily energy goal in whole kcal/day, or `null` when no goal is
  /// set (no goal-adherence is reported then). It feeds ONLY the 热量达标
  /// metric — never the burn bars, the target line or the burn totals.
  final int? goalKcal;

  /// How many logged days stayed at or under [goalKcal]. Only meaningful when
  /// [goalKcal] is non-null; `0` otherwise.
  final int goalAdherentDays;

  /// The period's body-weight entries, day-ordered (already bounded to the
  /// period window by the providers). Profile-independent; feeds the 体重
  /// line block and its signed-change header.
  final List<WeightEntry> weightEntries;

  /// The signed body-weight change over the period (last entry minus first),
  /// or `null` with fewer than two in-period entries.
  double? get weightDeltaKg => periodWeightDeltaKg(weightEntries);

  /// How many days of the period logged at least one meal
  /// (`mealCount >= 1`).
  final int loggedDays;

  /// How many logged days stayed at or under [dailySodiumTargetMg].
  final int adherentDays;

  /// Sum of the logged days' intake kcal — the period's running intake.
  final int totalIntakeKcal;

  /// Sum of the logged days' expenditure (`bmrKcal + exercise`) — the period's
  /// running burn. Exercise on a logged day is included; an exercise-only day
  /// is not.
  final int totalBurnKcal;

  /// `totalIntakeKcal - totalBurnKcal` over the logged days.
  ///
  /// Positive = 盈余, negative = 缺口 — exactly the task-7 sign convention.
  final int totalBalanceKcal;

  /// `adherentDays / loggedDays` (0 when there are no logged days).
  double get saltAdherence => loggedDays == 0 ? 0 : adherentDays / loggedDays;

  /// `goalAdherentDays / loggedDays` (0 when there are no logged days or no
  /// goal).
  double get goalAdherence =>
      loggedDays == 0 || goalKcal == null ? 0 : goalAdherentDays / loggedDays;

  /// `true` when the day at [index] (in calendar order) logged at least one
  /// meal.
  bool isLogged(int index) => days[index].mealCount >= 1;
}

/// The period dashboard's sealed view state.
sealed class PeriodSummaryState {
  const PeriodSummaryState();
}

/// One or more live inputs are still loading; the dashboard shows a spinner
/// rather than a guessed number.
final class PeriodSummaryLoading extends PeriodSummaryState {
  /// Creates the loading state.
  const PeriodSummaryLoading();
}

/// No day in the period logged a meal: the chart has nothing to plot, so the
/// dashboard shows an empty state instead of an all-zero (or
/// division-by-zero) summary.
final class PeriodSummaryEmpty extends PeriodSummaryState {
  /// Creates the empty state for the period's [days] (all unlogged).
  const PeriodSummaryEmpty(this.days);

  /// The period's (all unlogged) rollups, in calendar order.
  final List<DayRollup> days;
}

/// The period has logged data but no complete profile exists.
///
/// The target line, total burn and the difference are **hidden** (none can be
/// computed without a budget) and replaced by a "完善资料" prompt. Total intake,
/// logged days and salt adherence do not need the profile and are carried here,
/// computed with the exact same rules as [PeriodSummary].
final class PeriodSummaryNoProfile extends PeriodSummaryState {
  /// Creates the incomplete-profile state.
  const PeriodSummaryNoProfile({
    required this.days,
    required this.loggedDays,
    required this.adherentDays,
    required this.totalIntakeKcal,
    this.weightEntries = const <WeightEntry>[],
  });

  /// The period's rollups, in calendar order.
  final List<DayRollup> days;

  /// How many days logged at least one meal.
  final int loggedDays;

  /// How many logged days stayed at or under [dailySodiumTargetMg].
  final int adherentDays;

  /// Sum of the logged days' intake kcal — the period's running intake.
  final int totalIntakeKcal;

  /// The period's body-weight entries (does not need the profile).
  final List<WeightEntry> weightEntries;

  /// The signed body-weight change over the period, or `null` with fewer than
  /// two in-period entries.
  double? get weightDeltaKg => periodWeightDeltaKg(weightEntries);

  /// `adherentDays / loggedDays`.
  double get saltAdherence => loggedDays == 0 ? 0 : adherentDays / loggedDays;
}

/// A complete period summary.
final class PeriodSummaryReady extends PeriodSummaryState {
  /// Creates the ready state.
  const PeriodSummaryReady(this.summary);

  /// The computed metrics.
  final PeriodSummary summary;
}

/// Builds the [PeriodSummaryState] from the period's day rollups and the
/// profile.
///
/// Precedence: loading is handled by the provider; then **empty** (no logged
/// days) wins over no-profile so a blank period is a blank period regardless of
/// the profile; then no-profile; then the full summary. [days] may be shorter
/// than a full period (or empty) — anything without a logged day is empty,
/// never a crash.
///
/// The totals are summed over the LOGGED days only (the same set the chart
/// plots), so an exercise-only day never contributes to the period's running
/// numbers. [today] is forwarded unchanged to the energy engine, which derives
/// the profile's age from it. [weightEntries] must already be bounded to the
/// period window and ordered by day (the providers slice them with the same
/// date-only keys the meals/exercises use); the delta is profile-independent,
/// so it shows with and without a complete profile.
PeriodSummaryState buildPeriodSummary({
  required List<DayRollup> days,
  required UserProfile? profile,
  required DateTime today,
  List<WeightEntry> weightEntries = const <WeightEntry>[],
}) {
  final List<DayRollup> logged = <DayRollup>[
    for (final day in days)
      if (day.mealCount >= 1) day,
  ];
  if (logged.isEmpty) {
    return PeriodSummaryEmpty(days);
  }

  // Profile-independent metrics first: a missing profile must not hide the
  // intake/day/adherence numbers.
  var intakeSum = 0;
  var adherent = 0;
  for (final day in logged) {
    intakeSum += day.intakeKcal;
    if (day.sodiumMg <= dailySodiumTargetMg) {
      adherent++;
    }
  }
  final int n = logged.length;

  if (profile == null) {
    return PeriodSummaryNoProfile(
      days: days,
      loggedDays: n,
      adherentDays: adherent,
      totalIntakeKcal: intakeSum,
      weightEntries: weightEntries,
    );
  }

  // The goal-adherence count is profile-dependent (a goal IS profile state),
  // so it is computed here where the engine's inputs are already resolved.
  final int? goal = resolveDailyGoalKcal(profile);
  var goalAdherent = 0;
  if (goal != null) {
    for (final day in logged) {
      if (day.intakeKcal <= goal) {
        goalAdherent++;
      }
    }
  }

  final EnergyBudget base = _requireBudget(
    computeEnergyBudget(profile: profile, intakeKcal: 0, today: today),
  );
  // The period's burn is the physiological expenditure — the resolved BMR
  // plus each logged day's exercise — exactly what the chart's burn bars, the
  // dashed 基础代谢 target line and the tooltip report. The user's goal is
  // deliberately NOT part of it: a goal is a diet target, not expended
  // energy, so folding it into the burn would make 摄入 vs 消耗 read as
  // diet adherence. The goal feeds ONLY the 热量达标 count above.
  final int bmr = base.bmrKcal;
  var burnSum = 0;
  var balanceSum = 0;
  for (final day in logged) {
    final int burn = bmr + day.exerciseKcal;
    burnSum += burn;
    balanceSum += day.intakeKcal - burn;
  }
  return PeriodSummaryReady(
    PeriodSummary(
      days: days,
      bmrKcal: bmr,
      goalKcal: goal,
      goalAdherentDays: goalAdherent,
      weightEntries: weightEntries,
      loggedDays: n,
      adherentDays: adherent,
      totalIntakeKcal: intakeSum,
      totalBurnKcal: burnSum,
      totalBalanceKcal: balanceSum,
    ),
  );
}

/// Unwraps the engine result; a non-null profile can never be incomplete.
EnergyBudget _requireBudget(EnergyBudgetResult result) => switch (result) {
  final EnergyBudget budget => budget,
  ProfileIncomplete() => throw StateError(
    'computeEnergyBudget returned ProfileIncomplete for a non-null profile',
  ),
};
