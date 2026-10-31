/// Task 13: the Riverpod DI graph and its override pattern.
///
/// Every test here runs against a `ProviderScope`/`ProviderContainer` whose
/// `appDatabaseProvider` is the in-memory harness from
/// `test/data/db/_test_db.dart`; the real file DB must never be opened under
/// `flutter test` (asserted below, with the documented `MissingPluginException`
/// as the failure mode when it is not overridden).
///
/// Riverpod 3.4 note: a `read` of a `StreamProvider` with no live listener
/// leaves its subscription paused, so stream tests use
/// `container.listen(..., fireImmediately: true)`.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/repositories.dart';
import 'package:caldoo/data/settings/app_settings_store.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/repositories/repositories.dart';
import 'package:caldoo/features/settings/ai_settings.dart';

import '../../data/db/_test_db.dart';
import '../../data/repositories/fake_repositories.dart';

final UserProfile _profile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 1, 1),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

void main() {
  group('ProviderScope override pattern', () {
    testWidgets('overrides route every repository onto the in-memory DB', (
      tester,
    ) async {
      final AppDatabase db = testDb();
      addTearDown(db.close);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            connectivityProvider.overrideWith(
              (ref) => Stream<List<ConnectivityResult>>.value(
                const <ConnectivityResult>[ConnectivityResult.wifi],
              ),
            ),
          ],
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              container = ProviderScope.containerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // The container hands out the in-memory harness for the DB port; the
      // real file DB provider is shadowed and therefore never opened.
      expect(identical(container.read(appDatabaseProvider), db), isTrue);

      // All four ports resolve to the Drift implementations over that DB.
      expect(
        container.read(profileRepositoryProvider),
        isA<DriftProfileRepository>(),
      );
      expect(
        container.read(foodRepositoryProvider),
        isA<DriftFoodRepository>(),
      );
      expect(
        container.read(mealRepositoryProvider),
        isA<DriftMealRepository>(),
      );
      expect(
        container.read(exerciseRepositoryProvider),
        isA<DriftExerciseRepository>(),
      );

      // A real write through the provider handle lands in the overridden DB.
      final ProfileRepository repo = container.read(profileRepositoryProvider);
      await repo.saveProfile(_profile);
      expect(await repo.loadProfile(), _profile);
      expect(await db.userProfileDao.getProfile(), isNotNull);

      // The connectivity override is in place too: while the canned stream is
      // still loading nothing is reported offline (no startup banner flash).
      expect(container.read(connectivityProvider).isLoading, isTrue);
      expect(container.read(isOfflineProvider), isFalse);
    });

    testWidgets('a fake repository override replaces the port entirely', (
      tester,
    ) async {
      final FakeProfileRepository fake = FakeProfileRepository();
      addTearDown(fake.dispose);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Tripwire: reading the database port fails the test, so a
            // passing run proves the fake repository fully replaced the Drift
            // one and the file DB provider was never touched.
            appDatabaseProvider.overrideWith(
              (ref) => throw StateError('appDatabaseProvider must not be read'),
            ),
            profileRepositoryProvider.overrideWithValue(fake),
          ],
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              container = ProviderScope.containerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final ProfileRepository repo = container.read(profileRepositoryProvider);
      expect(identical(repo, fake), isTrue);
      await repo.saveProfile(_profile);
      expect(await fake.loadProfile(), _profile);
    });
  });

  group('un-overridden providers', () {
    test('the real file DB provider cannot open under flutter test', () async {
      // `flutter test` has no path_provider plugin, so drift's lazy opener
      // (drift_flutter `driftDatabase(name:)`) fails the moment the file DB is
      // constructed. This is the documented "not initialized" failure that
      // makes overriding appDatabaseProvider mandatory in every test.
      TestWidgetsFlutterBinding.ensureInitialized();
      final ProviderContainer container = ProviderContainer.test();
      final List<Object> zoneErrors = <Object>[];

      await runZonedGuarded(
        () async {
          final AppDatabase db = container.read(appDatabaseProvider);
          expect(db, isA<AppDatabase>());
          await expectLater(
            db.appSettingsDao.getAll(),
            throwsA(isA<MissingPluginException>()),
          );
        },
        (Object error, StackTrace stackTrace) {
          zoneErrors.add(error);
        },
      );

      expect(zoneErrors, isNotEmpty);
      expect(zoneErrors.first, isA<MissingPluginException>());
      expect('$zoneErrors', contains('path_provider'));
    });
  });

  group('appSettingsStoreProvider', () {
    test('round-trips a non-secret pref through the Drift table', () async {
      final AppDatabase db = testDb();
      addTearDown(db.close);
      final ProviderContainer container = ProviderContainer.test(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );

      final AppSettingsStore store = container.read(appSettingsStoreProvider);
      expect(await store.read('notice_seen'), isNull);

      // Watching through the provider emits the initial null, then the write.
      final List<String?> seen = <String?>[];
      final StreamSubscription<String?> subscription = store
          .watch('notice_seen')
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      await store.write('notice_seen', 'true');
      await pumpEventQueue();
      expect(seen, <String?>[null, 'true']);

      expect(await store.read('notice_seen'), 'true');
      expect(await store.readBool('notice_seen'), isTrue);
      // The value really lives in Drift, not in provider state.
      expect(await db.appSettingsDao.getValue('notice_seen'), 'true');

      // The generic prefs lane does NOT duplicate the AI keys owned by task 17.
      expect(
        await db.appSettingsDao.getValue(AiSettingsRepository.baseUrlPrefKey),
        isNull,
      );
      expect(
        await db.appSettingsDao.getValue(AiSettingsRepository.modelPrefKey),
        isNull,
      );

      await store.remove('notice_seen');
      expect(await store.read('notice_seen'), isNull);
      expect(await store.readBool('notice_seen', fallback: true), isTrue);
    });
  });

  group('connectivityProvider', () {
    test('follows the overridden stream and projects isOffline', () async {
      final AppDatabase db = testDb();
      addTearDown(db.close);
      final StreamController<List<ConnectivityResult>> connectivity =
          StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);

      final ProviderContainer container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          connectivityProvider.overrideWith((ref) => connectivity.stream),
        ],
      );
      // A live listener keeps the provider's stream subscription unpaused.
      final subscription = container.listen(
        connectivityProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      // No event yet: not offline, so the UI never flashes a banner and a
      // plugin failure can never block saving (draft G7).
      expect(container.read(connectivityProvider).isLoading, isTrue);
      expect(container.read(isOfflineProvider), isFalse);

      connectivity.add(const <ConnectivityResult>[ConnectivityResult.none]);
      await pumpEventQueue();
      expect(container.read(isOfflineProvider), isTrue);

      connectivity.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(container.read(isOfflineProvider), isFalse);
    });
  });
}
