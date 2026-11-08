/// Shared fakes for the meal-capture tests.
///
/// These keep the widget tests off every platform channel: the picker source
/// is injected, the review router is recorded, and the AI call is served by the
/// settings `MockAdapter` (`../../settings/_fakes.dart`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/domain/models/models.dart' show Food, MealTemplate;
import 'package:caldoo/features/meals/capture/meal_capture_controller.dart';
import 'package:image/image.dart' as image;

import '../../../data/repositories/fake_repositories.dart'
    show FakeFoodRepository;

/// Records the submission the capture screen routes to review instead of
/// pushing the placeholder route, so a test can assert the call count, the
/// parsed draft and the exact capture inputs (photos + text) it carried.
class RecordingReviewRouter {
  RecordingReviewRouter({this.saved});

  /// The result the fake review screen reports: `true` = the meal was saved.
  /// `null` models a review the user left without saving.
  bool? saved;

  CaptureSubmission? submission;
  int calls = 0;

  /// The validated AI draft of the last recorded submission.
  MealAnalysis? get draft => submission?.draft;

  Future<bool?> call(BuildContext context, CaptureSubmission submission) async {
    calls++;
    this.submission = submission;
    return saved;
  }
}

/// Records the template the capture screen routes to review through the
/// 从模版记录 entry, mirroring [RecordingReviewRouter] for the template lane.
class RecordingTemplateRouter {
  RecordingTemplateRouter({this.saved});

  /// The result the fake review screen reports: `true` = the meal was saved.
  bool? saved;

  MealTemplate? template;
  int calls = 0;

  Future<bool?> call(BuildContext context, MealTemplate template) async {
    calls++;
    this.template = template;
    return saved;
  }
}

/// A `MealPhotoSource` fake: returns queued responses in order (`null` models a
/// cancelled pick) and counts how often the lane was invoked.
class FakePhotoSource {
  FakePhotoSource(this._responses);

  final List<Uint8List?> _responses;
  int calls = 0;

  Future<Uint8List?> call() async {
    calls++;
    if (_responses.isEmpty) {
      return null;
    }
    return _responses.removeAt(0);
  }
}

/// Builds a synthetic [width]x[height] frame with photo-like content: a smooth
/// diagonal gradient plus a few flat shapes. It is deliberately NOT max-entropy
/// noise — real photos compress far better than random pixels, so a random
/// probe would inflate the JPEG and make the 1.5 MB budget unrepresentative.
///
/// The gradient is written straight into a typed buffer, so a 4000x3000 probe
/// stays fast enough for a widget test.
image.Image syntheticFrame(int width, int height) {
  final Uint8List bytes = Uint8List(width * height * 3);
  int i = 0;
  for (int y = 0; y < height; y++) {
    final int g = (y * 255) ~/ height;
    for (int x = 0; x < width; x++) {
      final int r = (x * 255) ~/ width;
      bytes[i++] = r;
      bytes[i++] = g;
      bytes[i++] = (r + g) >> 1;
    }
  }
  final image.Image frame = image.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    numChannels: 3,
  );
  image.fillRect(
    frame,
    x1: width ~/ 8,
    y1: height ~/ 8,
    x2: width ~/ 3,
    y2: height ~/ 3,
    color: image.ColorRgb8(220, 30, 30),
  );
  image.fillRect(
    frame,
    x1: width ~/ 2,
    y1: height ~/ 2,
    x2: (width * 4) ~/ 5,
    y2: (height * 4) ~/ 5,
    color: image.ColorRgb8(30, 200, 90),
  );
  image.fillCircle(
    frame,
    x: (width * 3) ~/ 4,
    y: height ~/ 4,
    radius: width ~/ 10,
    color: image.ColorRgb8(40, 60, 230),
  );
  return frame;
}

/// Encodes [frame] as a JPEG so a fake picker can feed the byte lane.
Uint8List jpegBytes(image.Image frame) =>
    Uint8List.fromList(image.encodeJpg(frame, quality: 85));

/// A valid meal-analysis tool-call payload (one item, all required fields).
const String mealArguments =
    '{"items":[{"name":"米饭","grams":150,"kcal":174,"carb_g":38.7,'
    '"protein_g":3.2,"fat_g":0.5,"salt_g":0.1,"confidence":0.8}]}';

/// Serializes [body] into a Dio [ResponseBody] with a JSON content type.
ResponseBody jsonBody(Object? body, int status) => ResponseBody.fromString(
  body is String ? body : jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

/// A catalogue whose read always fails, to prove the analysis submit never
/// depends on it: the meal must still reach the AI (and never fail) when the
/// database is unavailable.
class ThrowingFoodRepository extends FakeFoodRepository {
  @override
  Future<List<Food>> getAllFoods() async {
    throw StateError('saved-food catalogue unavailable');
  }
}

/// A 200 chat completion carrying one strict tool call with [arguments].
ResponseBody mealCompletion(String arguments) => jsonBody(<String, Object?>{
  'id': 'chatcmpl-test',
  'object': 'chat.completion',
  'created': 0,
  'model': 'test-model',
  'choices': <Object?>[
    <String, Object?>{
      'index': 0,
      'message': <String, Object?>{
        'role': 'assistant',
        'content': '',
        'tool_calls': <Object?>[
          <String, Object?>{
            'index': 0,
            'id': 'call_test',
            'type': 'function',
            'function': <String, Object?>{
              'name': 'emit_meal_items',
              'arguments': arguments,
            },
          },
        ],
      },
    },
  ],
}, 200);
