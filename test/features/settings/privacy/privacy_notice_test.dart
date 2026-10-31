import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_providers.dart';

import '../../../data/db/_test_db.dart';
import '../_fakes.dart';

/// Pumps [PrivacyNoticeGate] over a "HOME" child with the test DB + fake key
/// store, exactly like a real app launch.
Future<void> _pumpGate(
  WidgetTester tester, {
  required AppDatabase db,
  required InMemorySecureKeyStore keyStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(keyStore),
      ],
      child: const MaterialApp(
        home: PrivacyNoticeGate(child: Scaffold(body: Text('HOME'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late InMemorySecureKeyStore keyStore;

  setUp(() {
    db = testDb();
    keyStore = InMemorySecureKeyStore();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('notice is shown once (persisted flag) and never again', (
    tester,
  ) async {
    await _pumpGate(tester, db: db, keyStore: keyStore);

    // First launch: the notice is visible and the app content is gated.
    expect(find.byKey(const Key('privacy_notice_screen')), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    // The flag is not yet persisted.
    expect(
      await db.appSettingsDao.getValue(PrivacyNoticeController.seenKey),
      isNull,
    );

    // Acknowledge: the flag is persisted and the app content is revealed.
    await tester.tap(find.byKey(const Key('privacy_notice_accept')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy_notice_screen')), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect(
      await db.appSettingsDao.getValue(PrivacyNoticeController.seenKey),
      'true',
    );

    // Simulate a relaunch: brand-new tree + scope over the SAME storage.
    await tester.pumpWidget(Container());
    await _pumpGate(tester, db: db, keyStore: keyStore);

    expect(find.byKey(const Key('privacy_notice_screen')), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });
}
