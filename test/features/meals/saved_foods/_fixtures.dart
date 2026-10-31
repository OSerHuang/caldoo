/// Shared fixtures for the task-20 saved-food picker tests.
///
/// The label food uses exactly-representable per-100 g values so the
/// `per100g * 1.5` / `per100g * 2.0` rescale assertions are exact in binary
/// floating point.
library;

import 'package:caldoo/domain/models/models.dart';

/// A `source=label` food: per-100 g kcal 200 / carb 20 / protein 10 / fat 5 /
/// sodium 200 mg (salt 0.5 g per 100 g).
const Food labelMilk = Food(
  id: 'food-label-milk',
  name: '全脂牛奶',
  brand: '光明',
  source: FoodSource.label,
  kcal: 200,
  carbG: 20,
  proteinG: 10,
  fatG: 5,
  sodiumMg: 200,
);

/// A `source=ai` saved food that does NOT match the milk item's name.
const Food aiVeg = Food(
  id: 'food-ai-veg',
  name: '清炒时蔬',
  source: FoodSource.ai,
  kcal: 90,
  carbG: 6,
  proteinG: 2,
  fatG: 6,
  sodiumMg: 400,
);

/// A manually entered food whose alias/package size live only in `notes`:
/// searching for the alias must still find it.
const Food aliasedFood = Food(
  id: 'food-alias',
  name: '苏打饼干',
  source: FoodSource.manual,
  notes: '一包 45 g；别名：小饼干',
  kcal: 400,
);

/// A label food with a deliberately blank protein field (a GB 28050 label may
/// omit a value): the protein must fall back to the AI value verbatim.
const Food blankProteinMilk = Food(
  id: 'food-label-blankprotein',
  name: '全脂牛奶',
  source: FoodSource.label,
  kcal: 200,
  carbG: 20,
  fatG: 5,
  sodiumMg: 200,
);

/// A drink with every structured supplement field filled: per-100 ml basis,
/// two aliases and two servings. Used by the supplement editor / detail tests
/// (prefill, save round-trip, structured display).
const Food structuredOatMilk = Food(
  id: 'food-structured-oat',
  name: '燕麦奶',
  brand: 'OATLY',
  aliases: <String>['燕麦奶', 'oat milk'],
  servings: <FoodServing>[
    FoodServing(label: '一盒', amount: 250, unit: 'ml'),
    FoodServing(label: '一袋', amount: 120, unit: 'g'),
  ],
  basis: MeasureBasis.per100ml,
  source: FoodSource.manual,
  kcal: 60,
  carbG: 7,
  proteinG: 1,
  fatG: 3,
  sodiumMg: 100,
);

/// An archived food: still listed in the catalogue (tagged 「已停用」) but
/// skipped by matching and suggestions.
const Food archivedBiscuit = Food(
  id: 'food-archived-biscuit',
  name: '停用饼干',
  aliases: <String>['旧饼干'],
  status: FoodStatus.archived,
  source: FoodSource.manual,
  kcal: 450,
);

/// The AI estimate being reviewed: name matches [labelMilk].
MealItem aiMilkItem({double grams = 100}) => MealItem(
  id: 'item-1',
  name: '全脂牛奶',
  grams: grams,
  kcal: 120,
  carbG: 8,
  proteinG: 6,
  fatG: 5,
  saltG: 0.3,
  source: FoodSource.ai,
  confidence: 0.7,
);
