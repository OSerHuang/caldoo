/// OpenAI-compatible chat client (DeepSeek-verified) with a sealed error
/// taxonomy, plus the verified endpoint constants.
///
/// Values were confirmed by the task-1 spike (2026-09-22) with three real
/// OpenAI-compatible `/chat/completions` calls. Raw response fixtures live in
/// `test/fixtures/ai/` and the transcript in
/// `.omo/evidence/task-1-diet-ai-android.md`.
///
/// Findings that task 14 builds on:
/// * `GET $baseUrl/models` returned exactly `deepseek-flash` and
///   `deepseek-v4-pro`; `deepseek-flash` is the vision-capable id
///   (https://api-docs.deepseek.com/guides/vision).
/// * Vision input works as a base64 `image_url` content part on `model`.
/// * `response_format` accepts only `text` / `json_object`; asking for
///   `json_schema` returns HTTP 400 "This response_format type is unavailable
///   now" on both model ids. Strict, schema-enforced JSON is obtained instead
///   with a tool call (`tools` + `tool_choice`, `function.strict = true`),
///   which the spike verified on the meal photo, text meal and label photo.
///   [AiClient.completeWithTool] implements exactly that mechanism and returns
///   `tool_calls[0].function.arguments` unchanged.
library;

import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:dio/dio.dart';

import '../core/logging/meal_trace.dart';

// verified 2026-09-22 against deepseek-flash (model list + three live calls)
const String baseUrl = 'https://api.deepseek.com';

/// Default vision + text model id; chat completions live at
/// `$baseUrl/chat/completions`.
const String model = 'deepseek-flash';

/// Chat completions path, resolved against the configured base URL.
const String _chatCompletionsPath = 'chat/completions';

/// Dio timeouts: a slow phone network may take a while to flush a multi-MB
/// base64 photo, but a dead connection must not hang the UI forever.
const Duration _connectTimeout = Duration(seconds: 15);
const Duration _sendTimeout = Duration(seconds: 60);
const Duration _receiveTimeout = Duration(seconds: 60);

/// Upper bound on how long a `Retry-After` header may make the single retry
/// wait. The header is honoured, but a hostile/silly value (e.g. 3600 s) must
/// not freeze an interactive meal-logging screen.
const Duration _maxRetryAfter = Duration(seconds: 30);

/// Pause before the opt-in single retry of a transport failure (see
/// [AiClient.completeWithTool]'s `retryNetworkErrors`).
const Duration _networkRetryDelay = Duration(milliseconds: 500);

/// Supplies the current API key, or `null`/blank when none is configured.
///
/// Task 17 backs this with `flutter_secure_storage`. The client never reads,
/// logs, persists or caches anything else, and never stores the value on an
/// [AiError].
typedef ApiKeyProvider = Future<String?> Function();

/// Test seam for the one retry delay. Production uses [Future.delayed].
typedef Sleeper = Future<void> Function(Duration duration);

Future<void> _systemDelay(Duration duration) => Future<void>.delayed(duration);

/// Every failure an AI call can surface, as a sealed taxonomy.
///
/// The client throws (never returns) exactly one of the subtypes, so callers
/// can switch exhaustively:
///
/// ```dart
/// try {
///   final arguments = await client.completeWithTool(...);
/// } on NoKey {
///   // ask the user for a key
/// } on Unauthorized {
///   // the key was rejected
/// } on RateLimited catch (error) {
///   // error.retryAfter
/// } on Timeout {
/// } on Network {
/// } on MalformedResponse {
/// } on Server {
/// }
/// ```
///
/// Security: an error only carries sanitized, static context. The API key is
/// never stored on one and never formatted into [toString] — even when a
/// provider (or a proxy in front of it) echoes request material back in its
/// error body.
sealed class AiError implements Exception {
  const AiError([this.detail]);

  /// Sanitized, human-readable context (provider message, HTTP status, ...).
  /// Never contains the API key.
  final String? detail;

  @override
  String toString() {
    final String? detail = this.detail;
    return detail == null || detail.isEmpty
        ? '$runtimeType'
        : '$runtimeType: $detail';
  }
}

/// No usable key came back from the injected [ApiKeyProvider].
final class NoKey extends AiError {
  const NoKey([super.detail]);
}

/// HTTP 401/403 — the provider rejected the key.
final class Unauthorized extends AiError {
  const Unauthorized([super.detail]);
}

/// HTTP 429 — rate limited or out of quota.
///
/// [retryAfter] is the delay the client honoured before its single retry,
/// parsed from `Retry-After` (seconds or HTTP-date) and capped at 30 s.
final class RateLimited extends AiError {
  const RateLimited({this.retryAfter, String? detail}) : super(detail);

  final Duration? retryAfter;
}

/// Timed out: a Dio connect/send/receive timeout, HTTP 408 or HTTP 504.
final class Timeout extends AiError {
  const Timeout([super.detail]);
}

/// Transport failure: no connection, TLS problem, cancelled request, ...
final class Network extends AiError {
  const Network([super.detail]);
}

/// The provider answered, but with no usable strict tool call: unparseable
/// JSON, missing `choices`/`tool_calls`, or arguments that are not a JSON
/// object. Any other unexpected HTTP status (e.g. the HTTP 400 that DeepSeek
/// returns for `response_format: json_schema`) is classified here too,
/// because the body cannot be a chat completion.
final class MalformedResponse extends AiError {
  const MalformedResponse([super.detail]);
}

/// HTTP 5xx — the provider failed (after the single retry, if any).
final class Server extends AiError {
  const Server(this.statusCode, [String? detail]) : super(detail);

  final int statusCode;
}

/// One part of a chat message: text, or an inline base64 image.
///
/// Text-only and vision requests are the same message model with different
/// parts; the request builder never branches on input type.
sealed class AiPart {
  const AiPart();

  Map<String, Object?> toJson();
}

/// A text content part (`{"type":"text","text":...}`).
final class AiTextPart extends AiPart {
  const AiTextPart(this.text);

  final String text;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'text',
    'text': text,
  };
}

/// An inline image content part
/// (`{"type":"image_url","image_url":{"url":"data:<mime>;base64,<data>"}}`).
final class AiImagePart extends AiPart {
  /// [base64Data] is the raw base64 payload **without** the `data:` prefix;
  /// [toJson] adds it.
  const AiImagePart(this.base64Data, {this.mimeType = 'image/jpeg'});

  /// Encodes raw bytes (e.g. a downscaled JPEG from task 18) as base64.
  factory AiImagePart.bytes(
    List<int> bytes, {
    String mimeType = 'image/jpeg',
  }) => AiImagePart(base64Encode(bytes), mimeType: mimeType);

  final String base64Data;
  final String mimeType;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'image_url',
    'image_url': <String, Object?>{'url': 'data:$mimeType;base64,$base64Data'},
  };
}

/// One chat message: a role plus ordered [parts] (text and/or image).
final class AiMessage {
  const AiMessage({required this.role, required this.parts});

  /// A `user` message from parts.
  factory AiMessage.user(List<AiPart> parts) =>
      AiMessage(role: 'user', parts: parts);

  /// A `system` message with a single text part.
  factory AiMessage.system(String text) =>
      AiMessage(role: 'system', parts: <AiPart>[AiTextPart(text)]);

  final String role;
  final List<AiPart> parts;

  Map<String, Object?> toJson() {
    final AiPart? single = parts.length == 1 ? parts.single : null;
    if (single is AiTextPart) {
      // Verified request shape: a text-only message sends `content` as a
      // plain string; only vision messages send the parts array.
      return <String, Object?>{'role': role, 'content': single.text};
    }
    return <String, Object?>{
      'role': role,
      'content': <Object?>[for (final part in parts) part.toJson()],
    };
  }
}

/// DeepSeek-specific request fields, verified by task 1: thinking mode must be
/// disabled because a named `tool_choice` is unsupported while thinking and
/// thinking can consume the whole `max_tokens` budget (the photo call returned
/// `finish_reason=length` and empty content otherwise). Pass `const {}` for an
/// OpenAI-compatible provider that rejects unknown fields.
const Map<String, Object?> _defaultExtraBody = <String, Object?>{
  'thinking': <String, Object?>{'type': 'disabled'},
};

/// A minimal OpenAI-compatible chat completions client.
///
/// Config is injected (task 17 owns the settings/DI layer): [baseUrl],
/// [model], an [apiKey] provider and an optional [dio] (tests attach a mock
/// adapter). The single public operation, [completeWithTool], sends messages
/// — text and/or base64 `image_url` parts — together with one named strict
/// tool, and returns the model's `tool_calls[0].function.arguments` string.
/// Task 15 validates that string against the JSON schema.
class AiClient {
  /// Creates a client; every input is injected (task 17 owns the
  /// settings/DI layer) and [dio] is replaceable so tests can attach a mock
  /// adapter.
  ///
  /// [apiKey] is the only place the key is ever read from. [sleeper] is a
  /// test seam for the single retry delay (production uses [Future.delayed]),
  /// and [extraBody] replaces the DeepSeek-verified `thinking: disabled`
  /// default (pass `const {}` for a provider that rejects unknown fields).
  factory AiClient({
    required String baseUrl,
    required String model,
    required ApiKeyProvider apiKey,
    Dio? dio,
    Sleeper sleeper = _systemDelay,
    Map<String, Object?> extraBody = _defaultExtraBody,
  }) => AiClient._(baseUrl, model, apiKey, dio ?? Dio(), sleeper, extraBody);

  AiClient._(
    String baseUrl,
    this.model,
    this._apiKey,
    this._dio,
    this._sleeper,
    this._extraBody,
  ) : baseUrl = _withTrailingSlash(baseUrl) {
    final BaseOptions options = _dio.options;
    options.baseUrl = this.baseUrl;
    options.connectTimeout = _connectTimeout;
    options.sendTimeout = _sendTimeout;
    options.receiveTimeout = _receiveTimeout;
    options.responseType = ResponseType.json;
    // Statuses are classified by this client (see [_statusError]) so that
    // 401/429/5xx all flow through [AiError] instead of Dio's generic
    // `badResponse` exception.
    options.validateStatus = (int? _) => true;
  }

  /// Base URL of the OpenAI-compatible endpoint, always with a trailing `/`.
  final String baseUrl;

  /// Model id passed as `model` on every request.
  final String model;

  final ApiKeyProvider _apiKey;
  final Dio _dio;
  final Sleeper _sleeper;
  final Map<String, Object?> _extraBody;

  /// Sends [messages] plus one named strict tool and returns the
  /// `tool_calls[0].function.arguments` JSON string, unchanged.
  ///
  /// The strict tool (`function.strict = true` + named `tool_choice`) is the
  /// mechanism task 1 verified as schema-enforcing on DeepSeek, where
  /// `response_format: json_schema` is rejected with HTTP 400.
  ///
  /// Retries once on HTTP 429 or 5xx, honouring `Retry-After` (seconds or
  /// HTTP-date, capped at 30 s; no header means an immediate retry).
  ///
  /// [retryNetworkErrors] adds the same single retry for transport failures
  /// ([Timeout] / [Network]) after a short pause. It is opt-in because a
  /// genuinely offline device should fail fast instead of waiting out two
  /// timeouts; the analysis call opts in, the label-link enrichment does not.
  ///
  /// Throws an [AiError] subtype on every failure.
  Future<String> completeWithTool({
    required List<AiMessage> messages,
    required String toolName,
    required Map<String, Object?> parameters,
    double temperature = 0,
    int maxTokens = 8192,
    bool retryNetworkErrors = false,
  }) async {
    try {
      return await _completeWithTool(
        messages: messages,
        toolName: toolName,
        parameters: parameters,
        temperature: temperature,
        maxTokens: maxTokens,
        retryNetworkErrors: retryNetworkErrors,
      );
    } on AiError catch (error) {
      mealTrace('ai.error', '${error.runtimeType}: ${error.detail}');
      rethrow;
    }
  }

  Future<String> _completeWithTool({
    required List<AiMessage> messages,
    required String toolName,
    required Map<String, Object?> parameters,
    double temperature = 0,
    int maxTokens = 8192,
    bool retryNetworkErrors = false,
  }) async {
    final String key = await _readApiKey();
    mealTraceJson('ai.request', <String, Object?>{
      'tool': toolName,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'retryNetworkErrors': retryNetworkErrors,
      'paramsChars': jsonEncode(parameters).length,
      'messages': <Object?>[
        for (final AiMessage message in messages)
          <String, Object?>{
            'role': message.role,
            'textChars': message.parts.whereType<AiTextPart>().fold<int>(
              0,
              (int sum, AiTextPart part) => sum + part.text.length,
            ),
            'images': message.parts.whereType<AiImagePart>().length,
          },
      ],
    });
    final Map<String, Object?> body = <String, Object?>{
      ..._extraBody,
      'model': model,
      'messages': <Object?>[
        for (final AiMessage message in messages) message.toJson(),
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      'tools': <Object?>[
        <String, Object?>{
          'type': 'function',
          'function': <String, Object?>{
            'name': toolName,
            'strict': true,
            'parameters': parameters,
          },
        },
      ],
      'tool_choice': <String, Object?>{
        'type': 'function',
        'function': <String, Object?>{'name': toolName},
      },
    };

    Response<Object?> response;
    if (retryNetworkErrors) {
      try {
        response = await _postOnce(body, key);
      } on Timeout {
        mealTrace('ai.retry', 'transport timeout → retry once');
        await _sleeper(_networkRetryDelay);
        response = await _postOnce(body, key);
      } on Network {
        mealTrace('ai.retry', 'transport failure → retry once');
        await _sleeper(_networkRetryDelay);
        response = await _postOnce(body, key);
      }
    } else {
      response = await _postOnce(body, key);
    }
    if (_isRetryable(response.statusCode)) {
      mealTrace('ai.retry', 'HTTP ${response.statusCode} → retry once');
      await _sleeper(_retryAfter(response) ?? Duration.zero);
      response = await _postOnce(body, key);
    }
    final String arguments = _toolArguments(response, key);
    mealTrace(
      'ai.response',
      'tool=$toolName status=${response.statusCode} argsChars=${arguments.length}',
    );
    mealTrace('ai.tool_args', arguments);
    return arguments;
  }

  /// Reads the key from the injected provider only. The value lives exactly as
  /// long as one request and is never logged, cached or persisted.
  Future<String> _readApiKey() async {
    String? key;
    try {
      key = await _apiKey();
    } catch (error) {
      // The provider is a platform channel (secure storage). A storage
      // failure is surfaced as "no key" (actionable: re-enter it) rather than
      // as an opaque platform exception — and never with the value.
      throw NoKey('key provider failed: ${error.runtimeType}');
    }
    if (key == null || key.trim().isEmpty) {
      throw const NoKey();
    }
    return key.trim();
  }

  Future<Response<Object?>> _postOnce(
    Map<String, Object?> body,
    String key,
  ) async {
    try {
      return await _dio.post<Object?>(
        _chatCompletionsPath,
        data: body,
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error, key);
    }
  }

  static bool _isRetryable(int? status) =>
      status == 429 || (status != null && status >= 500 && status < 600);

  /// Honoured `Retry-After` delay, or `null` when absent/unparseable.
  static Duration? _retryAfter(Response<Object?> response) {
    final String? raw = response.headers.value('retry-after');
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final String value = raw.trim();
    final int? seconds = int.tryParse(value);
    if (seconds != null) {
      return _clampRetryAfter(Duration(seconds: seconds));
    }
    try {
      final DateTime target = HttpDate.parse(value);
      final DateTime now = DateTime.now().toUtc();
      return _clampRetryAfter(
        target.isBefore(now) ? Duration.zero : target.difference(now),
      );
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Duration _clampRetryAfter(Duration value) {
    if (value.isNegative) {
      return Duration.zero;
    }
    return value > _maxRetryAfter ? _maxRetryAfter : value;
  }

  /// Extracts and validates `tool_calls[0].function.arguments`.
  static String _toolArguments(Response<Object?> response, String key) {
    final int status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw _statusError(response, key);
    }
    final Object? data = response.data;
    if (data is! Map<String, Object?>) {
      throw const MalformedResponse('response body is not a JSON object');
    }
    final Object? choices = data['choices'];
    if (choices is! List<Object?> || choices.isEmpty) {
      throw const MalformedResponse('response has no choices');
    }
    final Object? firstChoice = choices.first;
    if (firstChoice is! Map<String, Object?>) {
      throw const MalformedResponse('response has no message');
    }
    final Object? message = firstChoice['message'];
    if (message is! Map<String, Object?>) {
      throw const MalformedResponse('response has no message');
    }
    final Object? toolCalls = message['tool_calls'];
    if (toolCalls is! List<Object?> || toolCalls.isEmpty) {
      throw const MalformedResponse('response has no tool_calls');
    }
    final Object? firstCall = toolCalls.first;
    final Object? function = firstCall is Map<String, Object?>
        ? firstCall['function']
        : null;
    if (function is! Map<String, Object?>) {
      throw const MalformedResponse('tool call has no function');
    }
    final Object? arguments = function['arguments'];
    final String raw;
    if (arguments is String) {
      raw = arguments;
    } else if (arguments is Map<String, Object?>) {
      // Tolerated provider quirk: arguments returned as an object instead of
      // a JSON string.
      raw = jsonEncode(arguments);
    } else {
      throw const MalformedResponse('tool call arguments are missing');
    }
    if (raw.trim().isEmpty) {
      throw const MalformedResponse('tool call arguments are empty');
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException(
          'tool call arguments are not a JSON object',
        );
      }
    } on FormatException {
      throw const MalformedResponse('tool call arguments are not valid JSON');
    }
    return raw;
  }

  static AiError _statusError(Response<Object?> response, String key) {
    final int status = response.statusCode ?? 0;
    final String detail = _redact(_statusDetail(response, status), key);
    switch (status) {
      case 401:
      case 403:
        return Unauthorized(detail);
      case 429:
        return RateLimited(retryAfter: _retryAfter(response), detail: detail);
      case 408:
      case 504:
        return Timeout(detail);
      default:
        if (status >= 500) {
          return Server(status, detail);
        }
        return MalformedResponse(detail);
    }
  }

  static String _statusDetail(Response<Object?> response, int status) {
    final Object? data = response.data;
    if (data is Map<String, Object?>) {
      final Object? error = data['error'];
      if (error is Map<String, Object?>) {
        final Object? message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return 'HTTP $status: ${message.trim()}';
        }
      }
    }
    return 'HTTP $status';
  }

  static AiError _mapDioException(DioException error, String key) {
    final String detail = _redact(error.message ?? error.type.name, key);
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return Timeout(detail);
      case DioExceptionType.badResponse:
        final Response<Object?>? response = error.response;
        if (response != null) {
          return _statusError(response, key);
        }
        return Network(detail);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        if (error.error is FormatException) {
          // Dio wraps a jsonDecode failure of the body into `unknown`.
          return const MalformedResponse('response body is not valid JSON');
        }
        return Network(detail);
    }
  }

  /// Defense in depth: even if a provider/proxy echoes the `Authorization`
  /// header into its error body, the key cannot reach a log or an error.
  static String _redact(String value, String key) {
    if (key.isEmpty) {
      return value;
    }
    return value.replaceAll(key, '<redacted>');
  }

  static String _withTrailingSlash(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.endsWith('/')) {
      return trimmed;
    }
    return '$trimmed/';
  }
}
