/// The review row's label-link block: the applied match plus its alternatives.
///
/// Rendered only when `LinkedLabelView` is non-empty. It is deliberately
/// non-modal and reversible:
/// * an auto-applied match shows `已匹配：<标签>` with 撤销 (back to the AI
///   estimate) and 更换 (opens the saved-food picker);
/// * the remaining candidates are compact [ActionChip]s, so a wrong top-1 is
///   one tap away from the right label;
/// * tapping the applied name opens its per-100 g detail, exactly like the
///   manual adopted-food block.
///
/// Nothing here writes to the draft: every action is a callback owned by the
/// review screen, which keeps the draft the single source of truth.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/food_source_badge.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'linked_label_view.dart';

/// Key of the applied-match container for [itemId].
Key labelLinkAppliedKey(String itemId) => Key('label_link_applied_$itemId');

/// Key of the 撤销 button for [itemId].
Key labelLinkUndoKey(String itemId) => Key('label_link_undo_$itemId');

/// Key of the 更换 button for [itemId].
Key labelLinkChangeKey(String itemId) => Key('label_link_change_$itemId');

/// Key of the alternative-candidate chip for [itemId] + [foodId].
Key labelLinkChipKey(String itemId, String foodId) =>
    Key('label_link_chip_${itemId}_$foodId');

/// The label-link block for one review row.
class LabelLinkRow extends StatelessWidget {
  const LabelLinkRow({
    super.key,
    required this.itemId,
    required this.view,
    required this.onChange,
    required this.onApply,
    this.onUndo,
    this.onOpenDetail,
  });

  /// The review row's id (solely for stable widget keys).
  final String itemId;

  /// What the link produced for this row.
  final LinkedLabelView view;

  /// Opens the saved-food picker (更换).
  final VoidCallback onChange;

  /// Applies one of the alternative candidates.
  final ValueChanged<Food> onApply;

  /// Undoes the auto-applied match; `null` when nothing was auto-applied.
  final VoidCallback? onUndo;

  /// Opens the applied food's per-100 g detail, when provided.
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (view.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final Food? applied = view.appliedFood;
    final String? appliedLabel = applied == null
        ? null
        : S.of(context).foodLabelWithBrand(applied.name, applied.brand);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (applied != null) ...<Widget>[
          Container(
            key: labelLinkAppliedKey(itemId),
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: onOpenDetail,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            S.of(context).linkMatchedFood(appliedLabel!),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        FoodSourceBadge(source: applied.source),
                      ],
                    ),
                  ),
                ),
                if (onUndo != null)
                  TextButton(
                    key: labelLinkUndoKey(itemId),
                    onPressed: onUndo,
                    child: Text(S.of(context).linkUndo),
                  ),
                TextButton(
                  key: labelLinkChangeKey(itemId),
                  onPressed: onChange,
                  child: Text(S.of(context).linkChange),
                ),
              ],
            ),
          ),
        ],
        if (view.alternatives.isNotEmpty) ...<Widget>[
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
              for (final Food candidate in view.alternatives)
                ActionChip(
                  key: labelLinkChipKey(itemId, candidate.id),
                  label: Text(
                    S
                        .of(context)
                        .foodLabelWithBrand(candidate.name, candidate.brand),
                  ),
                  onPressed: () => onApply(candidate),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
