/// The non-blocking "库内已有/相近，采用?" suggestion for a saved food.
///
/// This widget is **advisory only**. Rendering it never changes an item: it
/// receives a ranked [FoodSuggestion] from `suggestSavedFood` and calls
/// [onApply] only when the user taps 采用. That is the plan's hard rule — an AI
/// item is never auto-overridden; the user's tap is the sole trigger.
///
/// The banner copy is now per-candidate: [message] names the saved food (with
/// its brand) and [reasonLabel] states *why* it was offered (名称一致 /
/// 别名一致 / 名称相近 / 名称相似), so the user can tell e.g. two brands of the
/// same 纯牛奶 apart before adopting one.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/domain/services/label_priority.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// A dismissible-looking banner offering to adopt a saved food's label.
class LabelSuggestionBanner extends StatelessWidget {
  const LabelSuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onApply,
    this.title,
    this.reasonLabel,
  });

  /// The top-ranked, non-binding candidate from `suggestSavedFood`.
  final FoodSuggestion suggestion;

  /// Invoked on the explicit 采用 tap; the caller applies the food.
  final VoidCallback onApply;

  /// Candidate-specific banner title; falls back to the legacy exact-name copy.
  ///
  /// Named [title] (not `message`) because the legacy default copy is exposed
  /// as the static [message] constant that the earlier tests import.
  final String? title;

  /// Why this candidate was proposed (a match-reason line), or `null`.
  final String? reasonLabel;

  /// The exact copy the plan specifies (legacy default title).
  static const String message = S.labelSuggestionMessageConst;

  /// Key of the 采用 button (asserted by the widget tests).
  static const Key applyButtonKey = Key('saved_food_apply_suggestion');

  /// Key of the banner container.
  static const Key containerKey = Key('saved_food_suggestion_banner');

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? reason = reasonLabel;
    return Container(
      key: containerKey,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title ?? S.of(context).labelSuggestionMessage,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                if (reason != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            key: applyButtonKey,
            onPressed: onApply,
            child: Text(S.of(context).applySuggestion),
          ),
        ],
      ),
    );
  }
}
