/// Nutrition-label capture flow tests: photo preview, multi-label parsing,
/// packaging-name prefill, supplementary notes, confirm/save.
///
/// The tests drive the recorded fixtures through the real task-14 [AiClient]
/// against a mocked Dio adapter, then through the widget form and into a fake
/// [FoodRepository]. No socket, no platform channel, no real DB.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/ai/schemas/label_parse.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/features/meals/label/label_capture_controller.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/label/label_draft.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show aiClientProvider;

import '../../../data/repositories/fake_repositories.dart';
import '../../../ai/schemas/fixture_support.dart';

/// A recorded fixture file, as the provider would return it.
String _fixtureBody(String name) =>
    File('test/fixtures/ai/$name').readAsStringSync();

/// Real label-photo bytes so the bounded codec has something to decode.
Future<Uint8List> _fixturePhoto() =>
    File('test/fixtures/ai/samples/nutrition_label.jpg').readAsBytes();

ResponseBody _json(String body) => ResponseBody.fromString(
  body,
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

/// An [AiClient] wired to a mock adapter serving [body].
({AiClient client, Dio dio}) _fixtureClient(String body) {
  final Dio dio = Dio();
  dio.httpClientAdapter = _FixtureAdapter(body);
  return (
    client: AiClient(
      baseUrl: 'https://example.test',
      model: 'test-model',
      apiKey: () async => 'test-key-label-0123456789abcdef',
      dio: dio,
    ),
    dio: dio,
  );
}

class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.body);

  final String body;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _json(body);
  }

  @override
  void close({bool force = false}) {}
}

String _fieldText(WidgetTester tester, Key key) {
  final TextField field = tester.widget<TextField>(find.byKey(key));
  return field.controller!.text;
}

void main() {
  late FakeFoodRepository repo;
  late AiClient client;
  late _FixtureAdapter adapter;
  late Uint8List photo;
  late int idCounter;

  setUp(() async {
    repo = FakeFoodRepository();
    final ({AiClient client, Dio dio}) wired = _fixtureClient(
      _fixtureBody('label_photo_response.json'),
    );
    client = wired.client;
    adapter = wired.dio.httpClientAdapter as _FixtureAdapter;
    photo = await _fixturePhoto();
    idCounter = 0;
  });

  tearDown(() async {
    await repo.dispose();
  });

  /// Pumps the screen with [body] served by the AI adapter.
  Future<void> pumpFlow(
    WidgetTester tester, {
    String? body,
    LabelPhotoSource? source,
    bool startManualEntry = false,
  }) async {
    if (body != null) {
      final ({AiClient client, Dio dio}) rewired = _fixtureClient(body);
      client = rewired.client;
      adapter = rewired.dio.httpClientAdapter as _FixtureAdapter;
    }
    // A tall surface so the whole confirm form (and its save button) is
    // visible without scrolling.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiClientProvider.overrideWithValue(client),
          labelPhotoSourceProvider.overrideWithValue(
            source ?? (LabelPhotoLane lane) async => photo,
          ),
          foodRepositoryProvider.overrideWithValue(repo),
          labelIdGeneratorProvider.overrideWithValue(
            () => 'label-food-${++idCounter}',
          ),
        ],
        child: MaterialApp(
          home: LabelCaptureScreen(startManualEntry: startManualEntry),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickAndParse(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('label_pick_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('label_parse_button')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the picked photo is previewed before recognition so the user can confirm '
    'the right photo was selected',
    (WidgetTester tester) async {
      await pumpFlow(tester);

      // No preview until something is picked.
      expect(find.byKey(labelPhotoPreviewKey), findsNothing);

      await tester.tap(find.byKey(const Key('label_pick_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(labelPhotoPreviewKey), findsOneWidget);
      expect(find.text('已选择照片（识别前请确认是否清晰、是否选对）'), findsOneWidget);
      // The parse button became available with a photo selected.
      final FilledButton parse = tester.widget<FilledButton>(
        find.byKey(const Key('label_parse_button')),
      );
      expect(parse.onPressed, isNotNull);
    },
  );

  testWidgets(
    'the camera button uses the camera lane and previews the new photo',
    (WidgetTester tester) async {
      final List<LabelPhotoLane> lanes = <LabelPhotoLane>[];
      await pumpFlow(
        tester,
        source: (LabelPhotoLane lane) async {
          lanes.add(lane);
          return photo;
        },
      );

      // The pick step offers both lanes.
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册选择'), findsOneWidget);

      await tester.tap(find.byKey(labelCameraButtonKey));
      await tester.pumpAndSettle();

      expect(lanes, <LabelPhotoLane>[LabelPhotoLane.camera]);
      expect(find.byKey(labelPhotoPreviewKey), findsOneWidget);
      // After a photo is picked the buttons offer re-take/re-pick.
      expect(find.text('重新拍照'), findsOneWidget);
      expect(find.text('重新选择'), findsOneWidget);
    },
  );

  testWidgets(
    'single-label fixture: name/brand are pre-filled from the packaging, the '
    'supplementary note is sent to the model and saved on the food',
    (WidgetTester tester) async {
      await pumpFlow(tester);

      const String note = '这是原味苏打饼干，一包 45 g；别名：小饼干';
      await tester.enterText(find.byKey(labelNoteFieldKey), note);
      await pickAndParse(tester);

      // Prefilled identity from the photo.
      expect(_fieldText(tester, labelNameFieldKey(0)), '原味苏打饼干');
      expect(_fieldText(tester, labelBrandFieldKey(0)), '某品牌');
      // The note is pre-filled into the saveable notes field too.
      expect(_fieldText(tester, labelNotesFieldKey(0)), note);
      // Parsed GB 28050 values are on screen.
      expect(_fieldText(tester, labelFieldKey(0, LabelField.energy)), '221');
      expect(_fieldText(tester, labelFieldKey(0, LabelField.sodium)), '0');
      expect(_fieldText(tester, labelFieldKey(0, LabelField.protein)), '1.5');
      expect(
        _fieldText(tester, labelFieldKey(0, LabelField.carbohydrate)),
        '10.2',
      );

      // The request carried the note as a hint but the tool call is plural.
      expect(adapter.requests, hasLength(1));
      final String body = jsonEncode(adapter.requests.single.data);
      expect(body, contains('emit_nutrition_labels'));
      expect(body, contains('image_url'));
      expect(body, contains(note));

      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final Food? saved = await repo.getFood('label-food-1');
      expect(saved, isNotNull);
      expect(saved!.source, FoodSource.label);
      expect(saved.name, '原味苏打饼干');
      expect(saved.brand, '某品牌');
      // The retired 补充说明 is not stored; the text only feeds the structured
      // alias/serving fields.
      expect(saved.notes, isNull);
      expect(saved.aliases, <String>['小饼干']);
      expect(saved.servings.single.label, '一包');
      expect(saved.servings.single.amount, 45);
      // kJ -> kcal is rounded once at the boundary: roundKcal(221/4.184)=53.
      expect(saved.kcal, 53);
      expect(saved.sodiumMg, 0);
      expect(saved.proteinG, 1.5);
      expect(saved.carbG, 10.2);
      // The optional GB 28050 declarations are stored now, blank stays NULL.
      expect(saved.sugarG, 5.8);
      expect(saved.saturatedFatG, 0);
      expect(find.text('已保存：原味苏打饼干'), findsOneWidget);
    },
  );

  testWidgets(
    'one photo with two labels renders two cards and saves two foods',
    (WidgetTester tester) async {
      await pumpFlow(
        tester,
        body: _fixtureBody('label_photo_response_multi.json'),
      );
      await tester.enterText(find.byKey(labelNoteFieldKey), '两包零食');
      await pickAndParse(tester);

      expect(find.byKey(labelCardKey(0)), findsOneWidget);
      expect(find.byKey(labelCardKey(1)), findsOneWidget);
      expect(_fieldText(tester, labelNameFieldKey(0)), '乐事原味薯片');
      expect(_fieldText(tester, labelNameFieldKey(1)), '纯牛奶');
      expect(_fieldText(tester, labelBrandFieldKey(0)), '乐事');
      expect(_fieldText(tester, labelBrandFieldKey(1)), '某牧业');
      // Both labels inherited the supplementary note, one card each.
      expect(_fieldText(tester, labelNotesFieldKey(0)), '两包零食');
      expect(_fieldText(tester, labelNotesFieldKey(1)), '两包零食');

      await tester.enterText(find.byKey(labelNameFieldKey(1)), '某牧业纯牛奶 250ml');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final Food? chips = await repo.getFood('label-food-1');
      final Food? milk = await repo.getFood('label-food-2');
      expect(chips, isNotNull);
      expect(milk, isNotNull);
      expect(chips!.name, '乐事原味薯片');
      expect(chips.brand, '乐事');
      expect(chips.notes, isNull);
      expect(chips.sodiumMg, 500);
      expect(milk!.name, '某牧业纯牛奶 250ml');
      expect(milk.brand, '某牧业');
      expect(milk.kcal, 65); // roundKcal(270 / 4.184) = 65
      expect(await repo.getAllFoods(), hasLength(2));
    },
  );

  testWidgets(
    'a label excluded with the switch is not saved (no name required)',
    (WidgetTester tester) async {
      await pumpFlow(
        tester,
        body: _fixtureBody('label_photo_response_multi.json'),
      );
      await pickAndParse(tester);

      await tester.tap(find.byKey(labelIncludeSwitchKey(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final List<Food> foods = await repo.getAllFoods();
      expect(foods, hasLength(1));
      expect(foods.single.name, '乐事原味薯片');
    },
  );

  testWidgets(
    'excluding every label is a validation error, not an empty save',
    (WidgetTester tester) async {
      await pumpFlow(
        tester,
        body: _fixtureBody('label_photo_response_multi.json'),
      );
      await pickAndParse(tester);

      await tester.tap(find.byKey(labelIncludeSwitchKey(0)));
      await tester.tap(find.byKey(labelIncludeSwitchKey(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('请至少保留一张要保存的标签'), findsOneWidget);
      expect(await repo.getAllFoods(), isEmpty);
    },
  );

  testWidgets('a label with only energy saves it and leaves every macro BLANK '
      '(asserted null, no fake zeros)', (WidgetTester tester) async {
    await pumpFlow(tester);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(LabelCaptureScreen)),
    );
    container
        .read(labelCaptureControllerProvider.notifier)
        .seedDraft(const LabelDraft(name: '只标能量', energyKj: 221));
    await tester.pumpAndSettle();

    // Blank macros render as empty inputs, not "0".
    expect(_fieldText(tester, labelFieldKey(0, LabelField.protein)), isEmpty);
    expect(_fieldText(tester, labelFieldKey(0, LabelField.sodium)), isEmpty);

    await tester.tap(find.byKey(const Key('label_save_button')));
    await tester.pumpAndSettle();

    final Food? saved = await repo.getFood('label-food-1');
    expect(saved, isNotNull);
    expect(saved!.source, FoodSource.label);
    expect(saved.kcal, 53); // roundKcal(221 / 4.184) = 53
    expect(saved.proteinG, isNull);
    expect(saved.carbG, isNull);
    expect(saved.fatG, isNull);
    expect(saved.sodiumMg, isNull);
    expect(saved.brand, isNull);
    expect(saved.notes, isNull);
  });

  testWidgets('a missing food name blocks the save with a clear message', (
    WidgetTester tester,
  ) async {
    await pumpFlow(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(LabelCaptureScreen)),
    );
    container
        .read(labelCaptureControllerProvider.notifier)
        .seedDraft(const LabelDraft(energyKj: 221));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('label_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('请填写食品名称'), findsOneWidget);
    expect(await repo.getAllFoods(), isEmpty);
  });

  testWidgets(
    'startManualEntry opens the blank confirm form with no camera or AI call',
    (WidgetTester tester) async {
      // The 食物库 → 添加食物 → 手动录入 entry point: the screen must land on the
      // confirm step directly and never touch the camera or the network.
      await pumpFlow(tester, startManualEntry: true);

      expect(find.byKey(labelNameFieldKey(0)), findsOneWidget);
      expect(find.byKey(labelCameraButtonKey), findsNothing);
      expect(find.byKey(const Key('label_parse_button')), findsNothing);
      expect(find.text('手动录入'), findsOneWidget);
      expect(adapter.requests, isEmpty);

      await tester.enterText(find.byKey(labelNameFieldKey(0)), '手输饼干');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final Food? saved = await repo.getFood('label-food-1');
      expect(saved, isNotNull);
      expect(saved!.name, '手输饼干');
      expect(saved.source, FoodSource.label);

      // The saved step ends the add flow: 完成 returns to the food library.
      expect(find.byKey(labelDoneButtonKey), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    },
  );

  testWidgets(
    'manual entry defaults to the display units (kcal + salt) and converts '
    'them into the canonical kcal / mg food',
    (WidgetTester tester) async {
      await pumpFlow(tester);

      await tester.enterText(find.byKey(labelNoteFieldKey), '手动录入的备注');
      await tester.tap(find.byKey(labelManualEntryButtonKey));
      await tester.pumpAndSettle();

      expect(adapter.requests, isEmpty);
      expect(_fieldText(tester, labelNotesFieldKey(0)), '手动录入的备注');

      // The bare test MaterialApp carries the app-default DisplayScope
      // (kcal + salt), so manual entry starts in the user's display units:
      // the energy row types 大卡 and the sodium row is a 盐 row.
      final DropdownButton<EnergyDisplay> energyUnit = tester
          .widget<DropdownButton<EnergyDisplay>>(
            find.byKey(labelEnergyUnitKey(0)),
          );
      expect(energyUnit.value, EnergyDisplay.kcal);
      final DropdownButton<SaltDisplay> saltUnit = tester
          .widget<DropdownButton<SaltDisplay>>(find.byKey(labelSaltUnitKey(0)));
      expect(saltUnit.value, SaltDisplay.salt);
      expect(find.text('盐'), findsOneWidget);

      await tester.enterText(find.byKey(labelNameFieldKey(0)), '手输饼干');
      await tester.enterText(
        find.byKey(labelFieldKey(0, LabelField.energy)),
        '358',
      );
      await tester.enterText(
        find.byKey(labelFieldKey(0, LabelField.sodium)),
        '2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final Food? saved = await repo.getFood('label-food-1');
      expect(saved, isNotNull);
      expect(saved!.name, '手输饼干');
      expect(saved.source, FoodSource.label);
      expect(saved.kcal, 358); // typed 大卡 stays whole kcal
      expect(saved.sodiumMg, 800); // 2 g 盐 × 400 = 800 mg 钠
      expect(saved.notes, isNull);
    },
  );

  testWidgets(
    'switching the energy row to kJ keeps the printed-kilojoule semantics '
    '(418.4 kJ -> 100 kcal)',
    (WidgetTester tester) async {
      await pumpFlow(tester, startManualEntry: true);

      // kcal is the default (display preference); switch the row to kJ first.
      await tester.tap(find.byKey(labelEnergyUnitKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kJ').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(labelNameFieldKey(0)), '手输饼干');
      await tester.enterText(
        find.byKey(labelFieldKey(0, LabelField.energy)),
        '418.4',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final Food? saved = await repo.getFood('label-food-1');
      expect(saved!.kcal, 100); // roundKcal(418.4 / 4.184) = 100
    },
  );

  testWidgets(
    'a photo-confirmed label keeps the printed kJ / mg defaults and a unit '
    'switch round-trips losslessly',
    (WidgetTester tester) async {
      await pumpFlow(
        tester,
        body: _fixtureBody('label_photo_response_multi.json'),
      );
      await pickAndParse(tester);

      // Photo path: the seeded text is the label's printed kJ / mg.
      expect(_fieldText(tester, labelFieldKey(0, LabelField.energy)), '2200');
      expect(_fieldText(tester, labelFieldKey(0, LabelField.sodium)), '500');

      // kJ -> kcal re-derives the whole-kcal text (2200 / 4.184 = 526) and
      // back to kJ restores it exactly: a switch never rewrites the draft.
      await tester.tap(find.byKey(labelEnergyUnitKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kcal').last);
      await tester.pumpAndSettle();
      expect(_fieldText(tester, labelFieldKey(0, LabelField.energy)), '526');
      await tester.tap(find.byKey(labelEnergyUnitKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kJ').last);
      await tester.pumpAndSettle();
      expect(_fieldText(tester, labelFieldKey(0, LabelField.energy)), '2200');

      // mg -> 盐 (500 mg = 1.25 g) and back; the row label follows the unit.
      await tester.tap(find.byKey(labelSaltUnitKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('g').last);
      await tester.pumpAndSettle();
      expect(find.text('盐'), findsOneWidget);
      expect(_fieldText(tester, labelFieldKey(0, LabelField.sodium)), '1.25');
      await tester.tap(find.byKey(labelSaltUnitKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('mg').last);
      await tester.pumpAndSettle();
      expect(_fieldText(tester, labelFieldKey(0, LabelField.sodium)), '500');

      // Saved values are untouched by the switching.
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();
      final Food? chips = await repo.getFood('label-food-1');
      expect(chips!.kcal, 526); // roundKcal(2200 / 4.184) = 526
      expect(chips.sodiumMg, 500);
    },
  );

  testWidgets(
    'model aliases and note-parsed aliases merge into the saved food, deduped',
    (WidgetTester tester) async {
      await pumpFlow(tester);

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(LabelCaptureScreen)),
      );
      container
          .read(labelCaptureControllerProvider.notifier)
          .seedDraft(
            const LabelDraft(
              name: '原味苏打饼干',
              brand: '某品牌',
              // The model's name_aliases: the source-language original plus
              // one duplicate of a note alias and one blank.
              aliases: <String>['Original Soda Crackers', '苏打饼干', ''],
              notes: '别名：小饼干、苏打饼干',
            ),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      final Food? saved = await repo.getFood('label-food-1');
      expect(saved, isNotNull);
      // Model alias wins the duplicate; the blank is dropped; the note's own
      // 别名 join after them in note order.
      expect(saved!.aliases, <String>['Original Soda Crackers', '苏打饼干', '小饼干']);
    },
  );

  testWidgets(
    'D4: leaving and re-opening the label screen starts from pick, never the '
    'stale 已保存 step',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // One container kept alive across both mounts, exactly like the real
      // (non-autoDispose) provider outliving the pushed screen.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          aiClientProvider.overrideWithValue(client),
          labelPhotoSourceProvider.overrideWithValue(
            (LabelPhotoLane lane) async => photo,
          ),
          foodRepositoryProvider.overrideWithValue(repo),
          labelIdGeneratorProvider.overrideWithValue(
            () => 'label-food-${++idCounter}',
          ),
        ],
      );
      addTearDown(container.dispose);

      Widget labelApp() => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LabelCaptureScreen()),
      );

      await tester.pumpWidget(labelApp());
      await tester.pumpAndSettle();

      // Drive the whole flow to the saved step.
      await tester.tap(find.byKey(const Key('label_pick_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_parse_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(labelNameFieldKey(0)), 'TestBiscuit');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      // Sanity: the stale saved step is what the bug leaks on re-entry.
      expect(find.text('已保存：TestBiscuit'), findsOneWidget);

      // Leave: unmount the screen while the provider survives.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold()),
        ),
      );
      await tester.pumpAndSettle();

      // Re-open: a fresh State runs initState -> reset().
      await tester.pumpWidget(labelApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('label_pick_button')), findsOneWidget);
      expect(find.text('已保存：TestBiscuit'), findsNothing);
      expect(find.byKey(const Key('label_save_button')), findsNothing);
      expect(
        container.read(labelCaptureControllerProvider).stage,
        LabelStage.pick,
      );
    },
  );

  testWidgets(
    'the recorded multi-label fixture parses both labels through the schema',
    (WidgetTester tester) async {
      final LabelParse parse = LabelParse.fromToolArguments(
        toolArgumentsFromFixture('label_photo_response_multi.json'),
      );
      expect(parse.labels, hasLength(2));
      expect(parse.labels.first.foodName, '乐事原味薯片');
    },
  );
}
