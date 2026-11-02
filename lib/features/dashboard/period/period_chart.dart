/// The chart machinery shared by the week and month summary cards.
///
/// The merged 概览 dashboard renders two cumulative summaries over the same
/// axes — the fixed Mon..Sun week and the calendar month. Both are "one bar per
/// day of the period", so the chart construction lives here once and is
/// parameterised by the period:
///
/// * **one bar group per day**, in the period's calendar order, carrying the
///   day's **intake** bar and — on the week card only — the day's **burn** bar
///   (that logged day's expenditure: BMR + exercise). The month card
///   deliberately sets [periodChartData]'s `showBurnBars` to `false`:
///   31 days × 2 six-pixel rods cannot be told apart on a phone, so the
///   month's burn stays in the tooltip and the totals rather than the plot.
/// * **a dashed target line** at the profile's resolved BMR (the user's own
///   override or the Mifflin-St Jeor estimate, excluding exercise and
///   regardless of any set goal), labelled [periodTargetLineLabel] so it can
///   never be confused with the daily dashboard's `今日额度(含运动)`. The line
///   is a single flat reference because one line cannot represent per-day
///   exercise-varying budgets.
/// * **a long-press tooltip bubble** naming the touched day (the weekday on the
///   week card, `1月5日` on the month card) plus its intake, burn (BMR +
///   exercise) and signed difference, in the display preference's energy unit
///   (kcal by default, kJ when chosen). It
///   replaces fl_chart's built-in tooltip, which paints the raw `toY` double
///   (`2500.0`) in the bar's own half-transparent fill colour on a blue-grey
///   square, and escapes the plot for tall bars — unreadable on a phone. The
///   bubble uses opaque theme colours (legible in both brightnesses), names the
///   rows in the app's own wording and is fitted inside the plot so it can
///   never be clipped by the card. An unlogged day says `未记录`; a missing
///   profile only has the intake row. The rows keep their canonical kcal value
///   in [PeriodDayTooltip] and only convert to the requested display unit
///   ([DisplayUnits]) when the bubble text is formatted.
/// * **evenly spaced integer y-axis labels**: the top is padded by 20% and then
///   rounded UP to a whole multiple of a "nice" 1-2-5 × 10^n step
///   ([periodChartInterval]), so fl_chart never also emits a tick at the exact
///   fractional maxY (e.g. 5080.8), which would collide with — and wrap over —
///   the tick below it.
///
/// The weekly card's chart is the parameter defaults (burn bars shown, 14 px
/// rods, a label under every day, weekday tooltip titles), so moving its
/// construction here cannot change a single rendered pixel of the task-26
/// dashboard — a requirement: the UI goldens capture it.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Fill colour of a daily intake bar (light-palette default for context-free
/// callers).
const Color periodBarColor = Color(0xFF16A34A);

/// Fill colour of a daily burn bar (light-palette default for context-free
/// callers).
const Color periodBurnBarColor = Color(0xFF0F766E);

/// Colour of the dashed base-budget target line.
const Color periodTargetLineColor = Color(0xFFDC2626);

/// Default colour of the axis tick labels (light palette, for context-free
/// callers).
const Color periodAxisLabelColor = Color(0xFF6B7280);

/// The dashed target line's dash pattern (`[6, 4]`) — a visual cue that the
/// line is a reference, not a per-day measurement.
const List<int> periodTargetLineDashArray = <int>[6, 4];

/// The dashed target line's label.
///
/// The shared period label deliberately comes from the same string constant as
/// the weekly card's `weeklyTargetLineLabel`, so the week view and the month
/// view can never word the exercise-free baseline differently.
const String periodTargetLineLabel = S.weeklyTargetLineLabelConst;

/// The three series a tooltip row can report.
enum PeriodTooltipKind {
  /// What was eaten that day.
  intake,

  /// That day's budget (BMR + exercise).
  burn,

  /// `intake - burn`: negative is 缺口 (deficit), positive is 盈余 (surplus).
  difference,
}

/// One labelled kcal row of the chart's long-press tooltip.
@immutable
class PeriodTooltipRow {
  /// Creates a tooltip row for [kind] (which drives the value's colour).
  const PeriodTooltipRow({
    required this.kind,
    required this.label,
    required this.kcal,
  });

  /// Which series the row reports.
  final PeriodTooltipKind kind;

  /// The row label (`摄入` / `消耗` / `差值`).
  final String label;

  /// The row's value in **whole kcal**.
  final int kcal;
}

/// The content of the chart's long-press tooltip bubble for one day.
@immutable
class PeriodDayTooltip {
  /// Creates the tooltip content for one day.
  const PeriodDayTooltip({
    required this.title,
    required this.logged,
    required this.rows,
    this.units = DisplayUnits.defaults,
  });

  /// The day's title: `周一` on the week card, `1月5日` on the month card.
  final String title;

  /// Whether the day logged at least one meal. An unlogged day has no [rows]
  /// and the bubble says [S.weeklyTooltipUnlogged] instead.
  final bool logged;

  /// The day's energy rows in reading order.
  ///
  /// The rows keep their canonical whole-kcal values; [units] decides how they
  /// are rendered in the bubble (kcal or kJ), never what is stored.
  final List<PeriodTooltipRow> rows;

  /// The display preference the bubble formats its [rows] with.
  final DisplayUnits units;
}

/// The colours of the chart's long-press tooltip bubble.
///
/// A dedicated palette rather than the raw [ColorScheme]: the bubble must stay
/// legible where it overlaps the coloured bars, so it paints an opaque fill and
/// uses its own text tones. The `差值` tint is a shade darker than the
/// surface-level semantic token so the value also clears a high-contrast text
/// ratio against the fill.
@immutable
class PeriodTooltipTheme {
  /// Creates a tooltip palette.
  const PeriodTooltipTheme({
    required this.background,
    required this.text,
    required this.muted,
    required this.border,
    required this.deficit,
    required this.surplus,
    required this.balanced,
  });

  /// The light-brightness palette.
  static const PeriodTooltipTheme light = PeriodTooltipTheme(
    background: Color(0xFFE5E8EC),
    text: Color(0xFF111827),
    muted: Color(0xFF4B5563),
    border: Color(0xFFD1D5DB),
    deficit: Color(0xFF166534),
    surplus: Color(0xFFB91C1C),
    balanced: Color(0xFF4B5563),
  );

  /// The dark-brightness palette.
  static const PeriodTooltipTheme dark = PeriodTooltipTheme(
    background: Color(0xFF272C33),
    text: Color(0xFFF3F4F6),
    muted: Color(0xFF9CA3AF),
    border: Color(0xFF3A3F47),
    deficit: Color(0xFF4ADE80),
    surplus: Color(0xFFF87171),
    balanced: Color(0xFF9CA3AF),
  );

  /// The palette matching the ambient [ThemeData.brightness].
  factory PeriodTooltipTheme.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The bubble's opaque fill.
  final Color background;

  /// Primary text: the day title, row labels and neutral values.
  final Color text;

  /// Secondary text: the energy unit (`kcal` / `kJ`; quieter, still above 4.5:1
  /// on [background]).
  final Color muted;

  /// The bubble's 1 px outline, so it reads as a surface over the bars.
  final Color border;

  /// The `差值` value when the day runs under budget (缺口).
  final Color deficit;

  /// The `差值` value when the day runs over budget (盈余).
  final Color surplus;

  /// The `差值` value when the day is exactly on budget (平衡).
  final Color balanced;
}

/// The long-press tooltip content for one chart day: the [title] and — for a
/// logged day — its intake, burn (BMR + exercise) and signed difference.
///
/// A missing profile ([bmrKcal] `null`) only reports intake; an unlogged
/// day reports `logged: false` so the bubble says `未记录` rather than a row of
/// zeros. The title is a parameter (rather than derived from [day]) because the
/// week card names the weekday while the month card names the calendar date.
/// Exposed (not private) so the widget tests can pin the exact content the
/// bubble shows without decoding the styled spans.
///
/// [units] is carried through to [PeriodDayTooltip] and only used when the
/// bubble is formatted: the [PeriodTooltipRow.kcal] values themselves stay
/// canonical kcal.
PeriodDayTooltip periodDayTooltip({
  required DayRollup day,
  required int? bmrKcal,
  required String title,
  DisplayUnits units = DisplayUnits.defaults,
}) {
  if (day.mealCount < 1) {
    return PeriodDayTooltip(
      title: title,
      logged: false,
      rows: const [],
      units: units,
    );
  }
  final List<PeriodTooltipRow> rows = <PeriodTooltipRow>[
    PeriodTooltipRow(
      kind: PeriodTooltipKind.intake,
      label: S.instance.legendIntake,
      kcal: day.intakeKcal,
    ),
  ];
  if (bmrKcal != null) {
    final int burn = periodBurnFor(day, bmrKcal);
    rows
      ..add(
        PeriodTooltipRow(
          kind: PeriodTooltipKind.burn,
          label: S.instance.legendBurn,
          kcal: burn,
        ),
      )
      ..add(
        PeriodTooltipRow(
          kind: PeriodTooltipKind.difference,
          label: S.instance.labelDifference,
          kcal: day.intakeKcal - burn,
        ),
      );
  }
  return PeriodDayTooltip(title: title, logged: true, rows: rows, units: units);
}

/// The value colour for a tooltip row: neutral for the measured series, tinted
/// by sign for the derived difference (the task-7 缺口/盈余 convention).
Color _periodTooltipValueColor(PeriodTooltipRow row, PeriodTooltipTheme theme) {
  if (row.kind != PeriodTooltipKind.difference) {
    return theme.text;
  }
  if (row.kcal == 0) {
    return theme.balanced;
  }
  return row.kcal < 0 ? theme.deficit : theme.surplus;
}

/// Builds the `fl_chart` tooltip item for one day's bubble.
///
/// One paragraph of [TextSpan]s so every line keeps its own colour and weight;
/// styles deliberately leave `inherit` at its default so fl_chart merges the
/// ambient `DefaultTextStyle` and the bubble keeps the app face and the system
/// text scale.
BarTooltipItem _periodTooltipItem({
  required PeriodDayTooltip tooltip,
  required PeriodTooltipTheme theme,
}) {
  const TextStyle rowStyle = TextStyle(fontSize: 12.5, height: 1.55);
  const TextStyle unitStyle = TextStyle(fontSize: 11, height: 1.55);
  final List<TextSpan> lines = <TextSpan>[
    TextSpan(
      text: tooltip.title,
      style: rowStyle.copyWith(
        fontSize: 13,
        color: theme.text,
        fontWeight: FontWeight.w700,
      ),
    ),
  ];
  if (tooltip.logged) {
    for (final PeriodTooltipRow row in tooltip.rows) {
      lines
        ..add(
          TextSpan(
            text: '\n${row.label} ',
            style: rowStyle.copyWith(color: theme.muted),
          ),
        )
        ..add(
          TextSpan(
            text: tooltip.units.energyValueText(row.kcal),
            style: rowStyle.copyWith(
              color: _periodTooltipValueColor(row, theme),
              fontWeight: FontWeight.w700,
            ),
          ),
        )
        ..add(
          TextSpan(
            text: ' ${tooltip.units.energyUnit}',
            style: unitStyle.copyWith(color: theme.muted),
          ),
        );
    }
  } else {
    lines.add(
      TextSpan(
        text: '\n${S.instance.weeklyTooltipUnlogged}',
        style: rowStyle.copyWith(color: theme.muted),
      ),
    );
  }
  return BarTooltipItem(
    '',
    rowStyle.copyWith(color: theme.text),
    textAlign: TextAlign.left,
    children: lines,
  );
}

/// Builds the `fl_chart` data for a period: one bar group per entry of [days]
/// (in order), each with an intake bar plus — when [showBurnBars] and
/// [bmrKcal] are both known — the day's burn bar (BMR + exercise), and the
/// dashed target line at [bmrKcal].
///
/// [bmrKcal] is the profile's resolved BMR — never the user's goal, which is
/// a diet target, not expended energy, and must not shift the burn bars, the
/// line or the axis when it differs from the BMR.
///
/// [xLabels] supplies the bottom-axis labels, one per day; [labelEvery] thins
/// them out (the month card labels every fifth day so its 31 day numbers stay
/// readable on a phone) by hiding the labels at the indices it does not divide.
/// [tooltipTitle] builds the tooltip's first line, so the week card can say
/// `周一` while the month card says `1月5日`.
///
/// Exposed (not private) so the widget tests can assert the exact bar values
/// and the target-line `y` through the rendered `BarChart` without duplicating
/// the chart construction. The colour params default to the light-palette
/// constants; the views pass brightness-aware colours. [tooltipTheme] defaults
/// to the light tooltip palette for the same context-free reason.
///
/// Only LOGGED days get a non-zero burn bar: an unlogged day (even one with an
/// exercise-only entry) is not part of the period's picture, exactly like its
/// zero intake bar.
///
/// [touchExtraHorizontal] is the horizontal hit-band padding around each rod.
/// It must stay below the gap between two neighbouring rods (see the
/// `touchExtraThreshold` comment); the month card passes 1 because its slots are
/// only ~9 px wide, the week keeps the historical 6.
///
/// The y-axis top covers exactly what is drawn: the intake bars, plus the burn
/// bars when [showBurnBars] is set, plus the target line's BMR. The month
/// card hides the burn rods, so their values deliberately do not enlarge its
/// axis — the tooltip and the totals still report burn.
///
/// [units] is the read-only display preference: when it asks for kJ, the rod
/// values, the y-axis top/ticks and the target-line `y` are all converted
/// through [DisplayUnits.energyValue] before the chart is built, so the plot
/// and its axis speak the same unit. The tooltip rows keep their kcal ints in
/// [PeriodDayTooltip] and convert only when the bubble text is formatted.
BarChartData periodChartData({
  required List<DayRollup> days,
  required List<String> xLabels,
  required int? bmrKcal,
  bool showBurnBars = true,
  double rodWidth = 14,
  int labelEvery = 1,
  double touchExtraHorizontal = 6,
  required String Function(DayRollup day) tooltipTitle,
  Color? barColor,
  Color? burnColor,
  Color? targetColor,
  Color? axisLabelColor,
  PeriodTooltipTheme? tooltipTheme,
  DisplayUnits units = DisplayUnits.defaults,
}) {
  final Color fill = barColor ?? periodBarColor;
  final Color burn = burnColor ?? periodBurnBarColor;
  final Color line = targetColor ?? periodTargetLineColor;
  final Color label = axisLabelColor ?? periodAxisLabelColor;
  final PeriodTooltipTheme tooltip = tooltipTheme ?? PeriodTooltipTheme.light;
  // Every plotted energy value goes through the display preference first, so
  // the rods, the target line and the axis labels share one (display) scale.
  // With the default kcal preference this is the identity and the chart is
  // pixel-identical to the historical one.
  final int? displayBmrKcal = bmrKcal == null
      ? null
      : units.energyValue(bmrKcal);
  final bool drawBurnBars = showBurnBars && displayBmrKcal != null;
  var top = displayBmrKcal?.toDouble() ?? 0.0;
  for (final day in days) {
    top = math.max(top, units.energyValue(day.intakeKcal).toDouble());
    if (drawBurnBars) {
      top = math.max(
        top,
        units.energyValue(periodBurnFor(day, bmrKcal)).toDouble(),
      );
    }
  }
  // Pad the top by 20%, then round UP to a whole multiple of a "nice" step.
  // fl_chart's auto-interval would otherwise also emit a tick at the exact
  // fractional maxY (e.g. 5080.8), which collides with — and wraps over — the
  // tick below it. An explicit interval that divides maxY yields evenly spaced
  // integer labels only (e.g. maxY 6000, interval 2000 -> 0,2000,4000,6000).
  final double interval = periodChartInterval(top);
  final double range = top <= 0 ? 100 : top * 1.2;
  final int steps = (range / interval - 1e-9).ceil();
  final double maxY = steps * interval;

  return BarChartData(
    alignment: BarChartAlignment.spaceAround,
    minY: 0,
    maxY: maxY,
    barGroups: <BarChartGroupData>[
      for (var i = 0; i < days.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: <BarChartRodData>[
            _periodBarRod(
              units.energyValue(days[i].intakeKcal).toDouble(),
              fill,
              rodWidth,
            ),
            if (drawBurnBars)
              _periodBarRod(
                units.energyValue(periodBurnFor(days[i], bmrKcal)).toDouble(),
                burn,
                rodWidth,
              ),
          ],
        ),
    ],
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (double value, TitleMeta meta) => SideTitleWidget(
            meta: meta,
            // Keep the label inside the plot's axis gutter: without this the
            // topmost label (at maxY, i.e. axisPosition 0) is centred on the
            // plot's top edge and its upper half paints over the card title.
            fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
            child: Text(
              AppFormat.number(value),
              style: TextStyle(fontSize: 10.5, color: label),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: labelEvery.toDouble(),
          getTitlesWidget: (double value, TitleMeta meta) {
            final int index = value.round();
            if (index < 0 || index >= xLabels.length) {
              return const SizedBox.shrink();
            }
            // fl_chart positions a horizontal bar chart's titles at EVERY group
            // and ignores the axis interval for them, so the label thinning has
            // to happen here: the month card's 31 day numbers would otherwise
            // collide (labelEvery == 1 for the week, so it renders unchanged).
            if (labelEvery > 1 && index % labelEvery != 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                xLabels[index],
                style: TextStyle(fontSize: 11.5, color: label),
              ),
            );
          },
        ),
      ),
    ),
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (double value) =>
          FlLine(color: label.withValues(alpha: 0.14), strokeWidth: 1),
    ),
    borderData: FlBorderData(show: false),
    extraLinesData: ExtraLinesData(
      horizontalLines: <HorizontalLine>[
        if (displayBmrKcal != null)
          HorizontalLine(
            y: displayBmrKcal.toDouble(),
            color: line,
            strokeWidth: 2,
            dashArray: periodTargetLineDashArray,
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: TextStyle(
                color: line,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (HorizontalLine line) => periodTargetLineLabel,
            ),
          ),
      ],
    ),
    barTouchData: BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (BarChartGroupData group) => tooltip.background,
        getTooltipItem:
            (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              if (groupIndex < 0 || groupIndex >= days.length) {
                return null;
              }
              return _periodTooltipItem(
                tooltip: periodDayTooltip(
                  day: days[groupIndex],
                  bmrKcal: bmrKcal,
                  title: tooltipTitle(days[groupIndex]),
                  units: units,
                ),
                theme: tooltip,
              );
            },
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tooltipMargin: 6,
        tooltipBorderRadius: BorderRadius.circular(AppDim.radiusControl),
        tooltipBorder: BorderSide(color: tooltip.border),
        // Keep the bubble inside the plot: without this it is painted above a
        // tall bar's top and clipped by (or escapes) the card.
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        maxContentWidth: 180,
      ),
      // Widen the pressed band around the rods so a long-press does not demand
      // pixel-perfect aim on the bar itself. Vertically the padding is free:
      // every group spans the same height, so it can never select the wrong
      // day. Horizontally it is NOT free — fl_chart's hit test returns the
      // FIRST group whose expanded band contains the press, so a band wider than
      // the gap between two rods attributes the left edge of one bar to the
      // previous day. The week's 14 px rods sit in ~44 px slots (6 px is safe);
      // the month's 6 px rods sit in ~9 px slots and pass [touchExtraHorizontal]
      // = 1 instead.
      touchExtraThreshold: EdgeInsets.symmetric(
        horizontal: touchExtraHorizontal,
        vertical: 16,
      ),
    ),
  );
}

/// One bar rod, tinted bottom-to-top like the rest of the dashboards.
BarChartRodData _periodBarRod(double toY, Color color, double width) =>
    BarChartRodData(
      toY: toY,
      width: width,
      borderRadius: BorderRadius.vertical(top: Radius.circular(width / 2)),
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[color.withValues(alpha: 0.55), color],
      ),
    );

/// The burn [day] contributes to the chart and to the period's totals: the
/// day's expenditure (`bmr + exercise`) for a logged day, otherwise zero.
///
/// [bmrKcal] is the profile's resolved BMR — never the user's goal, which is
/// a diet target, not expended energy.
///
/// Exposed (not private) so the widget tests can state the expected burn bars
/// without duplicating the rule.
int periodBurnFor(DayRollup day, int? bmrKcal) {
  if (bmrKcal == null || day.mealCount < 1) {
    return 0;
  }
  return bmrKcal + day.exerciseKcal;
}

/// The y-axis tick step for a period whose highest bar / budget is [top].
///
/// Picks a "nice" 1-2-5 x 10^n step targeting ~5 ticks, so [periodChartData]
/// can round `maxY` up to a whole multiple of it and emit evenly spaced integer
/// labels. Exposed so the widget tests can assert the step.
double periodChartInterval(double top) {
  final double range = top <= 0 ? 100 : top * 1.2;
  final double rough = range / 5;
  final double magnitude = math
      .pow(10, (math.log(rough) / math.ln10).floor())
      .toDouble();
  final double residual = rough / magnitude;
  final double nice = residual <= 1
      ? 1
      : residual <= 2
      ? 2
      : residual <= 5
      ? 5
      : 10;
  return nice * magnitude;
}

/// A filled dot + label legend item.
class PeriodLegendDot extends StatelessWidget {
  /// Creates a dot legend item; [textKey] is the widget-test hook.
  const PeriodLegendDot({
    required this.color,
    required this.label,
    super.key,
    this.textKey,
  });

  /// The dot's fill (the series colour).
  final Color color;

  /// The series name (`摄入` / `消耗`).
  final String label;

  /// Key attached to the label [Text] (widget-test hook).
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, key: textKey, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// A short dash + label legend item (the dashed target line).
class PeriodLegendDash extends StatelessWidget {
  /// Creates a dash legend item; [textKey] is the widget-test hook.
  const PeriodLegendDash({
    required this.color,
    required this.label,
    super.key,
    this.textKey,
  });

  /// The dash colour (the target line's colour).
  final Color color;

  /// The legend text (`虚线：基础代谢(不含运动)`).
  final String label;

  /// Key attached to the label [Text] (widget-test hook).
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, key: textKey, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
