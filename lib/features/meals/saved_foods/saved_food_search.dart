/// Pure search/filter for the saved-food picker (task 20).
///
/// Search is **normalized substring** matching: the query and the food's
/// name/brand/aliases/notes are folded with `normalizeName` from the
/// label-priority service (trim, lowercase, punctuation -> separator, CJK inner
/// spaces removed), then a `contains` test. That keeps `牛奶` matching `全脂牛奶`
/// and `全脂 牛奶` while different foods (`脱脂牛奶`) still cannot collapse into
/// the same key. [Food.aliases] is the structured way to record an alias
/// (`小饼干`); [Food.notes] is searched too, both for remarks and so a legacy
/// alias typed when the label was captured (「别名：小饼干」) still finds the
/// food later.
///
/// An empty (or blank/punctuation-only) query is **not an error**: it returns
/// the whole catalogue unchanged, so the picker's initial state is the full
/// list rather than an empty screen.
library;

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart';

/// The foods from [foods] whose normalized name, brand, alias or notes contains
/// the normalized [query]. Empty query -> every food (immutable copy).
List<Food> searchSavedFoods(List<Food> foods, String query) {
  final String key = normalizeName(query);
  if (key.isEmpty) {
    return List<Food>.unmodifiable(foods);
  }
  return List<Food>.unmodifiable(<Food>[
    for (final Food food in foods)
      if (_matches(food, key)) food,
  ]);
}

bool _matches(Food food, String key) {
  if (normalizeName(food.name).contains(key)) {
    return true;
  }
  final String? brand = food.brand;
  if (brand != null && normalizeName(brand).contains(key)) {
    return true;
  }
  for (final String alias in food.aliases) {
    if (normalizeName(alias).contains(key)) {
      return true;
    }
  }
  final String? notes = food.notes;
  return notes != null && normalizeName(notes).contains(key);
}
