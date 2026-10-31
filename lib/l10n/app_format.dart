/// intl-based zh-CN date and number formatting (task 31).
///
/// The app is zh-CN only, so the formatters are fixed to that locale instead of
/// reading the ambient [Intl.defaultLocale]. Dates go through [DateFormat] with
/// the `zh_CN` symbol set; numbers go through [NumberFormat].
///
/// The `zh_CN` date symbols are not loaded by default, so [_ensureDateSymbols]
/// loads them once. `initializeDateFormatting` populates the symbol/pattern maps
/// **synchronously** (its `Future` only matters when a custom loader is passed),
/// so widgets and tests can format a date without an async boot step.
library;

import 'dart:async' show unawaited;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_strings.dart';

/// Fixed-format zh-CN date and number helpers.
class AppFormat {
  const AppFormat._();

  static bool _dateSymbolsReady = false;

  static void _ensureDateSymbols() {
    if (_dateSymbolsReady) {
      return;
    }
    unawaited(initializeDateFormatting('zh_CN'));
    _dateSymbolsReady = true;
  }

  // Integral counts go through intl (locale-aware). A fixed fraction pattern
  // is deliberately NOT used for arbitrary doubles because NumberFormat rounds
  // (and, at high precision, mis-scales) them, which is why fractional values
  // (macros / salt / grams, never energy) are rendered with `toStringAsFixed(2)`
  // and then have their trailing zeros stripped.
  static final NumberFormat _integer = NumberFormat('0');

  static final RegExp _trailingZeros = RegExp(r'\.?0+$');

  /// Formats [value] as a whole number: `1935.75` -> `1936`,
  /// `-149.75` -> `-150`, `1935` -> `1935`.
  ///
  /// Energy is integer-only in the domain, so every kcal display and the chart
  /// axis labels use this (a fractional value is rounded here defensively, the
  /// domain never produces one).
  static String integer(num value) => _integer.format(value.round());

  /// Formats a number without grouping or trailing zeros: `300`, `74.25`,
  /// `7749.38`. Used for macros / salt / grams; energy values are `int` and
  /// therefore always render whole.
  ///
  /// Integral values are formatted by intl; a fractional value is capped at
  /// **two decimal places** and its trailing zeros trimmed, so raw binary
  /// noise (`7749.3821777821`) never reaches the UI.
  static String number(num value) {
    if (value == value.roundToDouble()) {
      return _integer.format(value);
    }
    return value.toStringAsFixed(2).replaceFirst(_trailingZeros, '');
  }

  /// Formats a local date and wall-clock time as `2026年10月30日 21:15`.
  ///
  /// Used by the automatic-backup status and restore dialog, where the copy's
  /// timestamp is what tells two snapshots apart.
  static String dateTimeMinute(DateTime value) {
    _ensureDateSymbols();
    return DateFormat('yyyy年M月d日 HH:mm', 'zh_CN').format(value);
  }

  /// Formats a byte count as `812 B`, `53.4 KB` or `1.2 MB`.
  static String bytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }

  /// Formats a local date as `2026年9月22日`.
  ///
  /// Pass [currentYear] for the 概览 rule — a date only carries its year when
  /// it does not belong to the year on the wall clock: `1月5日` this year,
  /// `2025年12月31日` in any earlier one. Without [currentYear] the year is
  /// always rendered.
  static String date(DateTime value, {int? currentYear}) {
    if (currentYear != null && value.year == currentYear) {
      return shortDate(value);
    }
    _ensureDateSymbols();
    return DateFormat('yyyy年M月d日', 'zh_CN').format(value);
  }

  /// Formats a local date without the year: `9月22日`.
  ///
  /// Used by [dateRange] for the end of a same-year range, where repeating the
  /// year would only add noise (`2025年12月29日 - 1月4日`).
  static String shortDate(DateTime value) {
    _ensureDateSymbols();
    return DateFormat('M月d日', 'zh_CN').format(value);
  }

  /// Formats the zh-CN weekday of [value]: `周一` .. `周日`.
  static String weekday(DateTime value) =>
      '周${S.weekdayLabelsConst[value.weekday - 1]}';

  /// Formats the year and month of [value] for the month header: `2026年1月`.
  ///
  /// A month is one contiguous calendar period, so the day is not part of its
  /// label — the month view's x axis names the individual days instead.
  ///
  /// Pass [currentYear] for the 概览 rule (see [date]): a month of the current
  /// year renders as `1月`, any earlier year keeps `2025年12月`.
  static String month(DateTime value, {int? currentYear}) {
    if (currentYear != null && value.year == currentYear) {
      _ensureDateSymbols();
      return DateFormat('M月', 'zh_CN').format(value);
    }
    _ensureDateSymbols();
    return DateFormat('yyyy年M月', 'zh_CN').format(value);
  }

  /// Formats a local date with its weekday: `2026年9月22日 周二`.
  ///
  /// [currentYear] follows the [date] 概览 rule: `1月5日 周一` this year,
  /// `2025年12月31日 周三` in any earlier one.
  static String dateWithWeekday(DateTime value, {int? currentYear}) =>
      '${date(value, currentYear: currentYear)} ${weekday(value)}';

  /// Formats an inclusive date range for the history header.
  ///
  /// With [currentYear] (the 概览 week pager), each endpoint drops its year
  /// independently when it belongs to the current year — a week inside the
  /// year reads `1月5日 - 1月11日`, a week crossing the boundary
  /// `2025年12月29日 - 1月4日`.
  ///
  /// Without [currentYear] the legacy rule applies: the start always keeps its
  /// year and the end drops it when it shares the start's year
  /// (`2025年12月29日 - 2026年1月4日`).
  static String dateRange(
    DateTime startInclusive,
    DateTime endInclusive, {
    int? currentYear,
  }) {
    final String start =
        currentYear != null && startInclusive.year == currentYear
        ? shortDate(startInclusive)
        : date(startInclusive);
    final String end = currentYear != null
        ? (endInclusive.year == currentYear
              ? shortDate(endInclusive)
              : date(endInclusive))
        : (startInclusive.year == endInclusive.year
              ? shortDate(endInclusive)
              : date(endInclusive));
    return '$start - $end';
  }
}
