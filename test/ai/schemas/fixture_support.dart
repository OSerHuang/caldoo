import 'dart:convert';
import 'dart:io';

/// Loads a recorded raw chat-completion fixture from `test/fixtures/ai/` and
/// returns the strict tool call's `arguments` string — exactly the value
/// `AiClient.completeWithTool` returns in production.
///
/// This mirrors the production extraction path
/// (`choices[0].message.tool_calls[0].function.arguments`) and fails loudly
/// when the fixture is not a tool-call response, so a re-recorded fixture
/// (task 16) that forgets `tool_calls` is reported as a fixture problem rather
/// than looking like a schema failure.
String toolArgumentsFromFixture(String fileName) {
  final String path = 'test/fixtures/ai/$fileName';
  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('$path: fixture is not a JSON object');
  }
  final Object? choices = decoded['choices'];
  if (choices is! List<dynamic> || choices.isEmpty) {
    throw StateError('$path: fixture has no choices');
  }
  final Object? firstChoice = choices.first;
  final Object? message = firstChoice is Map<String, dynamic>
      ? firstChoice['message']
      : null;
  final Object? toolCalls = message is Map<String, dynamic>
      ? message['tool_calls']
      : null;
  if (toolCalls is! List<dynamic> || toolCalls.isEmpty) {
    throw StateError('$path: fixture has no tool_calls');
  }
  final Object? firstCall = toolCalls.first;
  final Object? function = firstCall is Map<String, dynamic>
      ? firstCall['function']
      : null;
  final Object? arguments = function is Map<String, dynamic>
      ? function['arguments']
      : null;
  if (arguments is! String) {
    throw StateError('$path: tool call has no arguments string');
  }
  return arguments;
}
