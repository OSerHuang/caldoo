import 'package:drift/drift.dart';

import '../../../domain/models/food.dart';

/// Saved foods with **per-100 g** nutrient values (`foods`).
///
/// Canonical units (mirroring the domain model): energy in **whole kcal**
/// (integer-only), macros g, sodium **mg**. Every nutrient column is nullable on purpose — a GB 28050 label may
/// omit a field, and "left blank" must round-trip as SQL `NULL`, never as `0`.
///
/// Images are never stored here (no blobs): a food is a nutrient record, the
/// photo lives only as a transient AI input.
@DataClassName('FoodRow')
class Foods extends Table {
  /// UUID of the food.
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get brand => text().nullable()();

  /// Optional barcode; the column exists for phase 2, there is no scanner UI.
  TextColumn get barcode => text().nullable()();

  /// Structured aliases, serialized as a JSON array (`["泡面","小饼干"]`).
  /// Nullable: legacy rows keep their aliases in [notes] until edited.
  TextColumn get aliases => text().nullable()();

  /// Structured servings, serialized as a JSON array of
  /// `{label, amount, unit}` objects. Nullable for legacy rows (same reason as
  /// [aliases]).
  TextColumn get servings => text().nullable()();

  /// `active` (NULL reads as active) or `archived`: archived foods are skipped
  /// by matching but kept for history.
  TextColumn get status => textEnum<FoodStatus>().nullable()();

  /// `per100g` (NULL reads as per-100 g) or `per100ml`.
  TextColumn get basis => textEnum<MeasureBasis>().nullable()();

  /// Free-form user supplement: remarks, or a legacy alias/serving that has
  /// not been structured yet. Nullable — blank stays `NULL`, never `''`.
  TextColumn get notes => text().nullable()();

  /// Where the nutrient values came from; stored as the enum name.
  TextColumn get source => textEnum<FoodSource>()();

  /// Per-100 g energy in **whole kcal** (canonical energy unit — never kJ and
  /// never fractional: every energy value in the app is an integer).
  IntColumn get kcal => integer().nullable()();

  /// Per-100 g carbohydrate in grams.
  RealColumn get carbG => real().nullable()();

  /// Per-100 g protein in grams.
  RealColumn get proteinG => real().nullable()();

  /// Per-100 g fat in grams.
  RealColumn get fatG => real().nullable()();

  /// Per-100 g sugar in grams (GB 28050 optional declaration).
  RealColumn get sugarG => real().nullable()();

  /// Per-100 g saturated fat in grams (GB 28050 optional declaration).
  RealColumn get saturatedFatG => real().nullable()();

  /// Per-100 g sodium in mg — the canonical salt/sodium value on a food.
  RealColumn get sodiumMg => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
