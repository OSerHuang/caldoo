/// The ranked saved-food candidate list shown on an AI meal row.
///
/// One [FoodSuggestionList] renders the best candidate as a non-blocking
/// [LabelSuggestionBanner] and the remaining candidates as compact chips, so a
/// generic AI name (「牛奶」) can still be linked to the right saved label
/// (「光明 全脂牛奶」) without hiding the alternatives — e.g. two brands of the
/// same 纯牛奶.
///
/// Nothing here applies a food: every entry routes the user's explicit tap
/// through [onApply]. The non-binding rule of the label-priority design is
/// unchanged — this widget is the **lexical fallback** now that the
/// analyze-then-link call owns matching; the auto-applied match (with undo) is
/// rendered by `LabelLinkRow` on the review row, never here.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'label_suggestion_banner.dart';

/// Key of the alternative-candidate chip for [foodId].
Key foodSuggestionChipKey(String foodId) => Key('food_suggestion_chip_$foodId');

/// The banner title for [suggestion]: exact-name and similar matches read
/// differently, and both name the food (plus brand) so candidates are
/// distinguishable.
String foodSuggestionMessage(BuildContext context, FoodSuggestion suggestion) {
  final S strings = S.of(context);
  final String label = strings.foodLabelWithBrand(
    suggestion.food.name,
    suggestion.food.brand,
  );
  return suggestion.reason == FoodMatchReason.exactName
      ? strings.suggestionBannerExactMessage(label)
      : strings.suggestionBannerSimilarMessage(label);
}

/// The "why this candidate" line for [suggestion].
String foodSuggestionReason(BuildContext context, FoodSuggestion suggestion) {
  final S strings = S.of(context);
  return switch (suggestion.reason) {
    FoodMatchReason.exactName => strings.suggestionReasonExactName,
    FoodMatchReason.alias => _aliasReason(strings, suggestion.matchedAlias),
    FoodMatchReason.partialName => strings.suggestionReasonPartialName,
    FoodMatchReason.similarName => strings.suggestionReasonSimilarName,
  };
}

String _aliasReason(S strings, String? alias) {
  final String? trimmed = alias?.trim();
  return trimmed == null || trimmed.isEmpty
      ? strings.suggestionReasonAliasPlain
      : strings.suggestionReasonAlias(trimmed);
}

/// Renders [suggestions] (best first) and reports the tapped food via [onApply].
///
/// An empty list renders nothing, so a caller can embed this unconditionally.
class FoodSuggestionList extends StatelessWidget {
  const FoodSuggestionList({
    super.key,
    required this.suggestions,
    required this.onApply,
  });

  /// Ranked, non-binding candidates from `suggestSavedFood`.
  final List<FoodSuggestion> suggestions;

  /// Called with the explicitly tapped candidate's food.
  final ValueChanged<Food> onApply;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final FoodSuggestion first = suggestions.first;
    final List<FoodSuggestion> rest = suggestions.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LabelSuggestionBanner(
          suggestion: first,
          title: foodSuggestionMessage(context, first),
          reasonLabel: foodSuggestionReason(context, first),
          onApply: () => onApply(first.food),
        ),
        if (rest.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            S.of(context).otherSuggestions,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final FoodSuggestion candidate in rest)
                Tooltip(
                  message: foodSuggestionReason(context, candidate),
                  child: ActionChip(
                    key: foodSuggestionChipKey(candidate.food.id),
                    label: Text(
                      S
                          .of(context)
                          .foodLabelWithBrand(
                            candidate.food.name,
                            candidate.food.brand,
                          ),
                    ),
                    onPressed: () => onApply(candidate.food),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
