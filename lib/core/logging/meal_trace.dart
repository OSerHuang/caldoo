/// Lightweight tracing for the meal AI pipeline (analysis → label link → save).
///
/// Purpose: make one real run (e.g. typing 「两片 Emmental 奶酪片」) diagnosable
/// from the device log — which prompt went out, exactly what the model
/// answered, how the answer was normalised, and which grams each path
/// produced. Every call site logs summaries only: the API key is never passed
/// here, and image bytes are logged as a count, never as base64.
///
/// Enabled by default so a plain `flutter run` (or `adb logcat -s flutter`)
/// shows the traffic. Silence it with `--dart-define=MEAL_TRACE=false`.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Whether [mealTrace] emits anything.
///
/// `--dart-define=MEAL_TRACE=true|false` overrides the default; on by default
/// so a normal debug run needs no extra flags.
const bool kMealTraceEnabled = bool.fromEnvironment(
  'MEAL_TRACE',
  defaultValue: true,
);

const JsonEncoder _json = JsonEncoder.withIndent('  ');

/// Emits one `[MealTrace][tag] …` line, clipped so a runaway payload cannot
/// flood logcat (the full length is reported in the clip marker).
void mealTrace(String tag, Object? message) {
  if (!kMealTraceEnabled) {
    return;
  }
  final String text = message is String ? message : _encode(message);
  final String clipped = text.length <= 6000
      ? text
      : '${text.substring(0, 6000)}…[truncated, ${text.length} chars]';
  debugPrint('[MealTrace][$tag] $clipped');
}

/// Emits one pretty-printed JSON map/list under `[MealTrace][tag]`.
void mealTraceJson(String tag, Object? value) {
  if (!kMealTraceEnabled) {
    return;
  }
  mealTrace(tag, _encode(value));
}

String _encode(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  try {
    return _json.convert(value);
  } on Object {
    return value.toString();
  }
}
