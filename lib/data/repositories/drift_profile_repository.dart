/// Drift-backed [ProfileRepository].
library;

import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../db/app_database.dart';
import 'mappers.dart';

/// Stores the profile via `UserProfileDao` (single row, id `0`).
class DriftProfileRepository implements ProfileRepository {
  /// Creates the repository over [db].
  DriftProfileRepository(this._db);

  final AppDatabase _db;

  @override
  Future<UserProfile?> loadProfile() async {
    final row = await _db.userProfileDao.getProfile();
    return row == null ? null : userProfileFromRow(row);
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    return _db.userProfileDao.saveProfile(
      sex: profile.sex,
      birthDate: profile.birthDate,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      bmrKcalOverride: profile.bmrKcalOverride,
    );
  }

  @override
  Stream<UserProfile?> watchProfile() {
    return _db.userProfileDao.watchProfile().map(
      (row) => row == null ? null : userProfileFromRow(row),
    );
  }

  @override
  Future<void> clearProfile() async {
    await _db.userProfileDao.clearProfile();
  }
}
