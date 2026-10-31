/// Repository port for the single-row user profile (the phase-2 sync seam).
///
/// This interface is **pure Dart**: it imports [UserProfile] and nothing from
/// `drift`, and every method speaks in domain models — never `UserProfileRow`.
/// A phase-2 sync implementation, or an in-memory test fake, can therefore
/// satisfy it without knowing the local schema. The Drift implementation lives
/// in `lib/data/repositories/` and maps rows to domain models inside its own
/// layer.
library;

import '../models/user_profile.dart';

/// Persistence port for the one and only stored [UserProfile].
abstract interface class ProfileRepository {
  /// The stored profile, or `null` before onboarding.
  Future<UserProfile?> loadProfile();

  /// Inserts the profile, or overwrites the existing single row in place.
  Future<void> saveProfile(UserProfile profile);

  /// Emits the profile on every change (`null` until one is saved).
  Stream<UserProfile?> watchProfile();

  /// Removes the stored profile (used by "delete all local data").
  Future<void> clearProfile();
}
