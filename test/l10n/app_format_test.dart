/// Defect D2/D5: the shared [AppFormat.number] display contract.
///
/// Every user-visible number in the app funnels through this one helper, so
/// this file pins the behaviour that stops raw binary noise (`7749.3824…`) and
/// spurious `.0` (`30.0 分钟`) from reaching the UI.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

void main() {
  group('AppFormat.number integral values (unchanged)', () {
    test('drops a trailing .0', () {
      expect(AppFormat.number(300.0), '300');
      expect(AppFormat.number(0.0), '0');
      expect(AppFormat.number(5.0), '5');
    });

    test('keeps an exact half a trailing-zero-free decimal', () {
      expect(AppFormat.number(1978.5), '1978.5');
    });
  });

  group('AppFormat.number short fractions are preserved exactly', () {
    test('two-decimal and one-decimal values are untouched', () {
      expect(AppFormat.number(1935.75), '1935.75');
      expect(AppFormat.number(2235.75), '2235.75');
      expect(AppFormat.number(257.25), '257.25');
      expect(AppFormat.number(3.5), '3.5');
    });
  });

  group('AppFormat.integer rounds to a whole kcal value', () {
    test('rounds half up, keeping the sign', () {
      expect(AppFormat.integer(1935.75), '1936');
      expect(AppFormat.integer(10149.75), '10150');
      expect(AppFormat.integer(-149.75), '-150');
      expect(AppFormat.integer(300.0), '300');
      expect(AppFormat.integer(0), '0');
    });
  });

  group('AppFormat.number raw floating-point noise (D2)', () {
    test('caps at two decimals', () {
      expect(AppFormat.number(7749.3824091777821), '7749.38');
      expect(AppFormat.number(5513.6324091777821), '5513.63');
      expect(AppFormat.number(475.38240917782025), '475.38');
    });

    test('rounds the third decimal half-up', () {
      expect(AppFormat.number(275.625), '275.63');
    });
  });

  group('D5: durations never show a spurious .0', () {
    test('30.0 minutes renders as 30', () {
      expect(AppFormat.number(30.0), '30');
    });
  });

  group('AppFormat history period formatting', () {
    test('weekday maps Monday..Sunday to 周一..周日', () {
      expect(AppFormat.weekday(DateTime.utc(2026, 1, 5)), '周一');
      expect(AppFormat.weekday(DateTime.utc(2026, 1, 6)), '周二');
      expect(AppFormat.weekday(DateTime.utc(2026, 1, 11)), '周日');
    });

    test('dateWithWeekday carries the local date and weekday', () {
      expect(
        AppFormat.dateWithWeekday(DateTime.utc(2026, 1, 5)),
        '2026年1月5日 周一',
      );
    });

    test('shortDate omits the year', () {
      expect(AppFormat.shortDate(DateTime.utc(2026, 1, 5)), '1月5日');
    });

    test('month names the year and month only (the month view header)', () {
      expect(AppFormat.month(DateTime.utc(2026, 1)), '2026年1月');
      expect(AppFormat.month(DateTime.utc(2025, 12)), '2025年12月');
      // A mid-month date still names its month: the header is a period label,
      // not a day label.
      expect(AppFormat.month(DateTime.utc(2026, 1, 20)), '2026年1月');
    });

    test('dateRange omits the end year inside one year', () {
      expect(
        AppFormat.dateRange(
          DateTime.utc(2026, 1, 5),
          DateTime.utc(2026, 1, 11),
        ),
        '2026年1月5日 - 1月11日',
      );
    });

    test('dateRange keeps both years across a year boundary', () {
      expect(
        AppFormat.dateRange(
          DateTime.utc(2025, 12, 29),
          DateTime.utc(2026, 1, 4),
        ),
        '2025年12月29日 - 2026年1月4日',
      );
    });
  });

  group('AppFormat 概览 year rule (year only outside the current year)', () {
    const int currentYear = 2026;

    test('date drops the year inside the current year', () {
      expect(
        AppFormat.date(DateTime.utc(2026, 1, 5), currentYear: currentYear),
        '1月5日',
      );
    });

    test('date keeps the year outside the current year', () {
      expect(
        AppFormat.date(DateTime.utc(2025, 12, 31), currentYear: currentYear),
        '2025年12月31日',
      );
    });

    test('dateWithWeekday follows the same rule', () {
      expect(
        AppFormat.dateWithWeekday(
          DateTime.utc(2026, 1, 5),
          currentYear: currentYear,
        ),
        '1月5日 周一',
      );
      expect(
        AppFormat.dateWithWeekday(
          DateTime.utc(2025, 12, 31),
          currentYear: currentYear,
        ),
        '2025年12月31日 周三',
      );
    });

    test('month drops the year inside the current year', () {
      expect(
        AppFormat.month(DateTime.utc(2026, 1), currentYear: currentYear),
        '1月',
      );
      expect(
        AppFormat.month(DateTime.utc(2025, 12), currentYear: currentYear),
        '2025年12月',
      );
    });

    test('dateRange drops each endpoint year independently', () {
      // A week fully inside the current year.
      expect(
        AppFormat.dateRange(
          DateTime.utc(2026, 1, 5),
          DateTime.utc(2026, 1, 11),
          currentYear: currentYear,
        ),
        '1月5日 - 1月11日',
      );
      // A week crossing into the current year: only the past endpoint keeps
      // its year.
      expect(
        AppFormat.dateRange(
          DateTime.utc(2025, 12, 29),
          DateTime.utc(2026, 1, 4),
          currentYear: currentYear,
        ),
        '2025年12月29日 - 1月4日',
      );
      // A week fully inside a past year keeps both years.
      expect(
        AppFormat.dateRange(
          DateTime.utc(2025, 3, 3),
          DateTime.utc(2025, 3, 9),
          currentYear: currentYear,
        ),
        '2025年3月3日 - 2025年3月9日',
      );
    });
  });

  group('S history period strings', () {
    final S s = S.instance;

    test('the period labels and back-to-now actions', () {
      expect(s.historyToday, '今天');
      expect(s.historyThisWeek, '本周');
      expect(s.historyBackToToday, '回到今天');
      expect(s.historyBackToThisWeek, '回到本周');
    });

    test('the previous / next tooltips', () {
      expect(s.historyPreviousDay, '前一天');
      expect(s.historyNextDay, '后一天');
      expect(s.historyPreviousWeek, '上一周');
      expect(s.historyNextWeek, '下一周');
    });

    test('the historical headings and empty states', () {
      expect(s.historyLogHeading, '当日记录');
      expect(s.historyMealsEmpty, '这一天没有记录');
      expect(s.historyDailySummaryTitle, '当日汇总');
      expect(s.historyWeeklyTitle, '周汇总');
      expect(s.historyWeeklyEmpty, '这一周暂无记录');
    });
  });

  group('S exercise strings format through AppFormat', () {
    final S s = S.instance;

    test('the exercise-burn labels', () {
      expect(s.exerciseTitle, '运动消耗');
      expect(s.labelExerciseKcal, '运动消耗 (kcal)');
      expect(s.clearExercise, '清除');
      expect(s.exerciseDateLabel, '记录日期');
      expect(s.exerciseDayToday, '今天');
      expect(s.exerciseDayYesterday, '昨天');
      expect(s.exerciseDatePickerTitle, '选择记录日期');
      expect(s.exerciseDayEmpty, '还没有记录运动消耗');
      expect(s.exerciseDayLoading, '读取中…');
    });

    test('the selected-day value line carries the whole kcal', () {
      // The screen formats the stored int with AppFormat.integer first.
      expect(s.exerciseDayValue('300'), '已记录：300 kcal');
      expect(s.exerciseDayValue('257'), '已记录：257 kcal');
    });

    test('the food-library tab and add-food flow strings', () {
      // The former 记录 hub is gone: the second tab is the live food library,
      // and its 添加食物 sheet reuses the label-capture flow for both lanes.
      expect(s.navFoods, '食物库');
      expect(s.foodLibraryTitle, '食物库');
      expect(s.foodLibraryAdd, '添加食物');
      expect(s.foodLibraryAddSheetTitle, '添加食物');
      expect(s.foodLibraryAddPhotoTitle, '拍照识别营养标签');
      expect(s.foodLibraryAddManualTitle, '手动录入');
      expect(s.savedFoodsEmpty, '食物库还是空的');
      expect(s.savedFoodSearchHint, '搜索食物');
      expect(s.labelManualTitle, '手动录入');
      expect(s.labelDoneAction, '完成');
    });

    test('the profile BMR field strings', () {
      expect(s.labelBmr, '基础代谢消耗 (kcal)');
      expect(s.helperBmr, '按性别 / 生日 / 身高 / 体重自动计算，也可直接修改');
      expect(s.bmrAutoButton, '自动计算');
      expect(s.profileBmrValidationError, '基础代谢消耗需为大于 0 的数字');
    });

    test('the profile birthday field strings', () {
      // `labelAge` is gone: age is derived from the birthday, never typed.
      expect(s.labelBirthday, '生日');
      expect(s.birthdayPlaceholder, '点击选择生日');
      expect(s.helperBirthday, '年龄按生日自动计算，无需每年修改');
      expect(s.ageFromBirthday(30), '当前年龄：30 岁');
      expect(s.birthdayPickerHelp, '选择生日');
      expect(s.profileBirthdayValidationError, '请选择生日（需早于今天，且年龄大于 0）');
      expect(s.profileValidationError, '请输入有效的身高和体重（均须大于 0）');
    });

    test('the profile / weekly subtitles name the basal metabolic rate', () {
      expect(s.profileDetailsSubtitle, '性别 / 生日 / 身高 / 体重 / 基础代谢');
      expect(S.weeklyTargetLineLabelConst, '基础代谢(不含运动)');
      expect(s.weeklyTargetLineLabel, '基础代谢(不含运动)');
    });

    test('the weekly cumulative-total labels', () {
      expect(s.labelTotalIntake, '总摄入');
      expect(s.labelTotalBurn, '总消耗');
      expect(s.labelDifference, '差值');
      expect(s.legendIntake, '摄入');
      expect(s.legendBurn, '消耗');
      expect(s.periodProfilePrompt, '完善资料以显示基础代谢虚线与总消耗');
      expect(s.weeklyTooltipUnlogged, '未记录');
    });
  });
}
