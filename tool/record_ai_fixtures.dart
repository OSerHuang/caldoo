/// Re-records the canonical AI fixtures from the FINAL production prompts,
/// using the production [AiClient] strict-tool mechanism. The label mode now
/// returns every label found in one photo (`labels` array), so its fixture is
/// a multi-label-capable envelope even when the sample photo has one table.
///
/// Usage (the key is read from the environment only — never printed, never
/// written to a file):
///
/// ```console
/// $ set -a; . ./.env.local; set +a
/// $ dart run tool/record_ai_fixtures.dart            # all three modes
/// $ dart run tool/record_ai_fixtures.dart meal_text  # a single mode
/// ```
///
/// One live `POST /chat/completions` call is made per mode. The raw provider
/// body is captured through a Dio response interceptor (the decoded provider
/// JSON, re-encoded losslessly) and written to
/// `test/fixtures/ai/<mode>_response.json` **only after** the production
/// parser accepts the tool arguments, so a bad recording never replaces a good
/// fixture. The script refuses to write a body that contains the key.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:dio/dio.dart';
import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/ai/prompts/prompts.dart';
import 'package:caldoo/ai/schemas/label_parse.dart';
import 'package:caldoo/ai/schemas/meal_analysis.dart';

const String _fixtureDir = 'test/fixtures/ai';
const String _sampleDir = 'test/fixtures/ai/samples';
const List<String> _allModes = <String>[
  'meal_photo',
  'meal_text',
  'label_photo',
];

/// The text-mode sample meal (same operator sentence the task-1 spike used, so
/// the re-recorded fixture stays comparable).
const String _mealTextSample = '两个鸡蛋、一碗米饭（约150克）';

/// Result of running the production parser over the recorded arguments.
typedef _ParseSummary = ({int items, int exactDuplicates, String detail});

Future<void> main(List<String> args) async {
  final String? rawKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (rawKey == null || rawKey.trim().isEmpty) {
    stderr.writeln(
      'DEEPSEEK_API_KEY is not set; run: set -a; . ./.env.local; set +a',
    );
    exitCode = 2;
    return;
  }
  final String key = rawKey.trim();
  final List<String> modes = args.isEmpty ? _allModes : args;
  for (final String mode in modes) {
    if (!_allModes.contains(mode)) {
      stderr.writeln('unknown mode "$mode"; expected one of $_allModes');
      exitCode = 64;
      return;
    }
  }

  int failures = 0;
  for (final String mode in modes) {
    try {
      await _record(mode, key);
    } on AiError catch (error) {
      // AiError.toString() is sanitized (the client redacts the key).
      stderr.writeln('[$mode] FAILED: $error');
      failures++;
    } on Object catch (error) {
      stderr.writeln('[$mode] FAILED: ${error.runtimeType}: $error');
      failures++;
    }
  }
  if (failures > 0) {
    exitCode = 1;
  }
}

Future<void> _record(String mode, String key) async {
  final PromptTemplate prompt;
  final List<AiMessage> messages;
  final String toolName;
  final Map<String, Object?> parameters;
  final _ParseSummary Function(String arguments) parse;

  switch (mode) {
    case 'meal_photo':
      prompt = mealPhotoPrompt();
      final List<int> bytes = File('$_sampleDir/meal_photo.jpg')
          .readAsBytesSync();
      messages = prompt.toMessages(
        images: <AiImagePart>[AiImagePart.bytes(bytes)],
      );
      toolName = mealAnalysisToolName;
      parameters = mealAnalysisToolParameters;
      parse = _parseMeal;
    case 'meal_text':
      prompt = mealTextPrompt(userText: _mealTextSample);
      messages = prompt.toMessages();
      toolName = mealAnalysisToolName;
      parameters = mealAnalysisToolParameters;
      parse = _parseMeal;
    case 'label_photo':
      prompt = labelPhotoPrompt();
      final List<int> bytes = File('$_sampleDir/nutrition_label.jpg')
          .readAsBytesSync();
      messages = prompt.toMessages(
        images: <AiImagePart>[AiImagePart.bytes(bytes)],
      );
      toolName = labelParseToolName;
      parameters = labelParseToolParameters;
      parse = _parseLabel;
    default:
      throw ArgumentError.value(mode, 'mode');
  }

  // Capture the raw provider response without touching the client: the Dio
  // interceptor sees every attempt (the client may retry once on 429/5xx).
  final List<Response<Object?>> captured = <Response<Object?>>[];
  final Dio dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse:
          (Response<Object?> response, ResponseInterceptorHandler handler) {
            captured.add(response);
            handler.next(response);
          },
    ),
  );
  final AiClient client = AiClient(
    baseUrl: baseUrl,
    model: model,
    apiKey: () async => key,
    dio: dio,
  );

  final Stopwatch stopwatch = Stopwatch()..start();
  final String arguments = await client.completeWithTool(
    messages: messages,
    toolName: toolName,
    parameters: parameters,
  );
  stopwatch.stop();

  final Response<Object?> response = captured.last;
  final int status = response.statusCode ?? 0;
  if (status != 200) {
    throw StateError(
      'HTTP $status from provider (attempts: ${captured.length})',
    );
  }
  final Object? data = response.data;
  if (data is! Map<String, Object?>) {
    throw StateError('provider body is not a JSON object');
  }
  final String body = jsonEncode(data);
  if (body.contains(key)) {
    throw StateError('refusing to write a fixture containing the key');
  }
  _assertStrictToolCall(data, toolName);

  final _ParseSummary parsed = parse(arguments);
  final String fixturePath = '$_fixtureDir/${mode}_response.json';
  File(fixturePath).writeAsStringSync('$body\n');

  final Object? finishReason = _finishReason(data);
  stdout.writeln(
    jsonEncode(<String, Object?>{
      'mode': mode,
      'fixture': fixturePath,
      'prompt_id': prompt.id,
      'prompt_version': prompt.version,
      'prompt_system_chars': prompt.system.length,
      'prompt_user_chars': prompt.user.length,
      'tool_name': toolName,
      'http_status': status,
      'attempts': captured.length,
      'elapsed_ms': stopwatch.elapsedMilliseconds,
      'finish_reason': finishReason,
      'arguments_chars': arguments.length,
      'items': parsed.items,
      'exact_duplicate_items': parsed.exactDuplicates,
      'parsed_first_item': parsed.detail,
    }),
  );
  stdout.writeln(
    'RAW_TOOL_CALL_ARGUMENTS_HEAD: '
    '${arguments.substring(0, min(400, arguments.length))}',
  );
}

/// Confirms the captured body really is a strict tool-call completion.
void _assertStrictToolCall(Map<String, Object?> data, String toolName) {
  final Object? choices = data['choices'];
  if (choices is! List<Object?> || choices.isEmpty) {
    throw StateError('body has no choices');
  }
  final Object? first = choices.first;
  final Object? message = first is Map<String, Object?>
      ? first['message']
      : null;
  final Object? toolCalls = message is Map<String, Object?>
      ? message['tool_calls']
      : null;
  if (toolCalls is! List<Object?> || toolCalls.isEmpty) {
    throw StateError('body has no tool_calls (not a strict tool call)');
  }
  final Object? call = toolCalls.first;
  final Object? function = call is Map<String, Object?>
      ? call['function']
      : null;
  final Object? name = function is Map<String, Object?>
      ? function['name']
      : null;
  if (name != toolName) {
    throw StateError('tool call name is "$name", expected "$toolName"');
  }
}

Object? _finishReason(Map<String, Object?> data) {
  final Object? choices = data['choices'];
  if (choices is List<Object?> && choices.isNotEmpty) {
    final Object? first = choices.first;
    if (first is Map<String, Object?>) {
      return first['finish_reason'];
    }
  }
  return null;
}

_ParseSummary _parseMeal(String arguments) {
  final MealAnalysis analysis = MealAnalysis.fromToolArguments(arguments);
  final Map<String, int> counts = <String, int>{};
  for (final MealAnalysisItem item in analysis.items) {
    final String key = '${item.name}|${item.grams}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final int duplicates = counts.values
      .where((int count) => count > 1)
      .fold<int>(0, (int sum, int count) => sum + count - 1);
  return (
    items: analysis.items.length,
    exactDuplicates: duplicates,
    detail: jsonEncode(analysis.items.first.toJson()),
  );
}

_ParseSummary _parseLabel(String arguments) {
  final LabelParse label = LabelParse.fromToolArguments(arguments);
  return (items: 0, exactDuplicates: 0, detail: jsonEncode(label.toJson()));
}
