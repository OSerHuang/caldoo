import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/domain/models/user_profile.dart';

/// Reference "today" for every calculation below.
final DateTime _today = DateTime(2026, 10, 22);

/// Anthropometric fixture: male, born 1996-10-22 (30 years old on [_today]),
/// 175cm, 70kg. Mifflin-St Jeor gives `10*70 + 6.25*175 - 5*30 + 5 == 1648.75`,
/// rounded once to the integer 1649 kcal.
final UserProfile _male30 = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1996, 10, 22),
  heightCm: 175,
  weightKg: 70,
);

/// The same person with a user-pinned BMR override.
final UserProfile _male30Manual = _male30.copyWith(bmrKcalOverride: 1800);

/// Unwraps the sealed result, failing with a clear message when the engine
/// refused the profile. Uses an exhaustive switch: if the result type were not
/// sealed this would not compile.
EnergyBudget _budgetOf(EnergyBudgetResult result) => switch (result) {
  final EnergyBudget budget => budget,
  ProfileIncomplete() => fail(
    'expected a complete profile, got ProfileIncomplete',
  ),
};

void main() {
  group('worked vector — male 30y 175cm 70kg, derived BMR (1649), exercise '
      '257, intake 1936', () {
    const exerciseKcal = 257;
    final budget = _budgetOf(
      computeEnergyBudget(
        profile: _male30,
        intakeKcal: 1936,
        exerciseKcal: exerciseKcal,
        today: _today,
      ),
    );

    test('BMR = 1649 (Mifflin-St Jeor 1648.75 rounded to whole kcal)', () {
      expect(budget.bmrKcal, 1649);
    });

    test('baseBudget == BMR exactly (there is no activity multiplier)', () {
      expect(budget.baseBudgetKcal, 1649);
      expect(budget.baseBudgetKcal, budget.bmrKcal);
    });

    test('exerciseKcal = 257 exactly (input passed through verbatim)', () {
      expect(budget.exerciseKcal, 257);
    });

    test('budget = 1906 exactly (BMR + exerciseKcal add-back)', () {
      expect(budget.budgetKcal, 1906);
    });

    test('energyBalance = +30 exactly (intake - budget; surplus)', () {
      expect(budget.energyBalanceKcal, 30);
      expect(budget.isSurplus, isTrue);
    });

    test('deficit = -30 exactly (budget - intake; negative = surplus)', () {
      expect(budget.deficitKcal, -30);
      expect(budget.isDeficit, isFalse);
    });
  });

  group('age is derived from the birthday on `today` (never stored)', () {
    test(
      'birthday today -> age 30 (1649); the day before -> age 29 (1654)',
      () {
        expect(resolveBmrKcal(_male30, today: DateTime(2026, 10, 22)), 1649);
        expect(resolveBmrKcal(_male30, today: DateTime(2026, 10, 21)), 1654);
      },
    );

    test(
      'a profile needs no edit across a birthday: the BMR updates itself',
      () {
        final int bmrBefore = resolveBmrKcal(
          _male30,
          today: DateTime(2026, 10, 21),
        );
        final int bmrAfter = resolveBmrKcal(
          _male30,
          today: DateTime(2027, 10, 22),
        );
        // Two years of age at -5 kcal/year: the estimate follows the birthday.
        expect(bmrBefore - bmrAfter, 10);
      },
    );
  });

  group('sign convention cannot be confused', () {
    test('energyBalance == -deficit and they sum to zero, always', () {
      for (final intake in <int>[0, 500, 1649, 1906, 3000]) {
        final budget = _budgetOf(
          computeEnergyBudget(
            profile: _male30,
            intakeKcal: intake,
            today: _today,
          ),
        );
        expect(
          budget.energyBalanceKcal,
          -budget.deficitKcal,
          reason: 'intake=$intake',
        );
        expect(
          budget.energyBalanceKcal + budget.deficitKcal,
          0,
          reason: 'intake=$intake',
        );
      }
    });

    test('deficit case: intake 1500 -> energyBalance -149 (缺口)', () {
      final budget = _budgetOf(
        computeEnergyBudget(profile: _male30, intakeKcal: 1500, today: _today),
      );
      expect(budget.budgetKcal, 1649);
      expect(budget.energyBalanceKcal, -149);
      expect(budget.deficitKcal, 149);
      expect(budget.isSurplus, isFalse);
      expect(budget.isDeficit, isTrue);
    });

    test('exactly at budget: zero balance, neither surplus nor deficit', () {
      final budget = _budgetOf(
        computeEnergyBudget(profile: _male30, intakeKcal: 1649, today: _today),
      );
      expect(budget.energyBalanceKcal, 0);
      expect(budget.deficitKcal, 0);
      expect(budget.isSurplus, isFalse);
      expect(budget.isDeficit, isFalse);
    });
  });

  group('BMR baseline + exercise add-back', () {
    test(
      'baseBudget is the resolved BMR, never the exercise-inclusive total',
      () {
        final budget = _budgetOf(
          computeEnergyBudget(
            profile: _male30,
            intakeKcal: 0,
            exerciseKcal: 257,
            today: _today,
          ),
        );
        expect(budget.baseBudgetKcal, 1649);
        expect(budget.baseBudgetKcal, isNot(budget.budgetKcal));
      },
    );

    test('exercise raises budget by exactly the logged kcal (add-back)', () {
      for (final exercise in <int>[0, 1, 257, 500]) {
        final withExercise = _budgetOf(
          computeEnergyBudget(
            profile: _male30,
            intakeKcal: 1936,
            exerciseKcal: exercise,
            today: _today,
          ),
        );
        expect(
          withExercise.budgetKcal - withExercise.baseBudgetKcal,
          exercise,
          reason: 'exercise=$exercise',
        );
        expect(withExercise.budgetKcal, 1649 + exercise);
      }
    });

    test('exerciseKcal defaults to zero', () {
      final budget = _budgetOf(
        computeEnergyBudget(profile: _male30, intakeKcal: 1649, today: _today),
      );
      expect(budget.exerciseKcal, 0);
      expect(budget.budgetKcal, budget.baseBudgetKcal);
    });
  });

  group('user-set BMR override wins over the Mifflin-St Jeor estimate', () {
    test('resolveBmrKcal: override when set, estimate when null', () {
      expect(resolveBmrKcal(_male30, today: _today), 1649);
      expect(resolveBmrKcal(_male30Manual, today: _today), 1800);
    });

    test(
      'an override replaces BMR and the baseline, exercise still adds back',
      () {
        final budget = _budgetOf(
          computeEnergyBudget(
            profile: _male30Manual,
            intakeKcal: 1936,
            exerciseKcal: 257,
            today: _today,
          ),
        );
        expect(budget.bmrKcal, 1800);
        expect(budget.baseBudgetKcal, 1800);
        expect(budget.budgetKcal, 2057);
        expect(budget.energyBalanceKcal, -121);
        expect(budget.deficitKcal, 121);
      },
    );

    test('copyWith can set and clear the override', () {
      final manual = _male30.copyWith(bmrKcalOverride: 2000);
      expect(manual.bmrKcalOverride, 2000);
      expect(
        manual.copyWith(clearBmrKcalOverride: true).bmrKcalOverride,
        isNull,
      );
      expect(manual.copyWith(bmrKcalOverride: 2100).bmrKcalOverride, 2100);
    });
  });

  group('Mifflin-St Jeor BMR is a whole-kcal estimate', () {
    test('men: 1648.75 rounds to 1649', () {
      expect(
        mifflinStJeorBmr(sex: Sex.male, age: 30, heightCm: 175, weightKg: 70),
        1649,
      );
    });

    test('women: 1482.75 rounds to 1483', () {
      expect(
        mifflinStJeorBmr(sex: Sex.female, age: 30, heightCm: 175, weightKg: 70),
        1483,
      );
    });

    test('the male/female gap is exactly 166 kcal (+5 vs -161)', () {
      final male = mifflinStJeorBmr(
        sex: Sex.male,
        age: 30,
        heightCm: 175,
        weightKg: 70,
      );
      final female = mifflinStJeorBmr(
        sex: Sex.female,
        age: 30,
        heightCm: 175,
        weightKg: 70,
      );
      expect(male - female, 166);
    });

    test('a fractional formula result rounds half away from zero once', () {
      // 10*70 + 6.25*175 - 5*30 + 5 = 1648.75 -> 1649 (not 1648/1648.75).
      expect(
        mifflinStJeorBmr(sex: Sex.male, age: 30, heightCm: 175, weightKg: 70),
        isNot(closeTo(1648.75, 1e-9)),
      );
      // A .5 result rounds up: 10*70 + 6.25*174 - 5*30 + 5 = 1642.5 -> 1643.
      expect(
        mifflinStJeorBmr(sex: Sex.male, age: 30, heightCm: 174, weightKg: 70),
        1643,
      );
    });
  });

  group(
    'incomplete profile -> typed ProfileIncomplete, never a wrong number',
    () {
      test('null profile returns ProfileIncomplete (not an EnergyBudget)', () {
        final result = computeEnergyBudget(
          profile: null,
          intakeKcal: 1936,
          today: _today,
        );
        expect(result, isA<ProfileIncomplete>());
        expect(result, isNot(isA<EnergyBudget>()));
      });

      test('ProfileIncomplete is a const value of the sealed result type', () {
        expect(const ProfileIncomplete(), isA<EnergyBudgetResult>());
      });

      test('a null profile never yields numbers even with exercise logged', () {
        final result = computeEnergyBudget(
          profile: null,
          intakeKcal: 1936,
          exerciseKcal: 257,
          today: _today,
        );
        switch (result) {
          case ProfileIncomplete():
            break; // the only acceptable outcome
          case EnergyBudget():
            fail('engine produced a budget from a missing profile');
        }
      });
    },
  );

  group('guards: malformed numbers throw ArgumentError', () {
    test('negative intake', () {
      expect(
        () => computeEnergyBudget(
          profile: _male30,
          intakeKcal: -1,
          today: _today,
        ),
        throwsArgumentError,
      );
    });

    test('negative exercise', () {
      expect(
        () => computeEnergyBudget(
          profile: _male30,
          intakeKcal: 1936,
          exerciseKcal: -1,
          today: _today,
        ),
        throwsArgumentError,
      );
    });

    test('non-positive BMR override', () {
      for (final override in <int>[0, -1]) {
        expect(
          () => resolveBmrKcal(
            _male30.copyWith(bmrKcalOverride: override),
            today: _today,
          ),
          throwsArgumentError,
          reason: 'override=$override',
        );
      }
    });

    test('non-positive or non-finite age / height / weight', () {
      expect(
        () => mifflinStJeorBmr(
          sex: Sex.male,
          age: 0,
          heightCm: 175,
          weightKg: 70,
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            mifflinStJeorBmr(sex: Sex.male, age: 30, heightCm: 0, weightKg: 70),
        throwsArgumentError,
      );
      expect(
        () => mifflinStJeorBmr(
          sex: Sex.male,
          age: 30,
          heightCm: 175,
          weightKg: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => mifflinStJeorBmr(
          sex: Sex.male,
          age: 30,
          heightCm: double.nan,
          weightKg: 70,
        ),
        throwsArgumentError,
      );
      expect(
        () => mifflinStJeorBmr(
          sex: Sex.male,
          age: 30,
          heightCm: 175,
          weightKg: double.infinity,
        ),
        throwsArgumentError,
      );
    });
  });

  group('daily goal: the baseline is the goal when one is set', () {
    final goalProfile = _male30.copyWith(dailyKcalGoalOverride: 1250);

    test('baseBudget == goal, NOT the BMR', () {
      final budget = _budgetOf(
        computeEnergyBudget(
          profile: goalProfile,
          intakeKcal: 1000,
          today: _today,
        ),
      );
      expect(budget.goalKcal, 1250);
      expect(budget.baseBudgetKcal, 1250);
      expect(
        budget.budgetKcal,
        1250,
        reason: 'no exercise: budget is the goal',
      );
      // The BMR stays resolved and untouched for display elsewhere.
      expect(budget.bmrKcal, 1649);
    });

    test('exercise is added on top of the goal', () {
      final budget = _budgetOf(
        computeEnergyBudget(
          profile: goalProfile,
          intakeKcal: 1400,
          exerciseKcal: 220,
          today: _today,
        ),
      );
      expect(budget.budgetKcal, 1470);
      expect(budget.deficitKcal, 70);
    });

    test(
      'no goal: behaviour is exactly the maintain budget (null goalKcal)',
      () {
        final budget = _budgetOf(
          computeEnergyBudget(
            profile: _male30,
            intakeKcal: 1000,
            exerciseKcal: 100,
            today: _today,
          ),
        );
        expect(budget.goalKcal, isNull);
        expect(budget.baseBudgetKcal, budget.bmrKcal);
        expect(budget.budgetKcal, 1749);
      },
    );

    test('resolveDailyGoalKcal: null passes through, non-positive throws', () {
      expect(resolveDailyGoalKcal(_male30, bmrKcal: 1649), isNull);
      expect(resolveDailyGoalKcal(goalProfile, bmrKcal: 1649), 1250);
      for (final goal in <int>[0, -1]) {
        expect(
          () => resolveDailyGoalKcal(
            _male30.copyWith(dailyKcalGoalOverride: goal),
            bmrKcal: 1649,
          ),
          throwsArgumentError,
          reason: 'goal=$goal',
        );
      }
    });
  });

  group('BMR-relative presets: the goal follows the body weight', () {
    // The same person at 70kg (BMR 1649): the preset picks a delta from the
    // BMR at read time, so a later weight change moves the goal with it.
    test('slowCut = BMR - 250 (70kg -> 1399)', () {
      final UserProfile profile = _male30.copyWith(
        dailyGoalPreset: DailyGoalPreset.slowCut,
      );
      final budget = _budgetOf(
        computeEnergyBudget(profile: profile, intakeKcal: 0, today: _today),
      );
      expect(budget.bmrKcal, 1649);
      expect(budget.goalKcal, 1399);
      expect(budget.baseBudgetKcal, 1399);
      expect(budget.budgetKcal, 1399);
    });

    test('fastCut and gain use their own deltas', () {
      for (final (DailyGoalPreset preset, int expectedGoal)
          in <(DailyGoalPreset, int)>[
            (DailyGoalPreset.fastCut, 1149),
            (DailyGoalPreset.gain, 1899),
          ]) {
        final budget = _budgetOf(
          computeEnergyBudget(
            profile: _male30.copyWith(dailyGoalPreset: preset),
            intakeKcal: 0,
            today: _today,
          ),
        );
        expect(budget.goalKcal, expectedGoal, reason: '$preset');
      }
    });

    test('a lighter weight lowers the BMR and the preset goal with it', () {
      final UserProfile lighter = _male30.copyWith(weightKg: 65);
      // 10*65 + 6.25*175 - 5*30 + 5 == 1598.75 -> 1599.
      final budget = _budgetOf(
        computeEnergyBudget(
          profile: lighter.copyWith(dailyGoalPreset: DailyGoalPreset.slowCut),
          intakeKcal: 0,
          today: _today,
        ),
      );
      expect(budget.bmrKcal, 1599);
      expect(
        budget.goalKcal,
        1349,
        reason: 'the preset follows the weight: 1599 - 250',
      );
      expect(
        budget.goalKcal,
        1399 - 50,
        reason: '5 kg * 10 kcal/kg lowers the goal by exactly 50 kcal',
      );
    });

    test('the preset is relative to a pinned BMR override too', () {
      final budget = _budgetOf(
        computeEnergyBudget(
          profile: _male30Manual.copyWith(
            dailyGoalPreset: DailyGoalPreset.slowCut,
          ),
          intakeKcal: 0,
          today: _today,
        ),
      );
      expect(budget.bmrKcal, 1800);
      expect(budget.goalKcal, 1550);
    });

    test('exercise still adds on top of a preset goal', () {
      final budget = _budgetOf(
        computeEnergyBudget(
          profile: _male30.copyWith(dailyGoalPreset: DailyGoalPreset.fastCut),
          intakeKcal: 1400,
          exerciseKcal: 220,
          today: _today,
        ),
      );
      expect(budget.budgetKcal, 1369);
      expect(budget.deficitKcal, -31);
    });

    test('a preset and a fixed override are mutually exclusive', () {
      final UserProfile malformed = _male30.copyWith(
        dailyGoalPreset: DailyGoalPreset.slowCut,
        dailyKcalGoalOverride: 1250,
      );
      expect(
        () => resolveDailyGoalKcal(malformed, bmrKcal: 1649),
        throwsArgumentError,
      );
      expect(
        () => computeEnergyBudget(
          profile: malformed,
          intakeKcal: 0,
          today: _today,
        ),
        throwsArgumentError,
        reason: 'the engine refuses to guess which goal wins',
      );
    });

    test('a preset that resolves to a non-positive goal throws', () {
      final UserProfile profile = _male30.copyWith(
        dailyGoalPreset: DailyGoalPreset.fastCut,
      );
      for (final int bmr in <int>[500, 400]) {
        expect(
          () => resolveDailyGoalKcal(profile, bmrKcal: bmr),
          throwsArgumentError,
          reason: 'bmr=$bmr',
        );
      }
    });
  });
}
