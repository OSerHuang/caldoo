/// The meal-template feature end-to-end over the real app shell.
///
/// One seeded meal walks the full feature through the PRODUCTION routes and
/// screens (only persistence and the clock are faked):
///
/// * 存为模版 — the meal-detail app bar action opens the naming sheet
///   (pre-filled from the item names) and saves a template through the port;
/// * 模版库 — the 我的 tab's 餐食模版 entry lists, renames and deletes it;
/// * 从模版记录 — the capture screen's entry picks the template and routes
///   into the review form with the template-filled draft (no AI call); saving
///   writes a real meal carrying the template's items.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/templates/save_template_sheet.dart';
import 'package:caldoo/features/meals/templates/template_library_screen.dart';
import 'package:caldoo/features/nav/app_router.dart';
import 'package:caldoo/features/nav/meal_detail_screen.dart';
import 'package:caldoo/features/nav/nav_shell.dart';
import 'package:caldoo/features/nav/profile_tab_screen.dart';

import '_harness.dart';

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  group('存为模版 (meal detail)', () {
    testWidgets('the naming sheet is pre-filled and saves a template', (
      tester,
    ) async {
      final seeded = navMeal(id: 'meal-src', kcal: 420, name: '米饭');
      await env.meals.saveMealWithItems(seeded.meal, seeded.items);
      await env.pump(tester);

      final GoRouter router = env.container.read(appRouterProvider);
      router.go('/meal/meal-src');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(mealDetailSaveTemplateKey));
      await tester.pumpAndSettle();

      // The sheet pre-fills the name from the item names.
      final TextField field = tester.widget<TextField>(
        find.byKey(templateNameFieldKey),
      );
      expect(field.controller!.text, '米饭');

      await tester.enterText(find.byKey(templateNameFieldKey), '工作日午餐');
      await tester.tap(find.byKey(templateSaveConfirmKey));
      await tester.pumpAndSettle();

      final List<MealTemplate> templates = await env.templates
          .getAllTemplates();
      expect(templates, hasLength(1));
      expect(templates.single.name, '工作日午餐');
      expect(templates.single.mealType, seeded.meal.mealType);
      expect(templates.single.items.single.name, '米饭');
      expect(templates.single.items.single.kcal, 420);
      // The template is a copy: item ids do not have to match, but the values do.
      expect(templates.single.totalKcal, 420);
    });

    testWidgets('a blank name cannot be saved', (tester) async {
      final seeded = navMeal(id: 'meal-src', kcal: 420, name: '米饭');
      await env.meals.saveMealWithItems(seeded.meal, seeded.items);
      await env.pump(tester);

      final GoRouter router = env.container.read(appRouterProvider);
      router.go('/meal/meal-src');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(mealDetailSaveTemplateKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(templateNameFieldKey), '   ');
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.byKey(templateSaveConfirmKey))
            .onPressed,
        isNull,
      );
      expect(await env.templates.getAllTemplates(), isEmpty);
    });
  });

  group('餐食模版 library (我的 tab)', () {
    Future<void> openLibrary(WidgetTester tester) async {
      await tester.tap(find.byKey(navProfileKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(profileTabTemplatesKey));
      await tester.pumpAndSettle();
    }

    testWidgets('the library lists the saved template', (tester) async {
      await env.templates.saveTemplate(
        MealTemplate(
          id: 'tpl-1',
          name: '早餐标配',
          createdAt: DateTime(2026, 3, 4, 8),
          mealType: MealType.breakfast,
          items: const <MealItem>[
            MealItem(
              id: 'ti-1',
              name: '米饭',
              grams: 150,
              kcal: 174,
              carbG: 38.9,
              proteinG: 4.2,
              fatG: 0.6,
              saltG: 0.01,
              source: FoodSource.ai,
            ),
          ],
        ),
      );
      await env.pump(tester);

      await openLibrary(tester);

      expect(
        find.byKey(templateLibraryScreenKey).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('template_row_tpl-1')), findsOneWidget);
      expect(find.text('早餐标配'), findsOneWidget);
    });

    testWidgets('rename rewrites the template through the sheet', (
      tester,
    ) async {
      await env.templates.saveTemplate(
        MealTemplate(
          id: 'tpl-1',
          name: '早餐标配',
          createdAt: DateTime(2026, 3, 4, 8),
          mealType: MealType.breakfast,
          items: const <MealItem>[
            MealItem(
              id: 'ti-1',
              name: '米饭',
              grams: 150,
              kcal: 174,
              carbG: 38.9,
              proteinG: 4.2,
              fatG: 0.6,
              saltG: 0.01,
              source: FoodSource.ai,
            ),
          ],
        ),
      );
      await env.pump(tester);

      await openLibrary(tester);
      await tester.tap(find.byKey(const Key('template_rename_tpl-1')));
      await tester.pumpAndSettle();

      // The rename sheet opens pre-filled with the current name.
      expect(
        tester
            .widget<TextField>(find.byKey(templateNameFieldKey))
            .controller!
            .text,
        '早餐标配',
      );

      await tester.enterText(find.byKey(templateNameFieldKey), '减脂早餐');
      await tester.tap(find.byKey(templateSaveConfirmKey));
      await tester.pumpAndSettle();

      final List<MealTemplate> templates = await env.templates
          .getAllTemplates();
      expect(templates.single.name, '减脂早餐');
      expect(find.text('减脂早餐'), findsOneWidget);
    });

    testWidgets('delete confirms, then removes the row', (tester) async {
      await env.templates.saveTemplate(
        MealTemplate(
          id: 'tpl-1',
          name: '早餐标配',
          createdAt: DateTime(2026, 3, 4, 8),
          mealType: MealType.breakfast,
          items: const <MealItem>[
            MealItem(
              id: 'ti-1',
              name: '米饭',
              grams: 150,
              kcal: 174,
              carbG: 38.9,
              proteinG: 4.2,
              fatG: 0.6,
              saltG: 0.01,
              source: FoodSource.ai,
            ),
          ],
        ),
      );
      await env.pump(tester);

      await openLibrary(tester);
      await tester.tap(find.byKey(const Key('template_delete_tpl-1')));
      await tester.pumpAndSettle();

      // Confirm inside the dialog (the row's delete button is behind it).
      await tester.tap(find.widgetWithText(FilledButton, '删除').last);
      await tester.pumpAndSettle();

      expect(await env.templates.getAllTemplates(), isEmpty);
      expect(find.byKey(templateLibraryEmptyKey), findsOneWidget);
    });
  });

  group('从模版记录 (capture screen)', () {
    Future<void> pickTemplateInCapture(WidgetTester tester) async {
      await env.templates.saveTemplate(
        MealTemplate(
          id: 'tpl-1',
          name: '早餐标配',
          createdAt: DateTime(2026, 3, 4, 8),
          mealType: MealType.breakfast,
          items: const <MealItem>[
            MealItem(
              id: 'ti-1',
              name: '米饭',
              grams: 150,
              kcal: 174,
              carbG: 38.9,
              proteinG: 4.2,
              fatG: 0.6,
              saltG: 0.01,
              source: FoodSource.ai,
            ),
          ],
        ),
      );
      await env.pump(tester);
      await openMealCaptureFromToday(tester);

      // The template lane sits below the primary CTA at the bottom of the
      // capture form — off-screen on the 800x600 test viewport until scrolled.
      final Finder templateButton = find.byKey(captureTemplateButtonKey);
      await tester.ensureVisible(templateButton);
      await tester.pumpAndSettle();
      await tester.tap(templateButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('template_pick_tpl-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('the review form opens pre-filled with the template items', (
      tester,
    ) async {
      await pickTemplateInCapture(tester);

      // The review screen is on stage with the template's item line.
      expect(find.byType(MealReviewScreen), findsOneWidget);
      expect(find.text('米饭'), findsOneWidget);
      // The template's meal type is the pre-selected one.
      expect(find.text('早餐'), findsWidgets);
    });

    testWidgets('saving writes a real meal carrying the template items', (
      tester,
    ) async {
      await pickTemplateInCapture(tester);

      await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
      await tester.tap(find.byKey(reviewSaveButtonKey));
      await tester.pumpAndSettle();

      // Back on the capture screen, and the template meal is in the store.
      final List<MealWithItems> meals = await env.meals
          .getMealsWithItemsInRange(
            startInclusive: DateTime.utc(1900),
            endExclusive: DateTime.utc(2200),
          );
      expect(meals, hasLength(1));
      expect(meals.single.meal.mealType, MealType.breakfast);
      expect(meals.single.items.single.name, '米饭');
      expect(meals.single.items.single.kcal, 174);
      // Fresh ids: the template's line ids are never reused.
      expect(meals.single.items.single.id, isNot('ti-1'));
    });
  });
}
