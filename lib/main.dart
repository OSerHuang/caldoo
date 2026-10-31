/// App entry point: the Riverpod scope plus the go_router `MaterialApp.router`.
///
/// The router (task 27) is a provider so every screen and test sees the same
/// instance, disposed with the scope. The bottom-nav shell owns the three
/// primary tabs (概览 / 食物库 / 我的 — the 汇总 tab is merged into 概览 as its
/// week/month views); `/meal/:id` is a top-level deep link.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/units/display_units.dart';
import 'features/nav/app_router.dart';
import 'features/settings/backup/auto_backup_lifecycle.dart';
import 'features/settings/display_settings.dart';
import 'features/settings/display_settings_providers.dart';
import 'features/settings/privacy/privacy_notice.dart';
import 'l10n/app_strings.dart';

/// The app's only locale: zh-CN. The string table ([S]) is a single zh-CN table,
/// and the Material *framework* widgets (the date picker, text-field context
/// menus, tooltips) are pinned to the same locale so a dialog is never a mix of
/// Chinese and English.
const Locale appLocale = Locale('zh', 'CN');

Future<void> main() async {
  // The layouts are portrait-only (the daily/weekly dashboards and their
  // history pagers are designed for a phone held upright), so the app never
  // follows the device into landscape. The manifest pins the activity to
  // portrait for the launch window; this runtime lock is the second half
  // (and covers a config change the manifest cannot).
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  // The app's dependency-injection graph (lib/core/providers/app_providers.dart)
  // lives in this scope: the database and repositories are created lazily on
  // first use and disposed with the scope.
  runApp(const ProviderScope(child: HaohaochifanApp()));
}

/// The root widget: a `MaterialApp.router` over the app [GoRouter].
class HaohaochifanApp extends ConsumerWidget {
  /// Creates the app.
  const HaohaochifanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    // The persisted display preferences (kcal/kJ, salt/sodium). While they load
    // — or if the settings DB is unavailable — the app's defaults apply, so the
    // first frame is never blocked on a preference.
    final DisplaySettings display =
        ref.watch(displaySettingsProvider).value ?? DisplaySettings.defaults;
    return DisplayScope(
      units: display.units,
      child: MaterialApp.router(
        title: S.instance.appTitle,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        locale: appLocale,
        supportedLocales: const <Locale>[appLocale],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Gate the first run behind the privacy notice. `builder` (rather than
        // wrapping above `MaterialApp`) keeps Directionality /
        // MaterialLocalizations available to the notice's Scaffold and AppBar.
        //
        // [AutoBackupLifecycle] rides in the same builder: it is invisible, runs
        // the automatic off-app backup after the first frame and on every move
        // to the background, and stays above the notice so a first run is also
        // covered once the user starts recording.
        builder: (BuildContext context, Widget? child) => PrivacyNoticeGate(
          child: AutoBackupLifecycle(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
