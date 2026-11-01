/// The install script is a data-loss guard, so it is pinned by the suite.
///
/// Background: on 2026-10-30 the app was installed with a command that fell
/// back to uninstalling the old version first, and the uninstall deleted the
/// Drift database (the app declares `allowBackup="false"`, so the OS kept no
/// copy either) — every logged meal was lost. `tool/install_android.sh` exists
/// to make the safe path the default one; this test keeps it that way, because
/// the script is documentation that can silently rot.
///
/// What must stay true:
/// * it installs with `adb install -r` (overwrite in place, keep app data);
/// * it never runs a tooling install command that uninstalls first, and never
///   runs `adb uninstall` / `pm clear`;
/// * it refuses to install without a recent automatic backup on the device.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String script;
  late String code;

  setUpAll(() {
    script = File('tool/install_android.sh').readAsStringSync();
    // Comments describe the rule (and name the forbidden commands); only
    // executable lines are asserted on.
    code = script
        .split('\n')
        .where((String line) => !line.trimLeft().startsWith('#'))
        .join('\n');
  });

  test('installs with the data-preserving adb install -r', () {
    expect(
      script,
      contains('install -r'),
      reason: 'overwrite-install keeps /data/data/com.caldoo',
    );
  });

  test('never uninstalls or clears app data', () {
    expect(code, isNot(contains('adb uninstall')));
    expect(code, isNot(contains('pm clear')));
    // The destructive sub-command (install a prebuilt APK after uninstalling
    // the old version) must not appear as an executable command line.
    expect(
      RegExp(r'^\s*flutter\s+install', multiLine: true).hasMatch(code),
      isFalse,
      reason: 'that command uninstalls the app before installing',
    );
  });

  test('builds the APK itself instead of installing a stale artifact', () {
    expect(script, contains('flutter --no-version-check build apk --release'));
  });

  test('requires a fresh automatic backup before touching the device', () {
    expect(script, contains('ALLOW_NO_BACKUP'));
    expect(script, contains('Download/caldoo'));
    expect(
      script,
      contains('1440'),
      reason: 'refuses a backup older than a day',
    );
  });
}
