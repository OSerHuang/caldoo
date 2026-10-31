/// The live, searchable list of saved foods.
///
/// Shared by the two surfaces that show the saved-food catalogue:
/// * [FoodLibraryScreen] — the 食物库 tab, where choosing a row opens its
///   detail and the empty state offers the add-food flow;
/// * [SavedFoodPicker] — the explicit selection flow used while reviewing a
///   meal, where choosing a row resolves the food for the item.
///
/// The list itself only owns the search field; the row taps are delegated to
/// the caller ([onFoodTap]) so the two flows stay distinguishable, and a
/// caller may replace the empty state ([emptyState]) to add its own call to
/// action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart'
    show foodAliases, foodServings;
import 'package:caldoo/l10n/app_strings.dart';

import 'food_source_badge.dart';
import 'food_supplement_format.dart';
import 'saved_food_search.dart';
import 'saved_foods_providers.dart';

/// Key of the search text field.
const Key savedFoodSearchFieldKey = Key('saved_food_search_field');

/// Key of the tile for a food with [foodId].
Key savedFoodTileKey(String foodId) => Key('saved_food_tile_$foodId');

/// Key of the "view information" button for a food with [foodId].
Key savedFoodInfoKey(String foodId) => Key('saved_food_info_$foodId');

/// Key of the structured meta line (brand / aliases / servings) of a row.
Key savedFoodTileMetaKey(String foodId) => Key('saved_food_meta_$foodId');

/// Key of the 「已停用」 badge of an archived food with [foodId].
///
/// Absent from the tree while the food is active.
Key savedFoodArchivedBadgeKey(String foodId) =>
    Key('saved_food_archived_$foodId');

/// The searchable saved-food list.
class SavedFoodList extends ConsumerStatefulWidget {
  /// Creates the list. [onFoodTap] receives the tapped food; when
  /// [onFoodInfo] is set, every row also gets an info button for it.
  const SavedFoodList({
    required this.onFoodTap,
    this.onFoodInfo,
    this.emptyState,
    this.listBottomInset = 0,
    super.key,
  });

  /// Called when the user taps a row.
  final ValueChanged<Food> onFoodTap;

  /// Called when the user taps a row's info button; `null` hides the button.
  final ValueChanged<Food>? onFoodInfo;

  /// Replaces the empty-catalogue message; `null` shows the plain
  /// [S.savedFoodsEmpty] line. [SavedFoodPicker] leaves it unset, the 食物库
  /// passes a panel with an add action.
  final Widget? emptyState;

  /// Bottom padding of the scrolling list, so the 食物库's floating add button
  /// never covers the last row. The picker leaves it `0` (it has no FAB).
  final double listBottomInset;

  @override
  ConsumerState<SavedFoodList> createState() => _SavedFoodListState();
}

class _SavedFoodListState extends ConsumerState<SavedFoodList> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Food>> foodsAsync = ref.watch(savedFoodsProvider);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: savedFoodSearchFieldKey,
            controller: _search,
            onChanged: (String value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: S.of(context).savedFoodSearchHint,
            ),
          ),
        ),
        Expanded(
          child: foodsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) =>
                _ListMessage(text: S.of(context).savedFoodsLoadFailed),
            data: (List<Food> foods) {
              final List<Food> filtered = searchSavedFoods(foods, _query);
              if (foods.isEmpty) {
                return widget.emptyState ??
                    _ListMessage(text: S.of(context).savedFoodsEmpty);
              }
              if (filtered.isEmpty) {
                return _ListMessage(text: S.of(context).savedFoodsNoMatch);
              }
              return ListView.builder(
                padding: EdgeInsets.only(bottom: widget.listBottomInset),
                itemCount: filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  final Food food = filtered[index];
                  final String? meta = savedFoodMetaLine(context, food);
                  final ValueChanged<Food>? onInfo = widget.onFoodInfo;
                  return ListTile(
                    key: savedFoodTileKey(food.id),
                    title: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            // 品牌+食物名（名称（品牌）），so two brands of the
                            // same product are distinguishable at a glance.
                            S
                                .of(context)
                                .foodLabelWithBrand(food.name, food.brand),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!food.isMatchable) ...<Widget>[
                          const SizedBox(width: AppDim.gapTight),
                          _ArchivedBadge(
                            key: savedFoodArchivedBadgeKey(food.id),
                          ),
                        ],
                      ],
                    ),
                    subtitle: meta == null
                        ? null
                        : Text(
                            meta,
                            key: savedFoodTileMetaKey(food.id),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // The official-label pill is pure noise on a
                        // catalogue that is almost entirely labels; the
                        // non-authoritative sources (AI / manual) keep it
                        // because they are the ones worth flagging.
                        if (food.source != FoodSource.label)
                          FoodSourceBadge(
                            key: FoodSourceBadge.keyFor(food.id),
                            source: food.source,
                          ),
                        if (onInfo != null)
                          IconButton(
                            key: savedFoodInfoKey(food.id),
                            tooltip: S.of(context).viewFoodInfo,
                            onPressed: () => onInfo(food),
                            icon: const Icon(Icons.info_outline),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      ],
                    ),
                    onTap: () => widget.onFoodTap(food),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The structured meta line of a row: `别名：… · 份量：…`.
///
/// The brand is deliberately not part of it: the row title already reads
/// 名称（品牌）(see [S.foodLabelWithBrand]), so a brand here would say the same
/// thing twice. Aliases/servings prefer the structured fields and fall back to
/// the legacy prose in [Food.notes], so a row captured before P2 gets the same
/// readable line without a migration. Returns `null` when the food has neither.
String? savedFoodMetaLine(BuildContext context, Food food) {
  final S strings = S.of(context);
  final List<String> parts = <String>[];
  final List<String> aliases = foodAliases(food);
  if (aliases.isNotEmpty) {
    parts.add(strings.foodDetailAliasesLine(aliases.join('、')));
  }
  final List<FoodServing> servings = foodServings(food);
  if (servings.isNotEmpty) {
    parts.add(strings.foodDetailServingsLine(formatFoodServings(servings)));
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// The small 「已停用」 tag on an archived food's row.
///
/// Archiving never deletes a food: the row stays listed (and selectable), so
/// the badge is the only hint that this food is no longer offered by matching.
class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDim.radiusBadge),
      ),
      child: Text(
        S.of(context).foodStatusArchived,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
