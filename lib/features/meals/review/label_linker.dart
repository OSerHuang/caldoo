/// The background **link** call of the analyze-then-link design.
///
/// The analysis call no longer sees the saved-food library. For a **text**
/// capture, this call matches the analysed items against the library:
///
/// * input: the analysed items (name + grams), the user's original text, and a
///   compact index of saved labels (`renderLabelIndex`);
/// * output: `#food_index` picks per item — never nutrition, never free-form
///   names — validated against the real catalogue by
///   `normalizeLabelMatches`;
/// * it never sends the photos and the returned candidates are **not**
///   binding: the review screen decides whether to auto-apply, and the user can
///   undo / switch at any time.
///
/// A **photo** capture never calls it: a photographed dish usually has no saved
/// label behind it, so matching would replace a good AI estimate with an
/// unrelated food; photo rows stay prediction-only (design §17).
///
/// The provider is a seam so widget tests can inject a fake linker instead of
/// hitting the network. Failures are the caller's business: the review screen
/// treats any exception as "no link result" and keeps the AI estimate.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/ai/prompts/label_link_prompt.dart';
import 'package:caldoo/ai/prompts/prompt_template.dart';
import 'package:caldoo/ai/schemas/label_link.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_linking.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show aiClientProvider, aiSettingsConfigProvider;

/// Matches [items] against [foods]; [userText] is the capture text (non-empty
/// in production: only a text capture ever calls this linker).
///
/// Throws the client's sealed [AiError] on a failed call; the caller treats
/// every failure as "no matches" rather than blocking the review.
typedef LabelLinker = Future<LabelLinkResult> Function({
  required List<MealItem> items,
  required List<Food> foods,
  required String userText,
});

/// Production linker: renders the index + prompt, calls the model's strict
/// tool, and normalises the answer against the real catalogue.
final Provider<LabelLinker> labelLinkerProvider = Provider<LabelLinker>((ref) {
  return ({
    required List<MealItem> items,
    required List<Food> foods,
    required String userText,
  }) async {
    if (items.isEmpty || foods.isEmpty) {
      return const LabelLinkResult(matches: <LabelMatch>[]);
    }
    final String index = renderLabelIndex(foods);
    if (index.isEmpty) {
      return const LabelLinkResult(matches: <LabelMatch>[]);
    }
    final PromptTemplate prompt = labelLinkPrompt(
      foodIndex: index,
      items: <({String name, double grams})>[
        for (final MealItem item in items) (name: item.name, grams: item.grams),
      ],
      userText: userText,
    );
    // Cold-start guard: the client must be built against the loaded saved
    // config, not the defaults, or the request would carry the user's key to
    // the default endpoint (same guard as saveAndTestConnection).
    await ref.read(aiSettingsConfigProvider.future);
    final String arguments = await ref
        .read(aiClientProvider)
        .completeWithTool(
          messages: prompt.toMessages(),
          toolName: labelLinkToolName,
          parameters: labelLinkToolParameters,
          maxTokens: 2048,
        );
    final LabelLinkResult parsed = LabelLinkResult.fromToolArguments(arguments);
    return LabelLinkResult(
      matches: normalizeLabelMatches(
        matches: parsed.matches,
        itemCount: items.length,
        foods: foods,
      ),
    );
  };
});
