// The weight charts' y axis: the window/step helper and the labels it actually
// renders. The regression under test is the 周/月 overview bug where fl_chart's
// built-in min/max labels landed a fraction of a step from the regular tick and
// painted over it (右侧坐标数字相互遮盖).
//
// dart format width=80
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/features/weight/weight_chart_window.dart';
import 'package:caldoo/features/weight/weight_period_block.dart';

/// The multiples of [interval] strictly inside `[minY, maxY]`, which is what the
/// charts label (both bounds are excluded via minIncluded/maxIncluded).
int _interiorTicks(double minY, double maxY, double interval) {
  final int first = (minY / interval + 1e-9).floor() + 1;
  final int last = (maxY / interval - 1e-9).ceil() - 1;
  return math.max(0, last - first + 1);
}

/// The pixel gap between two consecutive labels of [interval].
double _gapPx(
  ({double minY, double maxY, double interval}) y,
  double plotHeightPx,
) => y.interval / (y.maxY - y.minY) * plotHeightPx;

void main() {
  group('weightChartWindow', () {
    test('pads the data so the line never touches the plot edges', () {
      final ({double minY, double maxY, double interval}) y = weightChartWindow(
        68.2,
        68.6,
        plotHeightPx: 100,
      );
      expect(y.minY, lessThan(68.2));
      expect(y.maxY, greaterThan(68.6));
      expect(y.interval, greaterThan(0));
    });

    test('a flat series (one recording) still gets a visible band', () {
      final ({double minY, double maxY, double interval}) y = weightChartWindow(
        68.4,
        68.4,
        plotHeightPx: 100,
      );
      expect(y.maxY - y.minY, greaterThanOrEqualTo(0.4));
      expect(y.minY, lessThan(68.4));
      expect(y.maxY, greaterThan(68.4));
    });

    test('labels clear the minimum pixel gap at the real plot heights', () {
      // The bug was a spacing failure, not a rounding one: two labels a
      // fraction of a step apart is what painted one over the other. The step
      // is therefore chosen against the plot's own height. 100 px is the
      // dashboard block, 178 px the trend page.
      for (final double height in <double>[100, 178]) {
        for (double minKg = 35; minKg <= 130; minKg += 0.37) {
          for (final double span in <double>[0, 0.05, 0.3, 1.1, 2.7, 6.4, 20]) {
            final ({double minY, double maxY, double interval}) y =
                weightChartWindow(minKg, minKg + span, plotHeightPx: height);
            expect(
              _gapPx(y, height),
              greaterThanOrEqualTo(minLabelGapPx),
              reason:
                  'window ${y.minY}..${y.maxY} step ${y.interval} '
                  'at $height px',
            );
          }
        }
      }
    });

    test('always leaves at least two labels to draw', () {
      for (final double height in <double>[60, 100, 120, 200, 400]) {
        for (double minKg = 35; minKg <= 130; minKg += 0.37) {
          for (final double span in <double>[0, 0.05, 0.3, 1.1, 2.7, 6.4, 20]) {
            final ({double minY, double maxY, double interval}) y =
                weightChartWindow(minKg, minKg + span, plotHeightPx: height);
            expect(
              _interiorTicks(y.minY, y.maxY, y.interval),
              greaterThanOrEqualTo(2),
              reason:
                  'window ${y.minY}..${y.maxY} step ${y.interval} '
                  'at $height px',
            );
          }
        }
      }
    });

    test('the step is a 1-2-5 x 10^n value', () {
      for (double minKg = 35; minKg <= 130; minKg += 1.7) {
        for (final double span in <double>[0, 0.4, 1.6, 9.5, 40]) {
          final double interval = weightChartWindow(
            minKg,
            minKg + span,
            plotHeightPx: 100,
          ).interval;
          final double magnitude = math
              .pow(10, (math.log(interval) / math.ln10).floor())
              .toDouble();
          expect(
            (interval / magnitude).roundToDouble(),
            anyOf(1.0, 2.0, 5.0),
            reason: 'interval $interval for $minKg..${minKg + span}',
          );
        }
      }
    });
  });

  group('体重 block right-axis labels', () {
    Future<void> pumpBlock(
      WidgetTester tester,
      List<WeightEntry> entries,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: WeightPeriodBlock(
                entries: entries,
                periodStart: DateTime.utc(2026, 10, 5),
                slotCount: 7,
                recordInitialDay: DateTime.utc(2026, 10, 11),
                deltaKey: const Key('weight_block_delta'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The right-axis label [Text]s: the only bare numbers the block prints.
    List<Text> axisLabels(WidgetTester tester) => <Text>[
      for (final Element element
          in find.byType(Text).evaluate().toList(growable: false))
        if (double.tryParse((element.widget as Text).data ?? '') != null)
          element.widget as Text,
    ];

    testWidgets('a tight in-week span does not repeat a label', (
      WidgetTester tester,
    ) async {
      await pumpBlock(tester, <WeightEntry>[
        WeightEntry(dayKey: DateTime.utc(2026, 10, 5), weightKg: 69.0),
        WeightEntry(dayKey: DateTime.utc(2026, 10, 7), weightKg: 68.7),
        WeightEntry(dayKey: DateTime.utc(2026, 10, 9), weightKg: 68.4),
        WeightEntry(dayKey: DateTime.utc(2026, 10, 11), weightKg: 68.2),
      ]);

      // The bug printed each raw window bound next to the regular tick, so two
      // labels rounded to the same string and painted over each other.
      final List<String> texts = <String>[
        for (final Text label in axisLabels(tester)) label.data!,
      ];
      expect(texts.length, greaterThanOrEqualTo(2));
      expect(
        texts.toSet().length,
        texts.length,
        reason: 'repeated axis labels: $texts',
      );
    });

    testWidgets('the labels are a whole step apart', (
      WidgetTester tester,
    ) async {
      await pumpBlock(tester, <WeightEntry>[
        WeightEntry(dayKey: DateTime.utc(2026, 10, 5), weightKg: 69.0),
        WeightEntry(dayKey: DateTime.utc(2026, 10, 9), weightKg: 68.4),
      ]);

      final List<double> values = <double>[
        for (final Text label in axisLabels(tester)) double.parse(label.data!),
      ]..sort();
      expect(values.length, greaterThanOrEqualTo(2));
      final double step = values[1] - values[0];
      for (int i = 2; i < values.length; i++) {
        expect(
          values[i] - values[i - 1],
          closeTo(step, 1e-6),
          reason: 'labels $values are unevenly spaced',
        );
      }
    });
  });
}
