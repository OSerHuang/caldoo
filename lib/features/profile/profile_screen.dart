/// Profile & settings screen.
///
/// Collects the Mifflin-St Jeor anthropometrics (`sex`, `birthDate`,
/// `heightCm`, `weightKg`) and derives both the **age** and a **basal
/// metabolic rate (基础代谢消耗)** from them. The age is computed from the
/// birthday on today's date, so the user never has to edit it year after year;
/// the derived BMR is shown in an editable field, so a user who knows their own
/// number can pin it (a non-null [UserProfile.bmrKcalOverride] then wins over
/// the estimate, and "自动计算" restores the derived value).
///
/// There is deliberately **no activity-level picker**: the exercise-free daily
/// baseline is the resolved BMR itself, and logged exercise is added on top by
/// the energy engine. The screen also shows two fixed/derived facts:
/// * a READ-ONLY **5 g/day** salt target (the WHO adult recommendation,
///   deliberately not configurable and with no child mode);
/// * the exercise-free daily budget from the energy engine, which is HIDDEN
///   behind a "完善资料以计算每日额度" prompt until a complete profile exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'daily_goal_sheet.dart';
import 'profile_providers.dart';

/// Validates the profile form: a birthday that yields an age of at least one,
/// positive height/weight, and an optional manual BMR cell.
///
/// Returns `null` when everything is usable, otherwise a user-facing message.
/// Blank, non-numeric, zero, negative, NaN and infinite height/weight are
/// rejected — the same non-positive guard the energy engine applies, so a
/// malformed value can never reach [UserProfile].
///
/// [bmr] is the manual basal-metabolic-rate text. `null` means the field is in
/// "auto" mode (no override is stored), so it is not validated; when non-null
/// it must parse to a positive **whole** kcal integer (energy is
/// integer-only). A blank manual field is rejected (the user chose manual
/// mode, so the number is required).
String? validateProfileInputs({
  required DateTime? birthDate,
  required String height,
  required String weight,
  String? bmr,
  required DateTime today,
}) {
  final double? parsedHeight = double.tryParse(height.trim());
  final double? parsedWeight = double.tryParse(weight.trim());
  final bool heightOk =
      parsedHeight != null && parsedHeight.isFinite && parsedHeight > 0;
  final bool weightOk =
      parsedWeight != null && parsedWeight.isFinite && parsedWeight > 0;

  // A future birthday yields a non-positive age, which is rejected by the same
  // test as a birthday dated within the last year.
  final bool birthdayOk =
      birthDate != null && ageOnBirthday(birthDate, today) > 0;

  if (!birthdayOk) {
    return S.instance.profileBirthdayValidationError;
  }
  if (!(heightOk && weightOk)) {
    return S.instance.profileValidationError;
  }
  if (bmr != null) {
    final int? parsedBmr = int.tryParse(bmr.trim());
    if (parsedBmr == null || parsedBmr <= 0) {
      return S.instance.profileBmrValidationError;
    }
  }
  return null;
}

/// The profile & settings screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bmrController = TextEditingController();

  /// Focus node of the weight field: an external weight change (a body-weight
  /// recording from the dashboard card or the trend page) must NOT clobber the
  /// cell while the user is editing it.
  final FocusNode _weightFocus = FocusNode();

  Sex _sex = Sex.male;
  DateTime? _birthDate;

  /// `true` once the user edits the BMR cell themselves. The derived value then
  /// stops tracking the anthropometrics until "自动计算" is tapped.
  bool _bmrManual = false;

  /// Guards the programmatic writes to [_bmrController] so they are not
  /// mistaken for a user edit.
  bool _syncingBmr = false;

  /// The saved profile is seeded into the fields exactly once; afterwards the
  /// form is the user's to edit — EXCEPT the weight cell, which live-tracks
  /// the stored profile (when unfocused): a body-weight recording writes the
  /// profile's weight externally, and the stale form value would otherwise be
  /// written back over it by the next 保存.
  bool _seeded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _heightController.addListener(_syncAutoBmr);
    _weightController.addListener(_syncAutoBmr);
    _bmrController.addListener(_onBmrEdited);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightFocus.dispose();
    _weightController.dispose();
    _bmrController.dispose();
    super.dispose();
  }

  /// The injected "today": the age (and therefore the BMR estimate) is always
  /// derived on it, and the birthday picker never offers a future date.
  DateTime _today() => ref.read(profileClockProvider).now();

  int? _currentAge() {
    final DateTime? birthday = _birthDate;
    if (birthday == null) {
      return null;
    }
    return ageOnBirthday(birthday, _today());
  }

  void _seed(UserProfile profile) {
    if (_seeded) {
      return;
    }
    _sex = profile.sex;
    _birthDate = profile.birthDate;
    _bmrManual = profile.bmrKcalOverride != null;
    _heightController.text = _formatNumber(profile.heightCm);
    _weightController.text = _formatNumber(profile.weightKg);
    final int? override = profile.bmrKcalOverride;
    _setBmrText(override != null ? _formatNumber(override) : _autoBmrText());
    _seeded = true;
  }

  Future<void> _pickBirthday() async {
    final DateTime today = _today();
    DateTime initial =
        _birthDate ?? DateTime(today.year - 30, today.month, today.day);
    // Defensive clamps for a corrupted/legacy row: the picker asserts that its
    // initial date lies inside [firstDate, lastDate].
    if (initial.isAfter(today)) {
      initial = today;
    }
    if (initial.isBefore(DateTime(1900))) {
      initial = DateTime(1900);
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: S.of(context).birthdayPickerHelp,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _birthDate = canonicalBirthDate(picked);
      _syncAutoBmr();
    });
  }

  /// Recomputes the BMR cell unless the user pinned a manual value.
  ///
  /// Runs from the anthropometric listeners on every keystroke (and after a
  /// birthday pick), so the derived number follows the inputs live.
  void _syncAutoBmr() {
    if (_bmrManual) {
      return;
    }
    _setBmrText(_autoBmrText());
  }

  /// Marks the BMR cell as manually overridden after a user edit.
  void _onBmrEdited() {
    if (_syncingBmr || _bmrManual) {
      return;
    }
    setState(() => _bmrManual = true);
  }

  /// Writes [text] into the BMR cell without firing the manual-edit detector.
  void _setBmrText(String text) {
    if (_bmrController.text == text) {
      return;
    }
    _syncingBmr = true;
    _bmrController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncingBmr = false;
  }

  /// The Mifflin-St Jeor BMR for the current anthropometrics, or `null` while
  /// those inputs are incomplete / produce a non-positive estimate.
  int? _autoBmrValue() {
    final int? age = _currentAge();
    final double? height = double.tryParse(_heightController.text.trim());
    final double? weight = double.tryParse(_weightController.text.trim());
    if (age == null ||
        age <= 0 ||
        height == null ||
        !height.isFinite ||
        height <= 0 ||
        weight == null ||
        !weight.isFinite ||
        weight <= 0) {
      return null;
    }
    try {
      final int bmr = mifflinStJeorBmr(
        sex: _sex,
        age: age,
        heightCm: height,
        weightKg: weight,
      );
      return bmr > 0 ? bmr : null;
    } on ArgumentError {
      return null;
    }
  }

  String _autoBmrText() {
    final int? bmr = _autoBmrValue();
    return bmr == null ? '' : _formatNumber(bmr);
  }

  void _restoreAutoBmr() {
    setState(() {
      _bmrManual = false;
      _setBmrText(_autoBmrText());
    });
  }

  Future<void> _save() async {
    final DateTime today = _today();
    final String? validationError = validateProfileInputs(
      birthDate: _birthDate,
      height: _heightController.text,
      weight: _weightController.text,
      bmr: _bmrManual ? _bmrController.text : null,
      today: today,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final int? autoBmr = _autoBmrValue();
    if (!_bmrManual && autoBmr == null) {
      setState(() => _error = S.instance.profileBmrValidationError);
      return;
    }

    // A manually typed number that happens to equal the derived estimate is
    // stored as "auto" (null), so the BMR keeps tracking the anthropometrics.
    int? bmrOverride;
    if (_bmrManual) {
      final int parsed = int.parse(_bmrController.text.trim());
      bmrOverride = parsed == autoBmr ? null : parsed;
    }

    setState(() => _error = null);
    // This save owns EXACTLY the five form fields — sex, birthday, height,
    // weight and the BMR override. Every other profile field (the daily goal
    // above all) is carried over from the stored row verbatim, so saving the
    // form can never wipe something this screen does not edit.
    final int? storedGoal = ref
        .read(storedProfileProvider)
        .value
        ?.dailyKcalGoalOverride;
    await ref
        .read(profileRepositoryProvider)
        .saveProfile(
          UserProfile(
            sex: _sex,
            birthDate: _birthDate!,
            heightCm: double.parse(_heightController.text.trim()),
            weightKg: double.parse(_weightController.text.trim()),
            bmrKcalOverride: bmrOverride,
            dailyKcalGoalOverride: storedGoal,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).savedSnack)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live-sync the weight cell with the stored profile: a body-weight
    // recording (dashboard card / trend page) rewrites the profile's weight
    // externally. Only applies while the cell is not being edited, so an
    // in-progress manual change is never clobbered mid-keystroke.
    ref.listen<AsyncValue<UserProfile?>>(storedProfileProvider, (
      AsyncValue<UserProfile?>? previous,
      AsyncValue<UserProfile?> next,
    ) {
      final UserProfile? profile = next.value;
      if (profile == null || !_seeded || _weightFocus.hasFocus) {
        return;
      }
      final double? fieldWeight = double.tryParse(
        _weightController.text.trim(),
      );
      if (fieldWeight == null || fieldWeight != profile.weightKg) {
        _weightController.text = _formatNumber(profile.weightKg);
      }
    });

    final AsyncValue<UserProfile?> asyncProfile = ref.watch(
      storedProfileProvider,
    );
    final EnergyBudgetResult? budget = ref.watch(profileBudgetProvider);
    final UserProfile? profile = asyncProfile.value;
    if (profile != null) {
      _seed(profile);
    }

    if (asyncProfile.isLoading && !asyncProfile.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context).profileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).profileTitle)),
      body: _buildForm(context, budget),
    );
  }

  Widget _buildForm(BuildContext context, EnergyBudgetResult? budget) {
    final int? age = _currentAge();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(S.of(context).sexLabel),
        const SizedBox(height: 8),
        SegmentedButton<Sex>(
          key: const Key('profile_sex_field'),
          segments: <ButtonSegment<Sex>>[
            ButtonSegment<Sex>(
              value: Sex.male,
              label: Text(S.of(context).sexMale),
            ),
            ButtonSegment<Sex>(
              value: Sex.female,
              label: Text(S.of(context).sexFemale),
            ),
          ],
          selected: <Sex>{_sex},
          onSelectionChanged: (Set<Sex> selection) {
            setState(() {
              _sex = selection.first;
              _syncAutoBmr();
            });
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          key: const Key('profile_birthday_field'),
          borderRadius: BorderRadius.circular(12),
          onTap: _pickBirthday,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: S.of(context).labelBirthday,
              helperText: age == null
                  ? S.of(context).helperBirthday
                  : S.of(context).ageFromBirthday(age),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              helperMaxLines: 2,
            ),
            child: Text(
              _birthDate == null
                  ? S.of(context).birthdayPlaceholder
                  : AppFormat.date(_birthDate!),
              key: const Key('profile_birthday_value'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('profile_height_field'),
          controller: _heightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(labelText: S.of(context).labelHeight),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('profile_weight_field'),
          controller: _weightController,
          focusNode: _weightFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: S.of(context).labelWeight,
            helperText: S.of(context).helperWeight,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('profile_bmr_field'),
          controller: _bmrController,
          // Energy is whole kcal: digits only, no decimal point.
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: S.of(context).labelBmr,
            helperText: S.of(context).helperBmr,
            helperMaxLines: 2,
          ),
        ),
        if (_bmrManual)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('profile_bmr_auto_button'),
              onPressed: _restoreAutoBmr,
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: Text(S.of(context).bmrAutoButton),
            ),
          ),
        const SizedBox(height: 24),
        // The daily energy goal: an explicit number the user picked (the goal
        // sheet only pre-computes suggestions). Needs a resolvable BMR, so it
        // appears exactly when the budget card below can appear.
        Builder(
          builder: (BuildContext context) {
            final EnergyBudget? resolved = switch (budget) {
              EnergyBudget() => budget,
              _ => null,
            };
            final UserProfile? stored = ref.watch(storedProfileProvider).value;
            if (resolved == null || stored == null) {
              return const SizedBox.shrink();
            }
            final int? goal = stored.dailyKcalGoalOverride;
            final int bmr = resolved.bmrKcal;
            final String subtitle = goal == null
                ? S.of(context).dailyGoalSubtitleNone
                : goal == bmr
                ? S.of(context).dailyGoalSubtitleMaintain
                : goal < bmr
                ? S.of(context).dailyGoalSubtitleCut(bmr - goal)
                : S.of(context).dailyGoalSubtitleGain(goal - bmr);
            return Card(
              key: const Key('profile_daily_goal'),
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(S.of(context).dailyGoalTitle),
                subtitle: Text(subtitle),
                trailing: Text(
                  goal == null
                      ? S.of(context).notSet
                      : DisplayUnits.of(context).energyText(goal),
                  key: const Key('profile_daily_goal_value'),
                ),
                onTap: () =>
                    showDailyGoalSheet(context, profile: stored, bmrKcal: bmr),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // The target is a read-only display, so it follows the 盐/钠
        // preference (5 g salt <-> 2000 mg sodium); the value is fixed and
        // still not editable.
        Builder(
          builder: (BuildContext context) {
            final DisplayUnits units = DisplayUnits.of(context);
            return Card(
              key: const Key('profile_salt_target'),
              child: ListTile(
                leading: const Icon(Icons.water_drop_outlined),
                title: Text(
                  units.showsSodium
                      ? S.of(context).sodiumTargetTitle
                      : S.of(context).saltTargetTitle,
                ),
                subtitle: Text(S.of(context).saltTargetSubtitle),
                trailing: Text(
                  units.showsSodium
                      ? S.of(context).sodiumTargetValue(units.saltTargetText)
                      : S.of(context).saltTargetValue(units.saltTargetText),
                  key: const Key('profile_salt_target_value'),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          key: const Key('profile_budget'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBudget(context, budget),
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              key: const Key('profile_validation_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          key: const Key('profile_save_button'),
          onPressed: _save,
          child: Text(S.of(context).save),
        ),
      ],
    );
  }

  /// Budget card body: spinner while loading, the "完善资料" prompt when the
  /// profile is incomplete (budget HIDDEN), or the engine's exercise-free
  /// baseline (the resolved BMR).
  Widget _buildBudget(BuildContext context, EnergyBudgetResult? budget) {
    return switch (budget) {
      null => const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ),
      ProfileIncomplete() => Text(
        S.of(context).profileBudgetIncomplete,
        key: const Key('profile_budget_incomplete'),
      ),
      EnergyBudget(:final int budgetKcal, :final int? goalKcal) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            S.of(context).profileBaseBudgetTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          // A read-only energy figure: kcal or kJ per the display preference
          // (the BMR input above stays canonical kcal).
          Text(
            DisplayUnits.of(context).energyText(budgetKcal),
            key: const Key('profile_budget_value'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          // With a goal set the exercise-free baseline IS the goal, so the
          // note says so; without one it is the BMR as before.
          Text(
            goalKcal == null
                ? S.of(context).profileBaseBudgetNote
                : S.of(context).profileBaseBudgetNoteGoal,
          ),
        ],
      ),
    };
  }

  /// Renders a number without a trailing `.0` (175.0 -> "175", 1649 ->
  /// "1649") and a fractional one capped at two decimals, via the shared
  /// [AppFormat.number]. Energy values arrive as `int` and therefore always
  /// render whole.
  static String _formatNumber(num value) => AppFormat.number(value);
}
