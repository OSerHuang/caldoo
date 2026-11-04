import 'package:json_annotation/json_annotation.dart';

import '../../core/units/nutrition_units.dart';

part 'user_profile.g.dart';

/// Biological sex, as consumed by the Mifflin-St Jeor BMR equation.
enum Sex { male, female }

/// A **relative** daily energy goal: a deficit or surplus applied on top of the
/// resolved basal metabolic rate (BMR).
///
/// Unlike [UserProfile.dailyKcalGoalOverride] — an absolute number that stays
/// fixed once saved — a preset is re-derived from the *current* BMR on every
/// read by the energy engine (`computeEnergyBudget`). The BMR itself is
/// computed from the anthropometrics (above all the body weight) unless the
/// user pinned it ([UserProfile.bmrKcalOverride]), so a preset goal follows the
/// weight while the BMR is derived: record a lighter weight and tomorrow's
/// daily budget is lower by the same number of kcal. With a pinned BMR the
/// preset is relative to that fixed number instead. That is exactly what the
/// presets mean ("基础代谢 −250 / −500 / +250 kcal/day").
///
/// A preset and [UserProfile.dailyKcalGoalOverride] are **mutually exclusive**:
/// the goal sheet always clears one when it writes the other, and the energy
/// engine rejects a profile that carries both rather than guessing which wins.
enum DailyGoalPreset {
  /// Gentle deficit: BMR − 250 kcal/day (≈ −0.25 kg/week).
  slowCut(-250),

  /// Faster deficit: BMR − 500 kcal/day (≈ −0.5 kg/week).
  fastCut(-500),

  /// Surplus: BMR + 250 kcal/day (≈ +0.25 kg/week).
  gain(250);

  const DailyGoalPreset(this.deltaKcal);

  /// Whole kcal/day added to the resolved BMR (negative = deficit).
  final int deltaKcal;
}

/// Normalises a calendar date to the canonical date-only shape used by
/// [UserProfile.birthDate]: **UTC midnight** of the picked year/month/day.
///
/// Only the Y/M/D components are meaningful; pinning them to UTC keeps the
/// value timezone-stable (a stored birthday never shifts by a day when the
/// phone travels), while the age calculation compares Y/M/D, never instants.
DateTime canonicalBirthDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Whole years of age of a person born on [birthDate] on [today].
///
/// Calendar arithmetic only: returns 30 for a 1995-10-22 birthday on
/// 2026-10-22 (birthday included) and 29 on 2026-10-21. The time-of-day of
/// either argument is irrelevant.
int ageOnBirthday(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  final bool birthdayReached =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!birthdayReached) {
    age -= 1;
  }
  return age;
}

/// The user's energy-profile inputs.
///
/// Holds the anthropometrics the basal-metabolic-rate estimate needs — [sex],
/// [birthDate], [heightCm] and [weightKg] — plus an optional user-set
/// [bmrKcalOverride]. Age is **derived** from [birthDate] ([ageOn]), so the
/// user never has to update it year after year.
///
/// There is deliberately **no activity level**: the daily baseline is the
/// basal metabolic rate itself, derived from the anthropometrics with
/// Mifflin-St Jeor and editable by the user. Logged exercise is added on top of
/// that baseline by the energy engine.
///
/// The optional goal is either a [DailyGoalPreset] (expressed relative to the
/// BMR, so it follows the weight) or a fixed [dailyKcalGoalOverride]; never
/// both.
@JsonSerializable(explicitToJson: true, checked: true)
class UserProfile {
  const UserProfile({
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    this.bmrKcalOverride,
    this.dailyKcalGoalOverride,
    this.dailyGoalPreset,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  final Sex sex;

  /// Birthday as a canonical date-only value (see [canonicalBirthDate]).
  ///
  /// The age is always derived from this at the point of use, so a profile
  /// stays correct across birthdays without any edit.
  final DateTime birthDate;

  /// Height in centimetres.
  final double heightCm;

  /// Weight in kilograms (editable; BMR recomputes on change).
  final double weightKg;

  /// User-set basal metabolic rate in **whole kcal/day**.
  ///
  /// `null` means "derive it": the energy engine computes Mifflin-St Jeor from
  /// [sex] / age ([ageOn]) / [heightCm] / [weightKg]. A non-null value is the
  /// user's own number and wins over the estimate. Energy is integer-only; a
  /// fractional value in a legacy backup is rounded at the JSON boundary by
  /// [nullableKcalFromJson].
  @JsonKey(fromJson: nullableKcalFromJson)
  final int? bmrKcalOverride;

  /// User-set **fixed** daily energy goal in whole kcal/day, or `null` when no
  /// goal is set (the daily budget then stays "maintain": the resolved BMR).
  ///
  /// An explicit number the user typed — never a hidden factor: the energy
  /// engine uses it as the exercise-free daily baseline instead of the BMR, so
  /// `budget = goal + exercise` while a goal is set. This number does NOT
  /// follow the anthropometrics: a custom goal is a promise the user made, so
  /// a weight change leaves it alone. (Use [dailyGoalPreset] for a goal that
  /// follows the BMR.) Like [bmrKcalOverride], energy is integer-only and a
  /// legacy fractional value is rounded at the JSON boundary by
  /// [nullableKcalFromJson].
  @JsonKey(fromJson: nullableKcalFromJson)
  final int? dailyKcalGoalOverride;

  /// The **relative** daily energy goal preset, or `null` when none is stored.
  ///
  /// When set, the goal is `resolveBmrKcal(profile) + preset.deltaKcal` and is
  /// re-derived on every read, so it follows the body weight (and any other
  /// BMR input) automatically. Stored as the enum **name** in Drift, so a
  /// reordering of [DailyGoalPreset] can never re-interpret an existing row.
  ///
  /// Mutually exclusive with [dailyKcalGoalOverride]: at most one of the two is
  /// non-null. A profile that carries both is malformed and the energy engine
  /// throws rather than picking one.
  final DailyGoalPreset? dailyGoalPreset;

  /// Whole years of age on [today] — see [ageOnBirthday].
  int ageOn(DateTime today) => ageOnBirthday(birthDate, today);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  /// Copies the profile, editing only the requested fields.
  ///
  /// [bmrKcalOverride], [dailyKcalGoalOverride] and [dailyGoalPreset] are
  /// nullable, so passing them cannot express "clear the value": use
  /// [clearBmrKcalOverride] / [clearDailyKcalGoalOverride] /
  /// [clearDailyGoalPreset] for that (mirrors the "blank stays blank" rule
  /// used across the models).
  UserProfile copyWith({
    Sex? sex,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    int? bmrKcalOverride,
    int? dailyKcalGoalOverride,
    DailyGoalPreset? dailyGoalPreset,
    bool clearBmrKcalOverride = false,
    bool clearDailyKcalGoalOverride = false,
    bool clearDailyGoalPreset = false,
  }) {
    return UserProfile(
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bmrKcalOverride: clearBmrKcalOverride
          ? null
          : (bmrKcalOverride ?? this.bmrKcalOverride),
      dailyKcalGoalOverride: clearDailyKcalGoalOverride
          ? null
          : (dailyKcalGoalOverride ?? this.dailyKcalGoalOverride),
      dailyGoalPreset: clearDailyGoalPreset
          ? null
          : (dailyGoalPreset ?? this.dailyGoalPreset),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserProfile &&
            other.sex == sex &&
            other.birthDate == birthDate &&
            other.heightCm == heightCm &&
            other.weightKg == weightKg &&
            other.bmrKcalOverride == bmrKcalOverride &&
            other.dailyKcalGoalOverride == dailyKcalGoalOverride &&
            other.dailyGoalPreset == dailyGoalPreset;
  }

  @override
  int get hashCode => Object.hash(
    sex,
    birthDate,
    heightCm,
    weightKg,
    bmrKcalOverride,
    dailyKcalGoalOverride,
    dailyGoalPreset,
  );
}
