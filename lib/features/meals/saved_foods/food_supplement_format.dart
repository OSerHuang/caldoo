/// Rendering helpers for the structured saved-food supplement.
///
/// Kept outside the editor screen so the list, the detail page and the editor
/// prefill can never disagree about how a serving is written.
library;

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_format.dart';

/// Renders [servings] the way the user writes them: `一袋 120 g、一块 30 g`.
///
/// Amounts go through [AppFormat.number], which prints `120.0` as `120` and
/// keeps a real decimal (`12.5`).
String formatFoodServings(List<FoodServing> servings) {
  return servings
      .map(
        (FoodServing serving) =>
            '${serving.label} ${AppFormat.number(serving.amount)} '
            '${serving.unit}',
      )
      .join('、');
}
