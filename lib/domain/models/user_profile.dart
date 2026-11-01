import 'package:json_annotation/json_annotation.dart';

import '../../core/units/nutrition_units.dart';

part 'user_profile.g.dart';

/// Biological sex, as consumed by the Mifflin-St Jeor BMR equation.
enum Sex { male, female }

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
@JsonSerializable(explicitToJson: true, checked: true)
class UserProfile {
  const UserProfile({
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    this.bmrKcalOverride,
    this.dailyKcalGoalOverride,
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

  /// User-set **daily energy goal** in whole kcal/day, or `null` when no goal
  /// is set (the daily budget then stays "maintain": the resolved BMR).
  ///
  /// An explicit number the user picked — never a hidden factor: the energy
  /// engine uses it as the exercise-free daily baseline instead of the BMR, so
  /// `budget = goal + exercise` while a goal is set. Like [bmrKcalOverride],
  /// energy is integer-only and a legacy fractional value is rounded at the
  /// JSON boundary by [nullableKcalFromJson].
  @JsonKey(fromJson: nullableKcalFromJson)
  final int? dailyKcalGoalOverride;

  /// Whole years of age on [today] — see [ageOnBirthday].
  int ageOn(DateTime today) => ageOnBirthday(birthDate, today);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  /// Copies the profile, editing only the requested fields.
  ///
  /// [bmrKcalOverride] and [dailyKcalGoalOverride] are nullable, so passing
  /// them cannot express "clear the value": use [clearBmrKcalOverride] /
  /// [clearDailyKcalGoalOverride] for that (mirrors the "blank stays blank"
  /// rule used across the models).
  UserProfile copyWith({
    Sex? sex,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    int? bmrKcalOverride,
    int? dailyKcalGoalOverride,
    bool clearBmrKcalOverride = false,
    bool clearDailyKcalGoalOverride = false,
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
            other.dailyKcalGoalOverride == dailyKcalGoalOverride;
  }

  @override
  int get hashCode => Object.hash(
    sex,
    birthDate,
    heightCm,
    weightKg,
    bmrKcalOverride,
    dailyKcalGoalOverride,
  );
}
