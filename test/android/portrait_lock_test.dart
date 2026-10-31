/// The app is portrait-only (no landscape UI).
///
/// The actual lock is enforced twice at the platform layer — the activity's
/// `android:screenOrientation="portrait"` and `SystemChrome
/// .setPreferredOrientations` in `main()` — which a widget test cannot observe.
/// This guard instead pins the manifest half, so an accidental edit that drops
/// the attribute fails the suite instead of silently letting landscape back in.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Android activity is locked to portrait', () {
    final String manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(
      manifest,
      contains('android:screenOrientation="portrait"'),
      reason:
          'the app is portrait-only; the activity must declare '
          'android:screenOrientation="portrait"',
    );
  });

  test('main() re-applies the portrait orientation at runtime', () {
    final String mainDart = File('lib/main.dart').readAsStringSync();

    expect(mainDart, contains('SystemChrome.setPreferredOrientations'));
    expect(mainDart, contains('DeviceOrientation.portraitUp'));
    expect(
      mainDart,
      isNot(contains('DeviceOrientation.landscape')),
      reason: 'landscape must never be a preferred orientation',
    );
  });
}
