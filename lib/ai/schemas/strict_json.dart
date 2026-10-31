/// Strict decoding and JSON-Schema validation of one strict tool call's
/// `arguments` payload.
///
/// Task 1 proved that DeepSeek rejects `response_format: json_schema` (HTTP
/// 400) and that schema-enforced JSON is obtained through a strict tool call
/// (`tools[].function.strict = true` + a named `tool_choice`). The provider
/// therefore returns `tool_calls[0].function.arguments` as a JSON *string*
/// (see `AiClient.completeWithTool`), and this library turns that string into
/// typed models in four ordered steps:
///
/// 1. [decodeToolArguments] — the string must be valid JSON and a JSON object;
/// 2. [validateToolArguments] — the object must satisfy the authored schema.
///    [lenientSchema] strips `additionalProperties` first: the schema *sent to
///    the model* forbids extras so the provider cannot drift, but a single
///    unknown key on the way back must not invalidate a whole valid analysis
///    (the plan's "TOLERATE extra/unknown keys" rule);
/// 3. [rejectNonFiniteNumbers] — `1e999` decodes to `Infinity`, which no JSON
///    Schema keyword can catch (JSON has no "finite" keyword) and which would
///    silently poison every derived day total;
/// 4. [reportUnknownKeys] — extras are ignored *and logged*, never thrown.
///
/// Every failure is an [AiError.MalformedResponse], so callers of
/// `MealAnalysis.fromToolArguments` / `LabelParse.fromToolArguments` keep
/// switching exhaustively over the sealed `AiError` taxonomy.
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:json_schema/json_schema.dart';

import '../ai_client.dart';

/// Sink for keys that were present in the model payload but not declared in
/// the schema. Ignoring them is correct; *seeing* them is how we notice a
/// provider or prompt regression, so every ignored key is reported.
typedef IgnoredKeySink = void Function(String path);

/// Default [IgnoredKeySink]: emits one `dart:developer` log line per key.
///
/// `dart:developer` (not `print`) keeps this out of release console spam while
/// staying visible in the Flutter DevTools log pane.
void debugLogIgnoredKey(String path) {
  developer.log('ignoring unknown key: $path', name: 'ai.schemas');
}

/// Decodes a strict tool call's `arguments` string into a JSON object.
///
/// [argumentsJson] is exactly what `AiClient.completeWithTool` returns and is
/// NOT the whole chat-completion body. Throws [MalformedResponse] when the
/// string is not JSON, or when it decodes to anything but an object.
Map<String, dynamic> decodeToolArguments(
  String argumentsJson,
  String schemaName,
) {
  if (argumentsJson.trim().isEmpty) {
    throw MalformedResponse('$schemaName: tool arguments are empty');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(argumentsJson);
  } on FormatException {
    // Truncated / non-JSON output: the QA failure path of task 15.
    throw MalformedResponse('$schemaName: tool arguments are not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw MalformedResponse(
      '$schemaName: tool arguments are not a JSON object',
    );
  }
  return decoded;
}

/// Validates [data] against [schema], throwing [MalformedResponse] with the
/// first violation.
///
/// [schema] must be the [lenientSchema] copy of the tool schema, so unknown
/// keys are tolerated here (and logged by [reportUnknownKeys] instead).
void validateToolArguments(
  Map<String, dynamic> data,
  JsonSchema schema,
  String schemaName,
) {
  final ValidationResults results = schema.validate(data);
  if (results.isValid) {
    return;
  }
  final ValidationError first = results.errors.first;
  final String at = first.instancePath.isEmpty ? '(root)' : first.instancePath;
  throw MalformedResponse('$schemaName: $at ${first.message}');
}

/// Rejects `Infinity` / `NaN` anywhere in [data] with [MalformedResponse].
///
/// JSON has no "finite" schema keyword, and `jsonDecode('1e999')` yields
/// `double.infinity`, which passes every `type: number` check and then breaks
/// the non-negative/finite contract of `core/units/nutrition_units.dart`.
void rejectNonFiniteNumbers(Object? data, String schemaName) {
  if (data is num) {
    if (data is double && !data.isFinite) {
      throw MalformedResponse('$schemaName: non-finite number');
    }
    return;
  }
  if (data is Map<String, Object?>) {
    for (final MapEntry<String, Object?> entry in data.entries) {
      rejectNonFiniteNumbers(entry.value, schemaName);
    }
    return;
  }
  if (data is List<Object?>) {
    for (final Object? value in data) {
      rejectNonFiniteNumbers(value, schemaName);
    }
  }
}

/// A deep copy of [strict] with every `additionalProperties` keyword removed.
///
/// The tool schema sent to the model keeps `additionalProperties: false` so
/// the provider emits exactly the declared fields; local validation uses this
/// copy so an unexpected key is logged and dropped instead of rejecting an
/// otherwise complete analysis. Built from the same authored schema, so the
/// two can never drift apart.
Map<String, Object?> lenientSchema(Map<String, Object?> strict) {
  final Map<String, Object?> copy = <String, Object?>{};
  for (final MapEntry<String, Object?> entry in strict.entries) {
    if (entry.key == 'additionalProperties') {
      continue;
    }
    copy[entry.key] = _lenientValue(entry.value);
  }
  return copy;
}

Object? _lenientValue(Object? value) {
  if (value is Map<String, Object?>) {
    return lenientSchema(value);
  }
  if (value is List<Object?>) {
    return <Object?>[for (final Object? item in value) _lenientValue(item)];
  }
  return value;
}

/// Reports every key in [data] that [schema] does not declare under
/// `properties`, without failing.
///
/// [path] is the JSON pointer-ish location used in the report (`items[0]`),
/// and [onUnknown] receives the full path of each unknown key. Unknown
/// subtrees are not descended into — one log line per unknown key is enough.
void reportUnknownKeys(
  Object? data,
  Map<String, Object?> schema,
  String path,
  IgnoredKeySink onUnknown,
) {
  final Object? properties = schema['properties'];
  final Object? items = schema['items'];
  if (data is Map<String, Object?> && properties is Map<String, Object?>) {
    for (final MapEntry<String, Object?> entry in data.entries) {
      final String childPath = path.isEmpty ? entry.key : '$path.${entry.key}';
      if (!properties.containsKey(entry.key)) {
        onUnknown(childPath);
        continue;
      }
      final Object? childSchema = properties[entry.key];
      if (childSchema is Map<String, Object?>) {
        reportUnknownKeys(entry.value, childSchema, childPath, onUnknown);
      }
    }
    return;
  }
  if (data is List<Object?> && items is Map<String, Object?>) {
    for (int i = 0; i < data.length; i++) {
      reportUnknownKeys(data[i], items, '$path[$i]', onUnknown);
    }
  }
}
