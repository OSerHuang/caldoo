/// Searchable saved-food picker (task 20).
///
/// A full-screen selection list of every saved food, each tagged with a
/// 官方标签 / AI估算 badge from `Food.source`. Tapping a row pops the picker
/// with the chosen [Food]; the caller decides how to apply it (the review
/// editor recomputes from per-100 g). The per-row info button opens
/// [SavedFoodDetailScreen] without making a choice, so a food can be inspected
/// before it is picked.
///
/// The list is live via `savedFoodsProvider` and filtered locally by
/// [searchSavedFoods]. A blank query shows everything, and an empty result set
/// shows a friendly empty state instead of an error.
///
/// Browsing the catalogue (rather than picking for a meal) uses
/// [FoodLibraryScreen], the 食物库 tab, which shares [SavedFoodList] but opens
/// the detail on a row tap.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'saved_food_detail_screen.dart';
import 'saved_food_list.dart';

export 'saved_food_list.dart'
    show savedFoodInfoKey, savedFoodSearchFieldKey, savedFoodTileKey;

/// The picker screen.
class SavedFoodPicker extends StatelessWidget {
  const SavedFoodPicker({super.key});

  /// Pushes the picker and completes with the chosen food, or `null` when the
  /// user backs out without choosing.
  static Future<Food?> push(BuildContext context) {
    return Navigator.of(context).push<Food>(
      MaterialPageRoute<Food>(builder: (_) => const SavedFoodPicker()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).savedFoodPickerTitle)),
      body: SavedFoodList(
        onFoodTap: (Food food) => Navigator.of(context).pop(food),
        onFoodInfo: (Food food) => SavedFoodDetailScreen.push(context, food),
      ),
    );
  }
}
