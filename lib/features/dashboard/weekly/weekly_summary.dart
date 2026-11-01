/// The weekly dashboard's value layer, kept as a thin facade over the
/// period-neutral [PeriodSummary] (see `../period/period_summary.dart`).
///
/// The week and the month are the same dashboard at two zoom levels after the
/// 汇总 tab merged into 概览, so both are built by the one [buildPeriodSummary]
/// function and share the metric definitions. This file exists for the **week's
/// own vocabulary**: the weekly view, its widget tests and the week pager were
/// written against `Weekly*` names, and a `week`-shaped `buildWeeklySummary`
/// entry point reads better at those call sites than a raw list of days.
///
/// The type aliases are exact aliases (not subclasses), so a [WeeklySummary] is
/// a [PeriodSummary] and a [WeeklySummaryState] is a [PeriodSummaryState] —
/// there is no second set of types to keep in sync and no `is` confusion at a
/// shared call site.
library;

import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/l10n/app_strings.dart';

import '../period/period_summary.dart';

export '../period/period_summary.dart' show dailySodiumTargetMg;

/// A week's cumulative summary: the seven Mon..Sun rollups plus the shared
/// period metrics.
typedef WeeklySummary = PeriodSummary;

/// The weekly dashboard's sealed view state.
typedef WeeklySummaryState = PeriodSummaryState;

/// One or more live inputs are still loading.
typedef WeeklySummaryLoading = PeriodSummaryLoading;

/// No day in the week logged a meal.
typedef WeeklySummaryEmpty = PeriodSummaryEmpty;

/// The week has logged data but no complete profile exists.
typedef WeeklySummaryNoProfile = PeriodSummaryNoProfile;

/// A complete weekly summary.
typedef WeeklySummaryReady = PeriodSummaryReady;

/// The dashed target line's label.
///
/// Fixed text so the weekly/monthly line ("base, excluding exercise") can never
/// be confused with the daily dashboard's number ("含运动").
const String weeklyTargetLineLabel = S.weeklyTargetLineLabelConst;

/// The target line's dash pattern (`[6, 4]`) — a visual cue that the line is a
/// reference, not a per-day measurement.
const List<int> weeklyTargetLineDashArray = <int>[6, 4];

/// Builds the weekly [WeeklySummaryState] from the seven rollups and the
/// profile.
///
/// The `week` is passed straight through as the period's day list (Mon..Sun,
/// seven entries), so an incomplete week is handled by the shared builder
/// exactly like an incomplete month: no logged day is empty, never a crash.
WeeklySummaryState buildWeeklySummary({
  required List<DayRollup> week,
  required UserProfile? profile,
  required DateTime today,
  List<WeightEntry> weightEntries = const <WeightEntry>[],
}) => buildPeriodSummary(
  days: week,
  profile: profile,
  today: today,
  weightEntries: weightEntries,
);
