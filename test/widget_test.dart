import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/features/nav/nav_shell.dart';
import 'package:caldoo/features/nav/today_screen.dart';

import 'features/nav/_harness.dart';

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  testWidgets('the app boots into the three-tab shell on Today', (
    WidgetTester tester,
  ) async {
    await env.pump(tester);

    expect(find.byKey(todayScreenKey).hitTestable(), findsOneWidget);
    expect(find.byKey(navTodayKey), findsOneWidget);
    expect(find.byKey(navFoodsKey), findsOneWidget);
    expect(find.byKey(navProfileKey), findsOneWidget);
    // The 汇总 tab was merged into 概览: no second dashboard destination.
    expect(find.byKey(const Key('nav_summary')), findsNothing);
  });
}
