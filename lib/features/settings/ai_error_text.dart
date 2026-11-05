/// User-facing text for the sealed [AiError] taxonomy.
///
/// Lives outside the screens so every AI-failure surface — the settings form's
/// 测试连接 outcome, the meal-capture offline banner and the label-capture
/// correction path — renders exactly the same words for the same failure.
library;

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// User-facing message for each [AiError] subtype (exhaustive over the
/// sealed taxonomy). Details may contain provider text but never the key.
String describeAiError(AiError error) => switch (error) {
  NoKey() => S.instance.errorNoKey,
  Unauthorized() => S.instance.errorUnauthorized,
  RateLimited() => S.instance.errorRateLimited,
  Timeout() => S.instance.errorTimeout,
  Network() => S.instance.errorNetwork,
  MalformedResponse() => S.instance.errorMalformedResponse,
  Server() => S.instance.errorServer(error.statusCode),
  Unknown() => S.instance.errorUnknown,
};
