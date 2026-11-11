/// The kg window and tick step shared by the weight line charts.
///
/// The weekly/monthly overview's 体重 block and the full trend page both plot kg
/// on their own right-hand axis, and both relied on `fl_chart`'s default title
/// sampling. That default emits a label at every multiple of the step AND one
/// at each exact bound of the window. Because the window is the *padded* data
/// range (e.g. 67.96 .. 69.24), those two extra labels landed a fraction of a
/// step from the nearest regular tick and painted over it — the 周/月 overview's
/// 右侧坐标数字相互遮盖.
///
/// [weightChartWindow] removes that class of bug: it picks a step whose labels
/// clear [minLabelGapPx] in the plot's own height, and the charts label ONLY the
/// regular ticks (`SideTitles.minIncluded` / `maxIncluded` false). Every label
/// is then a whole step from its neighbours, so two labels can never coincide
/// however the bounds fall. `minY` / `maxY` stay at the padded values — snapping
/// them to the grid would push the line into a corner of the plot.
library;

import 'dart:math' as math;

/// The room one 10 px axis label needs: its own line height plus the gap that
/// keeps two of them from reading as one block.
const double minLabelGapPx = 20;

/// The step multipliers, ascending — the classic 1-2-5 ladder.
const List<double> _stepMultipliers = <double>[1, 2, 5];

/// The y bounds and tick step (all kg) for a chart of [plotHeightPx] pixels over
/// [minKg]..[maxKg].
///
/// Pads the data by 30% of its span (clamped to 0.2 .. 1.2 kg, so a flat series
/// — a single recording — still draws inside a visible band), then picks the
/// finest 1-2-5 step whose labels are at least [minLabelGapPx] apart on screen.
/// Finer is better here: the labels are already guaranteed not to touch, so the
/// step only decides how much detail the axis shows.
///
/// A flat series ([minKg] == [maxKg]) is valid and gives a window around it.
({double minY, double maxY, double interval}) weightChartWindow(
  double minKg,
  double maxKg, {
  required double plotHeightPx,
}) {
  final double pad = ((maxKg - minKg) * 0.3).clamp(0.2, 1.2);
  final double minY = minKg - pad;
  final double maxY = maxKg + pad;
  return (
    minY: minY,
    maxY: maxY,
    interval: _tickStep(minY: minY, maxY: maxY, plotHeightPx: plotHeightPx),
  );
}

/// The finest 1-2-5 step that keeps the labels [minLabelGapPx] apart, falling
/// back to the finest one that merely keeps two of them.
///
/// The gap rule is what the overlap bug needs; the two-label rule keeps the
/// axis meaningful (one number does not describe a trend). They only collide on
/// a plot shorter than ~4 label heights — neither weight chart is (they reserve
/// 100 px and 178 px) — and there the labels win: a blank axis says nothing.
double _tickStep({
  required double minY,
  required double maxY,
  required double plotHeightPx,
}) {
  final double window = maxY - minY;
  if (window <= 0 || plotHeightPx <= 0) {
    return 1;
  }
  // A step spans `interval / window * plotHeightPx` pixels, so this is the
  // smallest interval whose labels do not touch.
  final double floorKg = minLabelGapPx * window / plotHeightPx;

  // Walk the ladder upward from the floor; the first rung carrying two labels
  // is the answer. The scan starts one decade below the floor so a plot too
  // short to honour the gap still ends up with the most spacious axis it can.
  final double magnitude = math
      .pow(10, (math.log(floorKg) / math.ln10).floor() - 1)
      .toDouble();
  double? spaced;
  for (var decade = magnitude; decade <= magnitude * 1e4; decade *= 10) {
    for (final double multiplier in _stepMultipliers) {
      final double step = multiplier * decade;
      if (_interiorTicks(minY, maxY, step) < 2) {
        continue;
      }
      if (step >= floorKg) {
        return step;
      }
      // Below the floor: remember the coarsest such rung, i.e. the widest gap
      // still available.
      spaced = step;
    }
  }
  return spaced ?? window / 2;
}

/// The multiples of [interval] strictly inside `[minY, maxY]`, i.e. what the
/// charts label once both bounds are excluded.
int _interiorTicks(double minY, double maxY, double interval) {
  final int first = (minY / interval + 1e-9).floor() + 1;
  final int last = (maxY / interval - 1e-9).ceil() - 1;
  return math.max(0, last - first + 1);
}
