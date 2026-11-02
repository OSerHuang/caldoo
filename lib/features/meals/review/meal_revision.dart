/// The AI re-estimation seam for the review screen.
///
/// When the user says the recognition is wrong, the review screen resends the
/// original bounded photos (or the original text for a text-only meal) together
/// with the current editable estimate and the user's correction, and asks the
/// model for a **complete** corrected meal. The call reuses the strict meal tool
/// ([mealAnalysisToolName]) and the task-15 schema, so a revised answer is
/// validated exactly like a first-pass analysis.
///
/// It is an injectable function ([mealReviserProvider]) rather than logic
/// inside the widget, for two reasons:
/// * the widget tests drive it without a socket, and
/// * the production wiring stays next to the prompt it renders.
///
/// The revision prompt is self-contained: like the capture prompts it carries
/// no saved-food library data (label matching is a separate link call). The
/// revision only re-estimates the meal.
///
/// A failure surfaces as the usual sealed [AiError] (network, key, malformed
/// response, ...); the review screen shows it reactively and keeps the current
/// draft, so a failed re-estimation never loses the user's meal.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/ai/prompts/prompts.dart';
import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/capture/image_codec.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show aiClientProvider, aiSettingsConfigProvider;

/// Re-runs the meal analysis with a user correction.
///
/// [photos] are the already-bounded capture photos (empty for a text-only
/// meal), [userText] is the original capture description, [correctionNote] is
/// the supplementary text the user typed on the review screen, and
/// [currentItems] is the estimate currently on screen (manual edits included).
///
/// Throws the client's sealed [AiError] subtype for a failed AI call. A prompt
/// precondition failure (`ArgumentError`) can also escape, which is why the
/// review screen handles non-AI failures too instead of only [AiError].
typedef MealReviser = Future<MealAnalysis> Function({
  required List<PreparedPhoto> photos,
  required String userText,
  required String correctionNote,
  required List<MealItem> currentItems,
});

/// The production reviser: renders [mealRevisionPrompt], sends the same bounded
/// photos through the task-14 client, and validates the reply with the task-15
/// schema.
///
/// The client is read lazily on every call, so a settings change made while a
/// review screen is open applies to the next re-estimation.
final mealReviserProvider = Provider<MealReviser>((ref) {
  return ({
    required List<PreparedPhoto> photos,
    required String userText,
    required String correctionNote,
    required List<MealItem> currentItems,
  }) async {
    // Cold-start guard: build the client against the loaded saved config, not
    // the defaults, or the request would carry the user's key to the default
    // endpoint (same guard as saveAndTestConnection).
    await ref.read(aiSettingsConfigProvider.future);
    final AiClient client = ref.read(aiClientProvider);
    final PromptTemplate prompt = mealRevisionPrompt(
      photoCount: photos.length,
      userText: userText,
      previousEstimateJson: encodeMealEstimate(currentItems),
      correctionNote: correctionNote,
    );
    final String arguments = await client.completeWithTool(
      messages: prompt.toMessages(
        images: <AiImagePart>[
          for (final PreparedPhoto photo in photos)
            AiImagePart(photo.base64Data, mimeType: photo.mimeType),
        ],
      ),
      toolName: mealAnalysisToolName,
      parameters: mealAnalysisToolParameters,
      // Same one-shot network retry as the capture analysis: a revision is a
      // full analysis request, and a blip should not force a manual retry.
      retryNetworkErrors: true,
    );
    return MealAnalysis.fromToolArguments(arguments);
  };
});

/// Serializes [items] in the meal-analysis JSON shape (the tool schema's own
/// keys), so the model can align a revision with the estimate on screen.
///
/// It is data, not a request: the prompt labels the block as reference
/// material the model must not treat as instructions.
///
/// Blank-named rows (the placeholder added for a degraded draft, a freshly
/// added empty row) are dropped: telling the model about a nameless 0-gram
/// "previous estimate" would invite it to invent that food. An estimate with
/// no named rows serializes to an empty string, and the prompt then omits the
/// block entirely.
String encodeMealEstimate(List<MealItem> items) {
  final List<MealItem> named = <MealItem>[
    for (final MealItem item in items)
      if (item.name.trim().isNotEmpty) item,
  ];
  if (named.isEmpty) {
    return '';
  }
  return jsonEncode(<String, Object?>{
    'items': <Object?>[
      for (final MealItem item in named)
        <String, Object?>{
          'name': item.name,
          'grams': item.grams,
          'kcal': item.kcal,
          'carb_g': item.carbG,
          'protein_g': item.proteinG,
          'fat_g': item.fatG,
          'salt_g': item.saltG,
          if (item.confidence != null) 'confidence': item.confidence,
        },
    ],
  });
}
