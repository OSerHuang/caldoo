import 'package:drift/drift.dart';

import '../../../domain/models/user_profile.dart';
import '../app_database.dart';
import '../tables/user_profiles.dart';

part 'user_profile_dao.g.dart';

/// Reads and writes the single-row `user_profile` table.
///
/// The row is addressed by the fixed [singleRowId] (`0`); `saveProfile` always
/// upserts that row, so a caller can never accumulate a second profile.
@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.attachedDatabase);

  /// Primary key of the one and only profile row (enforced by a `CHECK`).
  static const int singleRowId = 0;

  /// The stored profile, or null before onboarding.
  Future<UserProfileRow?> getProfile() {
    return (select(
      userProfiles,
    )..where((t) => t.id.equals(singleRowId))).getSingleOrNull();
  }

  /// Emits the profile on every change (null until one is saved).
  Stream<UserProfileRow?> watchProfile() {
    final query = select(userProfiles)..where((t) => t.id.equals(singleRowId));
    return query.watchSingleOrNull();
  }

  /// Inserts the profile or replaces the existing row in place.
  ///
  /// [bmrKcalOverride] is stored verbatim; `null` lets the engine derive the
  /// basal metabolic rate with Mifflin-St Jeor from the anthropometrics.
  /// [dailyKcalGoalOverride] is stored verbatim too; `null` means "no goal"
  /// (the budget stays the resolved BMR).
  Future<void> saveProfile({
    required Sex sex,
    required DateTime birthDate,
    required double heightCm,
    required double weightKg,
    int? bmrKcalOverride,
    int? dailyKcalGoalOverride,
  }) {
    return into(userProfiles).insertOnConflictUpdate(
      UserProfilesCompanion.insert(
        id: const Value<int>(singleRowId),
        sex: sex,
        birthDate: birthDate,
        heightCm: heightCm,
        weightKg: weightKg,
        bmrKcalOverride: Value<int?>(bmrKcalOverride),
        dailyKcalGoalOverride: Value<int?>(dailyKcalGoalOverride),
      ),
    );
  }

  /// Deletes the profile row; returns the number of rows removed (0 or 1).
  Future<int> clearProfile() => delete(userProfiles).go();
}
