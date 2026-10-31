/// A versioned prompt pair: one zh-CN system message plus one zh-CN user
/// message, ready to be sent through `AiClient.completeWithTool`.
///
/// Every template in `lib/ai/prompts/` is built from this type, so a recorded
/// fixture (task 16) can always be traced back to the exact prompt version
/// that produced it: the `version` string is stamped into the evidence and
/// asserted by `test/ai/prompts/`.
library;

import '../ai_client.dart';

/// One immutable prompt template.
///
/// [id] names the mode (`meal_photo`, `meal_text`, `meal_revision`,
/// `label_photo`), [version]
/// is the exported `*PromptVersion` constant, and [system]/[user] are the
/// rendered zh-CN strings. Rendering happens in the factory functions (they
/// interpolate the user's text/photo count); this class only carries the
/// result and turns it into [AiMessage]s.
class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.version,
    required this.system,
    required this.user,
  });

  /// Stable mode id, also used as the fixture-name stem (`meal_photo`).
  final String id;

  /// Version of the prompt that produced this render, e.g.
  /// `meal-photo/2026-09-22.1`.
  final String version;

  /// The system message (role `system`).
  final String system;

  /// The user message text (role `user`); image parts are appended by
  /// [toMessages].
  final String user;

  /// Builds the two chat messages for this prompt.
  ///
  /// [images] become `image_url` parts *after* the user text, the order the
  /// task-1 spike verified. Text-only modes pass none and get the plain-string
  /// `content` shape.
  List<AiMessage> toMessages({
    List<AiImagePart> images = const <AiImagePart>[],
  }) {
    final List<AiPart> parts = <AiPart>[AiTextPart(user), ...images];
    return <AiMessage>[AiMessage.system(system), AiMessage.user(parts)];
  }
}
