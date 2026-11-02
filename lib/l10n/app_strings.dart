/// The single zh-CN string table for the whole app (task 31).
///
/// Every user-facing literal — Chinese **and** English — lives here and nowhere
/// else. Widget code reaches the table through [S.of]:
///
/// ```dart
/// Text(S.of(context).navOverview)
/// ```
///
/// Non-widget code (controllers, pure projections such as [SignedBalance] or
/// `describeAiError`) cannot hold a [BuildContext]; it uses the identical table
/// through [S.instance]:
///
/// ```dart
/// state = state.copyWith(error: S.instance.errorExerciseKcalPositive);
/// ```
///
/// The app ships zh-CN only, so there is no locale switching: [S.of] always
/// returns the same const instance. The `context` parameter exists so the call
/// site reads like a normal localization lookup and so the table can become
/// context-aware later without touching the call sites.
///
/// Values that must stay `const` (default parameters, `const` widget subtrees,
/// and the public constants other modules/tests already import) are exposed as
/// `static const` fields with a `Const` suffix; the getter of the same name
/// returns that const, so there is still exactly one copy of each string.
library;

import 'package:flutter/widgets.dart';

/// The zh-CN string table.
class S {
  const S._();

  static const S _instance = S._();

  /// The table for widget code: `S.of(context).<key>`.
  static S of(BuildContext context) => _instance;

  /// The table for non-widget code (controllers, pure helpers).
  static S get instance => _instance;

  // ---------------------------------------------------------------------------
  // App identity
  // ---------------------------------------------------------------------------

  /// The application name, also the Android `android:label`.
  String get appTitle => '卡嘟';

  // ---------------------------------------------------------------------------
  // Shared unit / nutrient labels
  // ---------------------------------------------------------------------------

  /// Energy unit.
  String get unitKcal => 'kcal';

  /// Energy unit for the kilojoule display preference.
  String get unitKJ => 'kJ';

  /// Mass unit.
  String get unitG => 'g';

  /// Sodium unit.
  String get unitMg => 'mg';

  /// Day-count unit.
  String get unitDays => '天';

  /// Kilogram unit (the weight block's delta chip).
  String get unitKg => 'kg';

  /// Informal energy label used on the summary rows.
  String get labelEnergy => '热量';

  /// Informal carbohydrate label.
  String get labelCarb => '碳水';

  /// Informal protein label.
  String get labelProtein => '蛋白';

  /// Fat label.
  String get labelFat => '脂肪';

  /// Salt label (display-only, derived from sodium).
  String get labelSalt => '盐';

  /// Sodium label (the canonical stored mineral, shown when the user picks
  /// the 钠 display basis).
  String get labelSodium => '钠';

  /// Grams label.
  String get labelGrams => '克数';

  /// GB 28050 declaration name for energy.
  String get labelFieldEnergy => '能量';

  /// GB 28050 declaration name for protein.
  String get labelFieldProtein => '蛋白质';

  /// GB 28050 declaration name for fat.
  String get labelFieldFat => '脂肪';

  /// GB 28050 declaration name for saturated fat.
  String get labelFieldSaturatedFat => '饱和脂肪';

  /// GB 28050 declaration name for carbohydrate.
  String get labelFieldCarbohydrate => '碳水化合物';

  /// GB 28050 declaration name for sugar.
  String get labelFieldSugar => '糖';

  /// GB 28050 declaration name for sodium.
  String get labelFieldSodium => '钠';

  // ---------------------------------------------------------------------------
  // Common actions / states
  // ---------------------------------------------------------------------------

  /// Generic retry action.
  String get retry => '重试';

  /// Generic cancel action.
  String get cancel => '取消';

  /// Generic save action.
  String get save => '保存';

  /// Generic delete action.
  String get delete => '删除';

  /// Generic edit action.
  String get edit => '编辑';

  /// Generic "saved" confirmation snackbar.
  String get savedSnack => '已保存';

  /// Generic "load failed" message.
  String get loadFailed => '加载失败';

  /// Generic "save failed, please retry" message.
  String get errorSaveFailed => '保存失败，请重试';

  /// The single "a meal needs at least one item" validation message.
  String get errorNeedAtLeastOneItem => '至少需要一个食物项';

  /// The single "an item needs a name" validation message.
  String get errorFoodNameRequired => '请填写食物名称';

  // ---------------------------------------------------------------------------
  // Bottom navigation & tab app bars
  // ---------------------------------------------------------------------------

  /// Overview (landing) tab label. Period-neutral on purpose: the tab holds
  /// the day, week and month dashboards, so it is not named 今日.
  String get navOverview => '概览';

  /// Food-library tab label.
  String get navFoods => '食物库';

  /// Profile tab label.
  String get navProfile => '我的';

  /// Overview screen app bar title.
  String get overviewTitle => '概览';

  /// Food-library screen app bar title.
  String get foodLibraryTitle => '食物库';

  /// Profile tab app bar title.
  String get profileTabTitle => '我的';

  // ---------------------------------------------------------------------------
  // Dashboard period switcher (概览 tab: 日 / 周 / 月)
  // ---------------------------------------------------------------------------

  /// The day-view segment of the dashboard switcher.
  String get viewDay => '日';

  /// The week-view segment of the dashboard switcher.
  String get viewWeek => '周';

  /// The month-view segment of the dashboard switcher.
  String get viewMonth => '月';

  // ---------------------------------------------------------------------------
  // History period browser (日 / 周 / 月)
  // ---------------------------------------------------------------------------

  /// The current period, as shown in the dashboard's day history header.
  String get historyToday => '今天';

  /// The current period, as shown in the dashboard's week history header.
  String get historyThisWeek => '本周';

  /// The current period, as shown in the dashboard's month history header.
  String get historyThisMonth => '本月';

  /// Header action that jumps back to today's page.
  String get historyBackToToday => '回到今天';

  /// Header action that jumps back to the current week's page.
  String get historyBackToThisWeek => '回到本周';

  /// Header action that jumps back to the current month's page.
  String get historyBackToThisMonth => '回到本月';

  /// Tooltip of the ‹ button in the day view: one day older.
  String get historyPreviousDay => '前一天';

  /// Tooltip of the › button in the day view: one day newer.
  String get historyNextDay => '后一天';

  /// Tooltip of the ‹ button in the week view: one week older.
  String get historyPreviousWeek => '上一周';

  /// Tooltip of the › button in the week view: one week newer.
  String get historyNextWeek => '下一周';

  /// Tooltip of the ‹ button in the month view: one month older.
  String get historyPreviousMonth => '上一月';

  /// Tooltip of the › button in the month view: one month newer.
  String get historyNextMonth => '下一月';

  // ---------------------------------------------------------------------------
  // Today screen
  // ---------------------------------------------------------------------------

  /// Quick-add meal action.
  String get quickAddMeal => '记录一餐';

  /// Quick-add exercise action.
  String get quickAddExercise => '记录运动';

  /// Heading above today's logged meals.
  String get todayLogHeading => '今日记录';

  /// Heading above a past day's logged meals.
  String get historyLogHeading => '当日记录';

  /// Today-meals load failure.
  String get todayMealsError => '今日记录加载失败';

  /// Today-meals empty state.
  String get todayMealsEmpty => '今天还没有记录';

  /// Empty state for a past day with no logged meal.
  String get historyMealsEmpty => '这一天没有记录';

  /// Day-log load failure for a past day (today's failure says 今日).
  String get historyMealsError => '当日记录加载失败';

  // ---------------------------------------------------------------------------
  // Food library (食物库 tab)
  // ---------------------------------------------------------------------------

  /// FAB / empty-state action that opens the add-food flow.
  String get foodLibraryAdd => '添加食物';

  /// Bottom-sheet title for choosing how to add a food.
  String get foodLibraryAddSheetTitle => '添加食物';

  /// Add-food option: photograph a nutrition label and let the AI read it.
  String get foodLibraryAddPhotoTitle => '拍照识别营养标签';

  /// Subtitle of the 拍照识别营养标签 option.
  String get foodLibraryAddPhotoSubtitle => '拍营养成分表，AI 识别后保存';

  /// Add-food option: type the label values by hand (works offline).
  String get foodLibraryAddManualTitle => '手动录入';

  /// Subtitle of the 手动录入 option.
  String get foodLibraryAddManualSubtitle => '自己填写名称与营养数值，可离线';

  /// Hint under the empty-library state.
  String get foodLibraryEmptyHint => '拍一张营养成分表或手动录入，食物就会收进这里';

  // ---------------------------------------------------------------------------
  // Profile hub
  // ---------------------------------------------------------------------------

  /// Profile-details entry title.
  String get profileDetailsTitle => '我的资料';

  /// Profile-details entry subtitle.
  String get profileDetailsSubtitle => '性别 / 生日 / 身高 / 体重 / 基础代谢';

  /// Settings entry title (also the settings app bar).
  String get settingsTitle => '设置';

  /// Settings entry subtitle.
  String get settingsEntrySubtitle => '模型设置与数据显示';

  /// 模型设置 hub entry subtitle.
  String get settingsModelEntrySubtitle => 'API Key / 接口地址 / 模型';

  /// 数据显示 hub entry subtitle.
  String get settingsDisplayEntrySubtitle => '热量单位 / 盐 · 钠显示';

  /// Privacy-notice entry title.
  String get privacyTitle => '隐私说明';

  /// Privacy-notice entry subtitle.
  String get privacyEntrySubtitle => '照片与文字如何处理';

  /// Backup entry title.
  String get backupTitle => '数据备份';

  /// Backup entry subtitle.
  String get backupEntrySubtitle => '导出 / 导入本机数据（JSON）';

  // ---------------------------------------------------------------------------
  // Router fallbacks
  // ---------------------------------------------------------------------------

  /// Shown when `/today/review` is reached without a draft.
  String get reviewMissingArgs => '没有可确认的识别结果';

  // ---------------------------------------------------------------------------
  // Meal detail route
  // ---------------------------------------------------------------------------

  /// Meal-detail app bar title.
  String get mealDetailTitle => '餐食详情';

  /// Meal-not-found empty state.
  String get mealNotFound => '未找到该餐';

  /// Detail app-bar action that opens the meal editor.
  String get mealEditAction => '编辑';

  /// Detail app-bar action that deletes the whole meal.
  String get mealDeleteAction => '删除';

  /// Delete confirmation title.
  String get mealDeleteConfirmTitle => '删除这一餐？';

  /// Delete confirmation body: the meal and every item go away, and the
  /// live day/week rollups follow.
  String get mealDeleteConfirmBody => '整餐（含全部条目）会被移除，当日与本周累计会随之更新，且无法恢复。';

  /// Snackbar after a meal was deleted.
  String get mealDeletedSnack => '已删除';

  /// Review-screen banner in edit mode: the rows show the meal's stored
  /// values, not an AI estimate.
  String get reviewEditBanner => '已保存的记录，可直接修改';

  /// Heading above the review screen's meal-type selector.
  String get reviewMealTypeLabel => '餐次';

  /// Heading above the review screen's meal-time row.
  String get reviewMealTimeLabel => '用餐时间';

  /// Helper under the review screen's meal-time row: an edit moves the meal to
  /// another day's log, so the copy says what changing it does.
  String get reviewMealTimeHelp => '改到别的日期会把这一餐移到那一天';

  /// Title of the meal-time date picker dialog.
  String get reviewMealTimeDatePickerTitle => '选择用餐日期';

  /// Title of the meal-time time picker dialog.
  String get reviewMealTimeTimePickerTitle => '选择用餐时间';

  /// Heading above a meal's food list.
  String get mealItemsHeading => '本餐食物';

  /// A meal-detail item line with a pre-formatted energy value, so the
  /// kcal/kJ display preference owns the unit: `150 g · 350 kcal` /
  /// `150 g · 1464 kJ`.
  String mealDetailItemLineWith(String grams, String energy) =>
      '$grams g · $energy';

  /// A day-log food row's weight line: `150 g`.
  String foodGrams(String grams) => '$grams g';

  // ---------------------------------------------------------------------------
  // Per-meal summary card
  // ---------------------------------------------------------------------------

  /// Breakfast label.
  String get mealTypeBreakfast => '早餐';

  /// Lunch label.
  String get mealTypeLunch => '午餐';

  /// Dinner label.
  String get mealTypeDinner => '晚餐';

  /// Snack label.
  String get mealTypeSnack => '加餐';

  /// This-meal totals block title.
  String get mealTotalsThis => '本餐合计';

  /// Day running totals block title.
  String get mealTotalsToday => '今日累计';

  // ---------------------------------------------------------------------------
  // Daily summary
  // ---------------------------------------------------------------------------

  /// Daily dashboard heading.
  String get dailySummaryTitle => '今日汇总';

  /// Daily dashboard heading for a past day.
  String get historyDailySummaryTitle => '当日汇总';

  /// Exercise-burn metric label.
  String get labelExerciseBurn => '运动消耗';

  /// Daily budget metric label.
  String get labelDailyBudget => '今日额度';

  /// Profile prompt when the budget cannot be computed.
  String get dailyProfilePrompt => '完善资料以显示每日额度与缺口/盈余';

  /// Salt metric value: `3.5 / 5`.
  String saltProgress(String current, String target) => '$current / $target';

  /// Signed-balance label: deficit — relative to the daily budget
  /// (goal-or-BMR + exercise), which is what 今日额度 shows.
  String get balanceDeficit => '缺口(相对额度)';

  /// Signed-balance label: surplus — relative to the daily budget.
  String get balanceSurplus => '盈余(相对额度)';

  /// Signed-balance label: exactly on budget.
  String get balanceBalanced => '平衡';

  // ---------------------------------------------------------------------------
  // Weekly summary
  // ---------------------------------------------------------------------------

  /// Weekly dashboard heading.
  String get weeklyTitle => '本周汇总';

  /// Weekly dashboard heading for a past week.
  String get historyWeeklyTitle => '周汇总';

  /// Weekly empty state.
  String get weeklyEmpty => '本周暂无记录';

  /// Empty state for a past week with no logged meal.
  String get historyWeeklyEmpty => '这一周暂无记录';

  /// The base-budget target line label.
  static const String weeklyTargetLineLabelConst = '基础代谢(不含运动)';

  /// The base-budget target line label.
  String get weeklyTargetLineLabel => weeklyTargetLineLabelConst;

  /// The dashed-line legend: `虚线：基础代谢(不含运动)`.
  String targetLegend(String label) => '虚线：$label';

  /// Intake-bar legend item.
  String get legendIntake => '摄入';

  /// Burn-bar legend item.
  String get legendBurn => '消耗';

  /// Cumulative intake metric label.
  String get labelTotalIntake => '总摄入';

  /// Cumulative burn metric label (basal metabolism + exercise).
  String get labelTotalBurn => '总消耗';

  /// Cumulative difference metric label (`总摄入 - 总消耗`).
  String get labelDifference => '差值';

  /// Logged-days metric label.
  String get labelLoggedDays => '记录天数';

  /// Salt-adherence metric label.
  String get labelSaltAdherence => '盐达标';

  /// Sodium-adherence metric label (shown when the display basis is sodium).
  String get labelSodiumAdherence => '钠达标';

  /// Profile prompt under the week/month summary card (shared by both cards).
  String get periodProfilePrompt => '完善资料以显示基础代谢虚线与总消耗';

  /// Long-press tooltip row for a chart day with no logged meal.
  String get weeklyTooltipUnlogged => '未记录';

  /// Const form of the Monday..Sunday x-axis labels.
  static const List<String> weekdayLabelsConst = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  /// Monday..Sunday short labels for the weekly chart (0 = Monday).
  List<String> get weekdayLabels => weekdayLabelsConst;

  // ---------------------------------------------------------------------------
  // Monthly summary
  // ---------------------------------------------------------------------------

  /// Monthly dashboard heading.
  String get monthlyTitle => '本月汇总';

  /// Monthly dashboard heading for a past month.
  String get historyMonthlyTitle => '月汇总';

  /// Monthly empty state.
  String get monthlyEmpty => '本月暂无记录';

  /// Empty state for a past month with no logged meal.
  String get historyMonthlyEmpty => '这一月暂无记录';

  // ---------------------------------------------------------------------------
  // Exercise burn (one editable kcal value per local day)
  // ---------------------------------------------------------------------------

  /// Exercise-burn app bar title.
  String get exerciseTitle => '运动消耗';

  /// The burn field label.
  String get labelExerciseKcal => '运动消耗 (kcal)';

  /// Clear-today's-burn action.
  String get clearExercise => '清除';

  /// The day selector's field label.
  String get exerciseDateLabel => '记录日期';

  /// Today, as a day choice.
  String get exerciseDayToday => '今天';

  /// Yesterday, as a day choice.
  String get exerciseDayYesterday => '昨天';

  /// Title of the date picker dialog: `选择记录日期`.
  String get exerciseDatePickerTitle => '选择记录日期';

  /// The selected day's stored burn: `已记录：300 kcal`.
  String exerciseDayValue(String kcal) => '已记录：$kcal kcal';

  /// The selected day has no exercise burn yet.
  String get exerciseDayEmpty => '还没有记录运动消耗';

  /// The selected day's stored burn is being read.
  String get exerciseDayLoading => '读取中…';

  /// Validation: the burn must be positive.
  String get errorExerciseKcalPositive => '请输入大于 0 的运动消耗';

  // ---------------------------------------------------------------------------
  // Meal capture
  // ---------------------------------------------------------------------------

  /// Meal-capture app bar title.
  String get captureMealTitle => '记录一餐';

  /// Description field label.
  String get labelDescription => '文字描述（可选）';

  /// Description field hint.
  String get hintDescription => '例如：两个鸡蛋一碗米饭';

  /// Camera action.
  String get capturePhoto => '拍照';

  /// Gallery action.
  String get captureGallery => '相册';

  /// Photo count hint: `最多 3 张照片（已选 1/3）`.
  String capturePhotoCountHint(int count, int max) =>
      '最多 3 张照片（已选 $count/$max）';

  /// Submit action.
  String get startRecognition => '开始识别';

  /// Privacy hint under the submit button.
  String get capturePrivacyHint => '照片与文字将发送到你配置的第三方 AI 服务，仅用于估算营养。';

  /// Remove-thumbnail tooltip.
  String get remove => '移除';

  // ---------------------------------------------------------------------------
  // Voice input (handed to the keyboard's own microphone)
  // ---------------------------------------------------------------------------

  /// The voice entry under the description field.
  String get voiceInputAction => '语音输入';

  /// Hint line beside the voice entry.
  String get voiceInputHint => '点这里，用键盘上的麦克风说话';

  /// Shown after tapping the voice entry: where the IME's microphone key is.
  String get voiceKeyboardHint => '已打开键盘：点键盘上的麦克风图标说话，文字会出现在输入框里';

  // ---------------------------------------------------------------------------
  // Review placeholder (task 18)
  // ---------------------------------------------------------------------------

  /// Placeholder app bar title.
  String get reviewPlaceholderTitle => 'AI 识别结果（占位）';

  /// The always-on AI-estimate banner.
  static const String reviewAiBannerConst = 'AI 估算，可修改';

  /// The always-on AI-estimate banner.
  String get reviewAiBanner => reviewAiBannerConst;

  /// Placeholder body note.
  String get reviewPlaceholderBody => '编辑功能将在下一步实现（任务 19）。';

  /// A placeholder item line with every macro.
  String reviewPlaceholderItemLine({
    required String grams,
    required String kcal,
    required String carb,
    required String protein,
    required String fat,
    required String salt,
  }) =>
      '$grams g · $kcal kcal · 碳水 $carb g · 蛋白 $protein g · '
      '脂肪 $fat g · 盐 $salt g';

  /// Confidence chip: `置信 0.85`.
  String confidenceLabel(String value) => '置信 $value';

  // ---------------------------------------------------------------------------
  // Label capture
  // ---------------------------------------------------------------------------

  /// Label-capture app bar title (photo / AI path).
  String get labelTitle => '识别营养标签';

  /// Label-capture app bar title when it was opened straight into manual entry.
  String get labelManualTitle => '手动录入';

  /// Label-capture app bar title in the edit-nutrients flow (food detail page).
  String get labelEditTitle => '编辑数值';

  /// Confirmation-step hint in the edit-nutrients flow.
  String get labelEditHint => '修改后保存，将直接更新这个食物（每 100 g / 100 mL）';

  /// Confirmation action on the saved step: returns to the food library.
  String get labelDoneAction => '完成';

  /// Saved snackbar for a label food.
  String get labelSavedSnack => '已保存为官方标签食品';

  /// Saved snackbar when more than one label food was saved at once.
  String labelSavedSnackCount(int count) => '已保存 $count 个官方标签食品';

  /// Parsing progress message.
  String get labelRecognizing => '正在识别标签…';

  /// Pick-step hint.
  String get labelPickHint => '拍摄或选择营养成分表照片，识别后请逐项核对再保存。照片里有多张标签也会一起识别。';

  /// Caption above the picked-photo preview.
  String get labelPhotoSelected => '已选择照片（识别前请确认是否清晰、是否选对）';

  /// Pick-step: the selected photo preview failed to render.
  String get labelPhotoPreviewFailed => '照片预览失败，请重新选择';

  /// Supplementary-text field label.
  String get labelSupplementLabel => '文字补充（可选）';

  /// Supplementary-text field hint.
  String get labelSupplementHint => '例如：这是乐事原味薯片，一包 70 g；别名：薯片';

  /// Supplementary-text helper line.
  String get labelSupplementHelp => '会作为识别线索，并预填到下面每张标签的备注里';

  /// Take-a-photo action.
  String get labelTakePhoto => '拍照';

  /// Retake-photo action.
  String get labelRetakePhoto => '重新拍照';

  /// Reselect-photo action (gallery).
  String get labelReselectPhoto => '重新选择';

  /// Select-photo action (gallery).
  String get labelSelectPhoto => '从相册选择';

  /// Parse action.
  String get labelRecognize => '识别标签';

  /// Manual-entry fallback action.
  String get labelManualEntry => '手动录入标签数值';

  /// Confirm-step hint.
  String get labelConfirmHint => '请核对以下标签数值后再保存（每 100 g / 100 mL）';

  /// Confirm-step hint when the photo produced more than one label.
  String labelRecognizedCount(int count) =>
      '照片中识别到 $count 张标签，请逐张核对；不需要保存的可以关闭开关。';

  /// One label card's title: `标签 1`.
  String labelCardTitle(int index) => '标签 $index';

  /// Per-label include switch label.
  String get labelInclude => '保存这张标签';

  /// Per-label exclude explanation.
  String get labelIncludeHint => '关闭后不会保存这张标签';

  /// Food-name field label.
  String get labelFoodName => '食品名称';

  /// Food-name field hint.
  String get labelFoodNameHint => '例如：某品牌苏打饼干';

  /// Food-name helper: the model pre-filled a guess from the packaging.
  String get labelFoodNameFromImage => '由照片中的包装推断，请核对或修改';

  /// Brand field label.
  String get labelBrand => '品牌（可选）';

  /// Brand field hint.
  String get labelBrandHint => '例如：乐事';

  /// Notes field label.
  String get labelNotes => '别名 / 份量（可选）';

  /// Notes field hint.
  String get labelNotesHint => '例如：一包 45 g；别名：小饼干';

  /// A form field label with its full-width unit: `能量（kJ）`.
  String fieldLabelFullWidth(String label, String unit) => '$label（$unit）';

  /// Energy field helper when blank.
  String get labelEnergyBlankHint => '留空表示标签未提供能量';

  /// Energy field helper with the parsed value.
  String foodEnergyApprox(String kcal) => '≈ $kcal kcal';

  /// Energy field helper with the converted value, shown under a 大卡 (kcal)
  /// input.
  String foodEnergyKjApprox(String kJ) => '≈ $kJ kJ';

  /// Confirm-and-save action.
  String get labelConfirmSave => '确认并保存';

  /// Confirm-and-save action for a batch of labels.
  String labelConfirmSaveCount(int count) => '保存全部（$count 个）';

  /// Saved-step line: `已保存：某品牌苏打饼干`.
  String labelSaved(String name) => '已保存：$name';

  /// Saved-step source line.
  String get labelSourceLine => '来源：官方标签（每 100 g）';

  /// Generic recognition failure.
  String get labelRecognizeFailed => '识别失败';

  /// Label validation: food name required.
  String get errorLabelFoodNameRequired => '请填写食品名称';

  /// Label validation: the [index]-th label (1-based) needs a name.
  String errorLabelFoodNameRequiredAt(int index) => '请填写第 $index 张标签的食品名称';

  /// Label validation: every label is excluded from the save.
  String get errorLabelSelectAtLeastOne => '请至少保留一张要保存的标签';

  /// Label parse: photo could not be decoded.
  String get errorPhotoDecode => '照片无法解码，请重新选择';

  // ---------------------------------------------------------------------------
  // Review / edit (task 19)
  // ---------------------------------------------------------------------------

  /// Review app bar title.
  String get reviewTitle => '确认这一餐';

  /// Offline notice on the review screen (const for the widget default).
  static const String reviewOfflineNoticeConst = '当前无网络，AI 无法重新估算；已识别内容仍可编辑并保存';

  /// Offline notice on the review screen.
  String get reviewOfflineNotice => reviewOfflineNoticeConst;

  /// Title of the AI-correction panel on the review screen.
  String get reviewCorrectionTitle => '识别不准？补充说明让 AI 重新估算';

  /// Label of the correction text field.
  String get reviewCorrectionLabel => '补充说明';

  /// Hint of the correction text field.
  String get reviewCorrectionHint => '例如：这是牛肉面，不是牛肉粉；米饭其实有两碗';

  /// Helper under the correction text field.
  String get reviewCorrectionHelp => 'AI 会结合照片与说明重新生成全部条目';

  /// Action that re-runs the AI with the correction note.
  String get reviewReviseButton => '让 AI 重新估算';

  /// Snackbar shown after the AI re-estimated the meal.
  String get reviewReviseSuccess => 'AI 已按补充说明重新估算';

  /// Reactive failure message for a revision that failed for a non-AI reason.
  String get reviewReviseFailed => '重新估算失败，请重试';

  /// Title of the overwrite confirmation shown when the draft has edits.
  String get reviewReviseOverwriteTitle => '重新估算？';

  /// Body of the overwrite confirmation shown when the draft has edits.
  String get reviewReviseOverwriteBody => 'AI 会重新生成所有条目，你当前的修改将被覆盖。';

  /// Confirm action of the overwrite confirmation.
  String get reviewReviseOverwriteConfirm => '继续';

  /// Cancel action of the overwrite confirmation.
  String get reviewReviseOverwriteCancel => '取消';

  /// Add-item action.
  String get addFood => '添加食物';

  /// Food-name field label.
  String get reviewFoodName => '食物名称';

  /// A review field label with an ASCII unit: `克数 (g)`.
  String fieldLabelParen(String label, String unit) => '$label ($unit)';

  /// Adopted saved food: `已采用：全脂牛奶`.
  String adoptedFood(String name) => '已采用：$name';

  /// Select-saved-food action.
  String get selectSavedFood => '选择已存食物';

  // ---------------------------------------------------------------------------
  // Saved foods
  // ---------------------------------------------------------------------------

  /// Provenance badge: an official label food.
  String get foodSourceLabel => '官方标签';

  /// Provenance badge: an AI estimate.
  String get foodSourceAi => 'AI估算';

  /// Provenance badge: manual entry.
  String get foodSourceManual => '手动录入';

  /// The label-suggestion banner copy (legacy exact-name wording).
  static const String labelSuggestionMessageConst = '你已存过该食物的标签，采用?';

  /// The label-suggestion banner copy (legacy exact-name wording).
  String get labelSuggestionMessage => labelSuggestionMessageConst;

  /// Banner title when a saved food's name matches the AI item exactly.
  ///
  /// [foodLabel] already carries the brand when the food has one
  /// (see [foodLabelWithBrand]), e.g. `库内已存该食物的标签：全脂牛奶（光明），采用?`.
  String suggestionBannerExactMessage(String foodLabel) =>
      '库内已存该食物的标签：$foodLabel，采用?';

  /// Banner title for a partial / alias / similar-name saved-food candidate.
  ///
  /// e.g. `库内相近：光明 全脂牛奶（光明），采用?`.
  String suggestionBannerSimilarMessage(String foodLabel) =>
      '库内相近：$foodLabel，采用?';

  /// Match-reason line: the names are identical after normalization.
  String get suggestionReasonExactName => '名称一致';

  /// Match-reason line: the AI name equals an alias recorded on the food.
  String suggestionReasonAlias(String alias) => '别名一致：$alias';

  /// Match-reason line: an alias matched but its text is unknown.
  String get suggestionReasonAliasPlain => '别名一致';

  /// Match-reason line: one name contains the other.
  String get suggestionReasonPartialName => '名称相近';

  /// Match-reason line: the names share most characters (bigram similarity).
  String get suggestionReasonSimilarName => '名称相似';

  /// Heading of the secondary candidates row.
  String get otherSuggestions => '其他相近';

  // ---------------------------------------------------------------------------
  // Label linking (analyze-then-link)
  // ---------------------------------------------------------------------------

  /// A row whose label was matched and applied automatically:
  /// `已匹配：辛拉面(农心)`.
  String linkMatchedFood(String foodLabel) => '已匹配：$foodLabel';

  /// Undo an auto-applied label match and go back to the AI estimate.
  String get linkUndo => '撤销';

  /// Change the matched label: opens the saved-food picker.
  String get linkChange => '更换';

  /// A saved food's display label: `全脂牛奶（光明）`, or just the name.
  String foodLabelWithBrand(String name, String? brand) =>
      brand == null || brand.trim().isEmpty ? name : '$name（$brand）';

  /// Apply-suggestion action.
  String get applySuggestion => '采用';

  /// Saved-food picker app bar.
  String get savedFoodPickerTitle => '选择已存食物';

  /// Saved-food search hint.
  String get savedFoodSearchHint => '搜索食物';

  /// Saved-food load failure.
  String get savedFoodsLoadFailed => '已存食物加载失败';

  /// No saved foods yet.
  String get savedFoodsEmpty => '食物库还是空的';

  /// No search match.
  String get savedFoodsNoMatch => '没有匹配的已存食物';

  /// Saved-food detail app bar.
  String get savedFoodDetailTitle => '食物信息';

  /// Detail: the brand row, e.g. `品牌：光明`.
  String foodDetailBrandLine(String brand) => '品牌：$brand';

  /// Detail: the notes / aliases label shown above the free-text value.
  String get foodDetailNotes => '备注';

  /// Detail: the per-100 g nutrition heading.
  String get foodDetailPer100g => '营养成分（每 100 g）';

  /// Detail: a nutrient the saved food's source left blank.
  String get foodDetailNotProvided => '未提供';

  /// Action / tooltip that opens a saved food's detail.
  String get viewFoodInfo => '查看信息';

  // ---------------------------------------------------------------------------
  // Saved-food supplement (补充信息)
  // ---------------------------------------------------------------------------

  /// Editor app bar title: identity plus supplement in one form.
  String get foodEditTitle => '编辑食物信息';

  /// Detail app-bar action that opens the editor.
  String get foodEditAction => '编辑';

  /// Detail-page action that opens the nutrient-value editor (编辑数值).
  String get foodNutrientsEditAction => '编辑数值';

  /// Detail-page dialog title: offer to recompute logged records after a
  /// nutrient edit.
  String get foodRecomputeTitle => '重算历史记录？';

  /// Body of the recompute dialog: how many logged items across how many
  /// meals would be recomputed.
  String foodRecomputeBody(int items, int meals) =>
      '这个食物有 $items 条已记录的摄入（跨 $meals 餐），按刚保存的数值一并重算？';

  /// Confirm action of the recompute dialog.
  String get foodRecomputeConfirm => '重算';

  /// Snackbar after the batch recompute.
  String foodRecomputeSnack(int items) => '已重算 $items 条记录';

  /// Detail app-bar action that deletes the food from the catalogue.
  String get foodDeleteAction => '删除';

  /// Delete confirmation title.
  String get foodDeleteConfirmTitle => '删除这个食物？';

  /// Delete confirmation body: [name] is the food's name; logged meal items
  /// survive the deletion by contract.
  String foodDeleteConfirmBody(String name) => '「$name」会从食物库移除。已有的饮食记录不受影响。';

  /// Snackbar after a food was deleted.
  String get foodDeletedSnack => '已删除';

  /// Identity card heading on the detail page.
  String get foodInfoTitle => '基本信息';

  /// Placeholder for an identity field the food does not carry yet.
  String get foodDetailNotFilled => '未填写';

  /// Label of the saved food's name field in the editor.
  String get foodNameFieldLabel => '名称';

  /// Label of the saved food's brand field in the editor.
  String get foodBrandFieldLabel => '品牌';

  /// Validation: a saved food must keep a non-blank name.
  String get foodNameRequired => '食物名称不能为空';

  /// Editor save action.
  String get foodSupplementSave => '保存';

  /// Snackbar after the food was saved.
  String get foodSupplementSaved => '已保存';

  /// Editor label of the alias field.
  String get foodAliasesLabel => '别名';

  /// Editor hint: aliases are separated by the app's usual punctuation.
  String get foodAliasesHint => '用、或逗号分隔，最多 10 个';

  /// Editor helper: why aliases matter.
  String get foodAliasesHelp => '以后可按别名搜索、匹配这份食物';

  /// Editor label of the servings field.
  String get foodServingsLabel => '份量';

  /// Editor hint: how one serving is written.
  String get foodServingsHint => '例如：一袋 120 g、一块 30 g';

  /// Editor helper: serving format and lossy-parse contract.
  String get foodServingsHelp => '按「一袋 120 g」的格式填写，最多 3 条；无法识别的条目会被忽略';

  /// Editor label of the archive switch.
  String get foodStatusLabel => '状态';

  /// Status: still searched, matched and suggested.
  String get foodStatusActive => '仍在使用';

  /// Status: retired from matching (also the list / detail badge).
  String get foodStatusArchived => '已停用';

  /// Editor label of the per-100 basis selector.
  String get foodBasisLabel => '营养成分基准';

  /// Basis option: nutrients are per 100 g.
  String get foodBasisPer100g => '每 100 g';

  /// Basis option: nutrients are per 100 ml.
  String get foodBasisPer100ml => '每 100 ml';

  /// Detail: the aliases row, e.g. `别名：小饼干、牛奶`.
  String foodDetailAliasesLine(String aliases) => '别名：$aliases';

  /// Detail: the servings row, e.g. `份量：一袋 120 g、一块 30 g`.
  String foodDetailServingsLine(String servings) => '份量：$servings';

  /// Detail: the nutrition heading for a drink (per 100 ml).
  String get foodDetailPer100ml => '营养成分（每 100 ml）';

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Settings load failure.
  String get settingsLoadFailed => '设置加载失败';

  // Settings: model section

  /// Section heading for the AI model configuration.
  String get settingsSectionModel => '模型设置';

  /// Section heading for the display-unit preferences.
  String get settingsSectionDisplay => '数据显示';

  /// Display preference: the energy unit.
  String get displayEnergyTitle => '热量单位';

  /// Display preference subtitle: energy is display-only.
  String get displayEnergySubtitle => '只影响显示，不改动已记录的数据';

  /// Energy option: kilocalories.
  String get displayEnergyKcalOption => '大卡 (kcal)';

  /// Energy option: kilojoules.
  String get displayEnergyKjOption => '千焦 (kJ)';

  /// Display preference: salt vs sodium.
  String get displaySaltTitle => '盐 / 钠显示';

  /// Display preference subtitle: salt vs sodium.
  String get displaySaltSubtitle => '选择用盐还是钠展示盐分数据';

  /// Salt option: grams of salt.
  String get displaySaltOption => '盐 (g)';

  /// Sodium option: milligrams of sodium.
  String get displaySodiumOption => '钠 (mg)';

  /// The display-vs-input rule: displays switch, manual entry defaults to the
  /// selected units and stays switchable per field, and both kinds of data
  /// stay accepted.
  String get displayEntryNote =>
      '只影响显示，不改动已记录的数据。手动录入的默认输入单位跟随这里的设置，输入框内可随时切换（能量 kJ ⇄ kcal，钠 mg ⇄ 盐 g）。';

  // Settings: API-key form

  /// API-key field label.
  String get apiKeyLabel => 'API Key';

  /// API-key hint when a key is already stored.
  String get apiKeyHintSaved => '已保存，输入新值以更新';

  /// API-key hint when none is stored.
  String get apiKeyHintEmpty => '请输入你的 API Key';

  /// API-key helper text.
  String get apiKeyHelper => '仅保存在本机安全存储，不会上传、记录或导出';

  /// Base-URL field label.
  String get baseUrlLabel => 'Base URL';

  /// Base-URL helper text.
  String get baseUrlHelper => 'OpenAI 兼容接口地址';

  /// Model field label.
  String get modelLabel => '模型';

  /// Test-connection action.
  String get testConnection => '测试连接';

  /// Test-connection hint before a key is entered.
  String get testNeedKey => '请先填写 API Key，再测试连接';

  /// Test-connection success.
  String get connectionSuccess => '连接成功';

  /// AI error: no key.
  String get errorNoKey => '请先填写并保存 API Key';

  /// AI error: unauthorized.
  String get errorUnauthorized => '密钥无效';

  /// AI error: rate limited.
  String get errorRateLimited => '请求过于频繁，请稍后重试';

  /// AI error: timeout.
  String get errorTimeout => '连接超时，请重试';

  /// AI error: network unavailable.
  String get errorNetwork => '网络不可用';

  /// AI error: malformed response.
  String get errorMalformedResponse => '服务返回异常，请检查 Base URL 与模型配置';

  /// AI error: server error with [statusCode].
  String errorServer(Object statusCode) => '服务器错误（$statusCode）';

  // ---------------------------------------------------------------------------
  // Offline / AI unavailable
  // ---------------------------------------------------------------------------

  /// Draft-G7 notice shown wherever an AI action is unavailable offline.
  static const String aiUnavailableMessageConst = '当前无网络，AI 不可用，请手动录入';

  /// Draft-G7 notice shown wherever an AI action is unavailable offline.
  String get aiUnavailableMessage => aiUnavailableMessageConst;

  /// Reactive AI failure message: the typed reason plus the two recoveries.
  String aiFailureRetry(String reason) => '$reason，可重试或手动录入';

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  /// Import dialog title.
  String get importBackupTitle => '导入备份';

  /// Import dialog hint.
  String get pasteBackupHint => '粘贴备份 JSON';

  /// Import action.
  String get importAction => '导入';

  /// Backup intro paragraph.
  String get backupIntro =>
      '导出会把本机上的个人资料、食物、餐食与运动写成一个 JSON 文件；'
      '导入只新增本机没有的记录，已存在的不会覆盖。API Key 不在备份中。';

  /// Export action.
  String get exportBackup => '导出备份';

  /// Import action label on the screen.
  String get importBackup => '导入备份';

  /// Export success: `已生成备份（1234 字符）`.
  String backupGenerated(int characters) => '已生成备份（$characters 字符）';

  /// Export failure.
  String backupExportFailed(Object error) => '导出失败：$error';

  /// Import summary: added / skipped rows.
  String backupImported(int added, int skipped) =>
      '导入完成：新增 $added 行，跳过 $skipped 行';

  /// Import failure.
  String backupImportFailed(Object message) => '导入失败：$message';

  // ---------------------------------------------------------------------------
  // Automatic (off-app) backup
  // ---------------------------------------------------------------------------

  /// Automatic-backup section title.
  String get autoBackupTitle => '自动备份';

  /// Automatic-backup explanation paragraph.
  static const String autoBackupIntroConst =
      '每次打开或离开 App，都会自动把整份数据另存到「Download/caldoo」，'
      '保留最近 10 份。它不在 App 私有目录里，所以卸载或清空 App 数据后依然保留，'
      '重装后可从这里或「从文件导入」恢复。';

  /// Automatic-backup explanation paragraph.
  String get autoBackupIntro => autoBackupIntroConst;

  /// Toggle label.
  String get autoBackupToggle => '开启自动备份';

  /// Where the copies live, shown under the toggle.
  static const String autoBackupLocationConst = '文件位置：Download/caldoo';

  /// Where the copies live, shown under the toggle.
  String get autoBackupLocation => autoBackupLocationConst;

  /// Shown when the platform has no durable backup target.
  String get autoBackupUnavailable => '当前设备不支持自动备份';

  /// Status when no automatic copy exists yet.
  String get autoBackupNever => '还没有自动备份';

  /// Status when copies exist: `最近一次 2026年10月30日 21:15 · 共 3 份`.
  String autoBackupLastAt(String when, int count) => '最近一次 $when · 共 $count 份';

  /// The manual "back up now" action.
  String get autoBackupNow => '立即备份';

  /// Success message after a manual backup.
  String autoBackupSaved(String fileName) => '已保存自动备份：$fileName';

  /// A manual backup over an empty database.
  String get autoBackupSkippedEmpty => '本机还没有数据，无需备份';

  /// A failed manual backup.
  String autoBackupFailed(Object error) => '自动备份失败：$error';

  /// Confirm dialog title for restoring an automatic copy.
  static const String autoBackupRestoreTitleConst = '恢复这份自动备份？';

  /// Confirm dialog title for restoring an automatic copy.
  String get autoBackupRestoreTitle => autoBackupRestoreTitleConst;

  /// Confirm dialog body: what will be imported and the additive policy.
  String autoBackupRestoreBody(String when, String size) =>
      '将导入 $when 的自动备份（$size）。只新增本机没有的记录，'
      '已存在的记录不会覆盖。';

  /// Confirm action for restoring an automatic copy.
  String get autoBackupRestoreAction => '恢复';

  /// Import action that opens the system file picker.
  String get backupImportFromFile => '从文件导入（data.json）';

  /// Shown when the file picker was dismissed without a file.
  String get backupImportFileCancelled => '未选择文件';

  /// Shown when a listed copy can no longer be read (e.g. previous install).
  String autoBackupMissing(String fileName) => '无法读取这份备份：$fileName';

  // ---------------------------------------------------------------------------
  // Privacy notice
  // ---------------------------------------------------------------------------

  /// Privacy intro line.
  String get privacyIntro => '开始记录前，请先了解本应用如何处理你的数据：';

  /// Privacy bullet 1.
  String get privacyBullet1 =>
      '你主动提交的照片与文字记录，会通过你自己填写的 API Key，'
      '发送到你自己指定的第三方 AI 服务提供商（例如 DeepSeek），'
      '仅用于识别与分析。';

  /// Privacy bullet 2.
  String get privacyBullet2 =>
      '除此之外，照片与文字不会发送到任何其他服务器；'
      '开发者既看不到你的 API Key，也看不到你的照片与记录。';

  /// Privacy bullet 3.
  String get privacyBullet3 => '你的饮食、运动与个人资料等数据只保存在本机设备上。';

  /// Privacy bullet 4.
  String get privacyBullet4 => '若你不同意，请不要使用需要 AI 分析的拍照或文字识别功能。';

  /// Accept action.
  String get privacyAccept => '我已了解并继续';

  /// A privacy bullet line.
  String bullet(String text) => '• $text';

  // ---------------------------------------------------------------------------
  // Delete all data
  // ---------------------------------------------------------------------------

  /// Delete confirmation title.
  String get deleteConfirmTitle => '删除全部本机数据？';

  /// Delete confirmation body.
  String get deleteConfirmBody =>
      '这会永久删除本机上的所有饮食、运动与个人资料数据，以及已保存的 API Key。'
      '此操作无法撤销。';

  /// Data-deleted snackbar.
  String get dataDeletedSnack => '本机数据已删除';

  /// Delete-all-data action.
  String get deleteAllData => '删除全部本机数据';

  // ---------------------------------------------------------------------------
  // Profile form
  // ---------------------------------------------------------------------------

  /// Profile validation message (anthropometrics).
  String get profileValidationError => '请输入有效的身高和体重（均须大于 0）';

  /// Profile app bar title.
  String get profileTitle => '我的资料';

  /// Sex field label.
  String get sexLabel => '性别';

  /// Male segment.
  String get sexMale => '男';

  /// Female segment.
  String get sexFemale => '女';

  /// Birthday field label.
  String get labelBirthday => '生日';

  /// Birthday field placeholder before a date is picked.
  String get birthdayPlaceholder => '点击选择生日';

  /// Birthday field helper: explains that age is derived.
  String get helperBirthday => '年龄按生日自动计算，无需每年修改';

  /// Derived-age readout under the birthday field.
  String ageFromBirthday(int years) => '当前年龄：$years 岁';

  /// Date-picker dialog help text.
  String get birthdayPickerHelp => '选择生日';

  /// Birthday validation message.
  String get profileBirthdayValidationError => '请选择生日（需早于今天，且年龄大于 0）';

  /// Height field label.
  String get labelHeight => '身高（cm）';

  /// Weight field label.
  String get labelWeight => '体重（kg）';

  /// Weight field helper.
  String get helperWeight => '可随时修改，保存后重新计算基础代谢';

  /// Basal-metabolic-rate field label.
  String get labelBmr => '基础代谢消耗 (kcal)';

  /// Basal-metabolic-rate field helper.
  String get helperBmr => '按性别 / 生日 / 身高 / 体重自动计算，也可直接修改';

  /// Restores the auto-computed BMR after a manual edit.
  String get bmrAutoButton => '自动计算';

  /// BMR validation message: a manual BMR must be a positive number.
  String get profileBmrValidationError => '基础代谢消耗需为大于 0 的数字';

  /// Salt target title.
  String get saltTargetTitle => '每日盐目标';

  /// Salt-target title when the display basis is sodium.
  String get sodiumTargetTitle => '每日钠目标';

  /// Salt target subtitle.
  String get saltTargetSubtitle => '固定值，不随资料变化，也不可修改';

  /// Salt target value: `5 g`.
  String saltTargetValue(String grams) => '$grams g';

  /// The fixed daily sodium target: `2000 mg`.
  String sodiumTargetValue(String mg) => '$mg mg';

  /// Budget-incomplete prompt.
  String get profileBudgetIncomplete => '完善资料以计算每日额度';

  /// Base budget title.
  String get profileBaseBudgetTitle => '每日基础额度';

  /// Base budget value: `1935 kcal`.
  String budgetValue(String kcal) => '$kcal kcal';

  /// Base budget note.
  String get profileBaseBudgetNote => '即基础代谢消耗，不含刻意运动；记录运动后在此基础上叠加';

  /// Base budget note when a daily goal is set (the baseline is the goal).
  String get profileBaseBudgetNoteGoal => '即每日热量目标，不含刻意运动；记录运动后在此基础上叠加';

  /// Generic "not set" placeholder.
  String get notSet => '未设置';

  // ===== 每日热量目标 =====

  /// Daily-goal card title on the profile screen.
  String get dailyGoalTitle => '每日热量目标';

  /// Daily-goal card subtitle when no goal is set.
  String get dailyGoalSubtitleNone => '未设置，按基础代谢计算每日额度';

  /// Daily-goal card subtitle: the goal equals the resolved BMR.
  String get dailyGoalSubtitleMaintain => '维持体重，与基础代谢相同';

  /// Daily-goal card subtitle: goal below the resolved BMR (`diff` kcal/day).
  String dailyGoalSubtitleCut(int diff) => '低于基础代谢 $diff 大卡/日';

  /// Daily-goal card subtitle: goal above the resolved BMR (`diff` kcal/day).
  String dailyGoalSubtitleGain(int diff) => '高于基础代谢 $diff 大卡/日';

  /// Goal sheet title.
  String get dailyGoalSheetTitle => '每日热量目标';

  /// Goal sheet caption (`bmr` = the resolved basal metabolic rate).
  String dailyGoalSheetCaption(int bmr) => '基础代谢 $bmr 大卡/日。不设目标时，每日额度就按基础代谢算。';

  /// Preset: keep the resolved BMR (no explicit goal).
  String get goalPresetMaintain => '维持体重';

  /// Preset: gentle deficit.
  String get goalPresetSlowCut => '缓慢减脂';

  /// Preset: faster deficit.
  String get goalPresetFastCut => '较快减脂';

  /// Preset: surplus.
  String get goalPresetGain => '增肌增重';

  /// Subtitle of the 维持 preset (`bmr` = the resolved BMR).
  String goalPresetMaintainSub(int bmr) => '不设目标，按基础代谢 $bmr 大卡';

  /// Subtitle of the −250 preset (`bmr` = the resolved BMR).
  String goalPresetSlowCutSub(int bmr) =>
      '基础代谢 − 250 = ${bmr - 250} 大卡 · 每周约 −0.25 kg';

  /// Subtitle of the −500 preset (`bmr` = the resolved BMR).
  String goalPresetFastCutSub(int bmr) =>
      '基础代谢 − 500 = ${bmr - 500} 大卡 · 每周约 −0.5 kg';

  /// Subtitle of the +250 preset (`bmr` = the resolved BMR).
  String goalPresetGainSub(int bmr) =>
      '基础代谢 + 250 = ${bmr + 250} 大卡 · 每周约 +0.25 kg';

  /// Custom-goal row label.
  String get goalCustomLabel => '或自定义';

  /// Custom-goal unit suffix.
  String get goalCustomUnit => '大卡/日';

  /// Preview line when no goal is set (`bmr`, `exercise`, `total` in kcal).
  String goalPreviewNoGoal(int bmr, int exercise, int total) =>
      '不设目标，按基础代谢 $bmr + 运动 $exercise = 每日额度 $total 大卡';

  /// Preview line with a goal (`goal`, `exercise`, `total` in kcal).
  String goalPreview(int goal, int exercise, int total) =>
      '目标 $goal + 运动 $exercise = 每日额度 $total 大卡';

  /// Restores the no-goal default (clears the stored goal).
  String get goalRestoreDefault => '恢复默认（不设目标）';

  /// Goal validation: a positive whole kcal integer is required.
  String get goalValidationError => '目标需为大于 0 的整数';

  /// Soft health hint shown for very low custom goals (never blocking).
  String get goalLowHint => '提示：不建议长期低于 1200 大卡/日';

  /// Daily subline under 今日额度 when a goal is set (`goal` + `exercise`).
  String dailyGoalSubline(int goal, int exercise) => '目标 $goal + 运动 $exercise';

  /// Daily subline under 今日额度 when NO goal is set: the budget composition
  /// is always shown, so 额度 never reads as an unexplained number.
  String budgetBmrSubline(int bmr, int exercise) => '基础代谢 $bmr + 运动 $exercise';

  /// Weekly/monthly calorie-adherence value (`adherent` of `logged` days).
  String goalAdherenceDays(int adherent, int logged) => '$adherent/$logged 天';

  /// Weekly/monthly 热量达标 tile label (only rendered when a goal is set).
  String get labelGoalAdherence => '热量达标';

  // ===== 体重历史 =====

  /// Weight card title on the dashboard.
  String get weightCardTitle => '体重';

  /// Weight card record action.
  String get weightRecordAction => '记录';

  /// Weight card prompt when no weight has ever been recorded.
  String get weightCardEmptyPrompt => '还没有记录，点「记录」开始追踪体重';

  /// Weight card hint opening the trend page.
  String get weightCardOpenTrend => '查看趋势';

  /// Weight 7-day delta chip (`delta` like "−0.6").
  String weightDelta7d(String delta) => '$delta · 近7天';

  /// Weight trend screen title.
  String get weightTrendTitle => '体重趋势';

  /// Range chip: last 30 days.
  String get weightRange30 => '近30天';

  /// Range chip: last 90 days.
  String get weightRange90 => '近90天';

  /// Range chip: everything.
  String get weightRangeAll => '全部';

  /// Stat label: latest weight.
  String get weightStatNow => '当前';

  /// Stat label: change over the last 7 recorded days.
  String get weightStat7d => '近7天';

  /// Stat label: change since the first entry.
  String get weightStatAll => '累计';

  /// Empty state of the weight trend page.
  String get weightTrendEmpty => '还没有体重记录，先记一条吧';

  /// Weight entry sheet title (recording a new/other day).
  String get weightEntryTitleRecord => '记录体重';

  /// Weight entry sheet title (editing an existing day).
  String get weightEntryTitleEdit => '修改体重';

  /// Weight entry date field label.
  String get weightEntryDateLabel => '日期';

  /// Weight entry value field label.
  String get weightEntryValueLabel => '体重（kg）';

  /// Weight entry validation message.
  String get weightEntryValidationError => '请输入有效的体重（大于 0）';

  /// Weight entry note: re-recording a day overwrites it.
  String get weightEntryOverwriteNote => '当天已有记录时会覆盖';

  /// Note under the entry sheet: saving also syncs the profile weight.
  String get weightSyncNote => '记录体重会同步更新「我的」里的体重，基础代谢随之重算';

  /// Delete action for a weight row.
  String get weightDeleteAction => '删除';

  /// Confirm title for deleting a weight entry.
  String get weightDeleteConfirmTitle => '删除这条体重记录？';

  /// Snack after deleting a weight entry.
  String get weightDeletedSnack => '已删除';
}
