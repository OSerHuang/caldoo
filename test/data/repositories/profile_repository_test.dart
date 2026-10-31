// The SAME contract suite runs twice: once against the Drift implementation
// (in-memory database) and once against the in-memory fake. A behavior only
// belongs to the repository contract when both implementations satisfy it.
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_profile_repository.dart';

import '../db/_test_db.dart';
import 'fake_repositories.dart';
import 'repository_suites.dart';

void main() {
  group('ProfileRepository: Drift implementation (in-memory DB)', () {
    late AppDatabase db;
    setUp(() => db = testDb());
    tearDown(() => db.close());

    runProfileRepositorySuite(() => DriftProfileRepository(db));
  });

  group('ProfileRepository: Fake implementation (in-memory field)', () {
    late FakeProfileRepository fake;
    setUp(() => fake = FakeProfileRepository());
    tearDown(() => fake.dispose());

    runProfileRepositorySuite(() => fake);
  });
}
