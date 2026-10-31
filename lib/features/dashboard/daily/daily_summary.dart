/// Value layer for the daily summary dashboard (task 24).
///
/// The dashboard never invents a budget and never re-derives the balance: the
/// numbers come from the task-9 day rollup (`DayRollup`) and the task-7 energy
/// engine (`EnergyBudget`). This file owns exactly two things the widget needs:
///
/// * [SignedBalance] — the sign convention as a single, testable projection.
///   **缺口** is always `EnergyBudget.deficitKcal` (`budget - intake`, positive
///   when short) and **盈余** is always `EnergyBudget.energyBalanceKcal`
///   (`intake - budget`, positive when over). `intake - budget` is never
///   displayed under the 缺口 label.
/// * [DailySummaryState] — the sealed view state, so "profile incomplete"
///   (budget hidden, no deficit shown) is a typed case rather than a sentinel.
library;

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Which way the day's energy balance leans.
enum BalanceKind { deficit, surplus, balanced }

/// The signed balance exactly as the dashboard must present it.
///
/// Label and value are produced together so they can never drift apart:
/// a swap of the two engine fields would fail the unit tests directly instead
/// of only being visible in the UI.
final class SignedBalance {
  /// Creates a signed balance from an explicit label / value / kind.
  const SignedBalance({
    required this.label,
    required this.valueKcal,
    required this.kind,
  });

  /// Projects the engine's [EnergyBudget] per the task-7 sign convention.
  ///
  /// * deficit (缺口): [EnergyBudget.deficitKcal] > 0 -> positive number;
  /// * surplus (盈余): [EnergyBudget.energyBalanceKcal] > 0 -> positive number;
  /// * otherwise the day is exactly on budget (平衡, zero).
  factory SignedBalance.fromBudget(EnergyBudget budget) {
    if (budget.isDeficit) {
      return SignedBalance(
        label: S.instance.balanceDeficit,
        valueKcal: budget.deficitKcal,
        kind: BalanceKind.deficit,
      );
    }
    if (budget.isSurplus) {
      return SignedBalance(
        label: S.instance.balanceSurplus,
        valueKcal: budget.energyBalanceKcal,
        kind: BalanceKind.surplus,
      );
    }
    return SignedBalance(
      label: S.instance.balanceBalanced,
      valueKcal: 0,
      kind: BalanceKind.balanced,
    );
  }

  /// The zh-CN label: 缺口 / 盈余 / 平衡.
  final String label;

  /// The value in **whole kcal**, always positive for a non-zero balance.
  final int valueKcal;

  /// The direction, for colour selection.
  final BalanceKind kind;
}

/// The daily dashboard's sealed view state.
sealed class DailySummaryState {
  const DailySummaryState();
}

/// One or more live inputs are still loading; the dashboard shows a spinner
/// rather than a guessed number.
final class DailySummaryLoading extends DailySummaryState {
  /// Creates the loading state.
  const DailySummaryLoading();
}

/// Totals are known but no complete profile exists.
///
/// The budget and the signed balance are **hidden** (a deficit must never be
/// shown without a budget) and replaced by a "完善资料" prompt. Intake, macros,
/// salt and exercise are still shown because they do not depend on the profile.
final class DailySummaryNoProfile extends DailySummaryState {
  /// Creates the incomplete-profile state for the day's [rollup].
  const DailySummaryNoProfile(this.rollup);

  /// The day's rolled-up totals.
  final DayRollup rollup;
}

/// A complete summary: the day's rollup plus the engine's budget.
final class DailySummaryReady extends DailySummaryState {
  /// Creates the ready state.
  const DailySummaryReady({required this.rollup, required this.budget});

  /// The day's rolled-up totals.
  final DayRollup rollup;

  /// The budget from the task-7 engine, with exercise added back.
  final EnergyBudget budget;
}

/// Formats a daily macro / salt metric for display, dropping a trailing `.0`
/// (`300.0 -> "300"`, `74.25 -> "74.25"`).
///
/// Energy values never use this: every kcal number is an `int` and is rendered
/// with `AppFormat.integer` / `AppFormat.number` directly.
String formatDailyNumber(double value) => AppFormat.number(value);
