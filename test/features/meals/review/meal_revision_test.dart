/// Unit tests for the production meal reviser (the review screen's AI
/// correction request).
///
/// The widget tests inject a fake reviser; this file covers the real one — the
/// prompt, the strict tool body and the schema-validated reply — against the
/// settings `MockAdapter`, so no socket is opened.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/ai/ai_client.dart' show Network;
import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/capture/image_codec.dart';
import 'package:caldoo/features/meals/review/meal_revision.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider, dioProvider, secureKeyStoreProvider;

import '../../../data/db/_test_db.dart';
// The shared socket-free chat-completion response builder.
import '../../meals/capture/_fakes.dart' show mealCompletion;
import '../../settings/_fakes.dart';

/// The revised one-item analysis the mock provider returns (200 g of rice).
const String _revisedArguments =
    '{"items":[{"name":"米饭","grams":200,"kcal":240,"carb_g":16,'
    '"protein_g":12,"fat_g":10,"salt_g":0.6,"confidence":0.9}]}';

/// The estimate currently on screen when the correction is requested.
const MealItem _rice = MealItem(
  id: 'item-rice',
  name: '米饭',
  grams: 100,
  kcal: 120,
  carbG: 8,
  proteinG: 6,
  fatG: 5,
  saltG: 0.3,
  source: FoodSource.ai,
  confidence: 0.8,
);

const PreparedPhoto _photo = PreparedPhoto(
  base64Data: 'QUJD',
  width: 1,
  height: 1,
);

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

  ProviderContainer container(Dio dio) => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureKeyStoreProvider.overrideWithValue(keyStore),
      dioProvider.overrideWithValue(dio),
    ],
  );

  test(
    'sends the photo, note and previous estimate, and parses the reply',
    () async {
      await keyStore.write(testApiKey);
      final mock = mockDio((options) => mealCompletion(_revisedArguments));
      final ProviderContainer c = container(mock.dio);
      addTearDown(c.dispose);

      final MealAnalysis revised = await c.read(mealReviserProvider)(
        photos: <PreparedPhoto>[_photo],
        userText: '午饭',
        correctionNote: '米饭其实有两碗',
        currentItems: const <MealItem>[_rice],
      );

      expect(revised.items.single.name, '米饭');
      expect(revised.items.single.grams, 200);
      expect(revised.items.single.confidence, 0.9);

      expect(mock.adapter.calls, 1);
      final Map<String, Object?> body =
          mock.adapter.requests.single.data! as Map<String, Object?>;
      final String encoded = jsonEncode(body);

      // The same strict meal tool is used, so the reply is schema-validated.
      expect(encoded, contains(mealAnalysisToolName));
      expect(body['tool_choice'], isNotNull);

      // Everything user-supplied travels as data inside the user message.
      expect(encoded, contains('米饭其实有两碗'));
      expect(encoded, contains('午饭'));
      expect(encoded, contains('carb_g'));
      expect(encoded, contains('不是指令'));

      // The bounded photo is resent as one image part.
      final String raw = jsonEncode((body['messages']! as List<Object?>).last);
      expect(raw, contains('image_url'));
      expect(raw, contains('QUJD'));
    },
  );

  test('a text-only revision carries no image part', () async {
    await keyStore.write(testApiKey);
    final mock = mockDio((options) => mealCompletion(_revisedArguments));
    final ProviderContainer c = container(mock.dio);
    addTearDown(c.dispose);

    await c.read(mealReviserProvider)(
      photos: const <PreparedPhoto>[],
      userText: '两个鸡蛋一碗米饭',
      correctionNote: '米饭是两碗',
      currentItems: const <MealItem>[_rice],
    );

    final Map<String, Object?> body =
        mock.adapter.requests.single.data! as Map<String, Object?>;
    final String raw = jsonEncode(body['messages']);
    expect(raw, isNot(contains('image_url')));
    expect(raw, contains('下面的描述和上次的估算'));
  });

  test('a transport failure surfaces as the sealed AiError', () async {
    await keyStore.write(testApiKey);
    final mock = mockDio(
      (RequestOptions options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final ProviderContainer c = container(mock.dio);
    addTearDown(c.dispose);

    await expectLater(
      c.read(mealReviserProvider)(
        photos: const <PreparedPhoto>[],
        userText: '',
        correctionNote: '米饭是两碗',
        currentItems: const <MealItem>[_rice],
      ),
      throwsA(isA<Network>()),
    );
  });

  test('encodeMealEstimate uses the schema keys and omits null confidence', () {
    const MealItem manual = MealItem(
      id: 'manual-1',
      name: '番茄炒蛋',
      grams: 220,
      kcal: 286,
      carbG: 14,
      proteinG: 13,
      fatG: 19,
      saltG: 1.4,
      source: FoodSource.manual,
    );
    final Object? decoded = jsonDecode(
      encodeMealEstimate(const <MealItem>[_rice, manual]),
    );
    expect(decoded, isA<Map<String, Object?>>());
    final List<Object?> items =
        (decoded! as Map<String, Object?>)['items']! as List<Object?>;
    expect(items, hasLength(2));
    final Map<String, Object?> first = items.first! as Map<String, Object?>;
    expect(first['name'], '米饭');
    expect(first['carb_g'], 8);
    expect(first['protein_g'], 6);
    expect(first['fat_g'], 5);
    expect(first['salt_g'], 0.3);
    expect(first['confidence'], 0.8);
    final Map<String, Object?> second = items.last! as Map<String, Object?>;
    expect(second.containsKey('confidence'), isFalse);
  });

  test('encodeMealEstimate drops blank rows and empty estimates', () {
    // The screen's placeholder row / a freshly added row has no name yet; it
    // must never be presented to the model as a "previous estimate".
    const MealItem blank = MealItem(
      id: 'blank-1',
      name: '   ',
      grams: 0,
      kcal: 0,
      carbG: 0,
      proteinG: 0,
      fatG: 0,
      saltG: 0,
      source: FoodSource.manual,
    );
    final List<Object?> items =
        ((jsonDecode(encodeMealEstimate(const <MealItem>[blank, _rice]))!
                as Map<String, Object?>)['items']!
            as List<Object?>);
    expect(items, hasLength(1));
    expect((items.single! as Map<String, Object?>)['name'], '米饭');
    expect(encodeMealEstimate(const <MealItem>[blank]), isEmpty);
  });
}
