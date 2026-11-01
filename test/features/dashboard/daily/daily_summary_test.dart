/// Task 24: pure tests for the dashboard's value layer.
///
/// Locks the task-7 sign convention at the projection boundary: 缺口 always
/// carries `deficitKcal` (`budget - intake`, positive) and 盈余 always carries
/// `energyBalanceKcal` (`intake - budget`, positive). A swap of the two engine
/// fields would fail here directly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary.dart';

/// The task-7 profile: male 175cm 70kg, born 1995-10-22 (age 30 on
/// [_today]), with a pinned BMR of 1979 kcal (1978.5 rounded; the base budget
/// is the BMR, exercise is added on top).
final UserProfile _profile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 10, 22),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

/// The day the profile's age is derived on (pinned so the tests never age).
final DateTime _today = DateTime.utc(2026, 1, 5);

/// Unwraps the sealed engine result, failing loudly on a missing profile.
EnergyBudget _budget({required int intake, int exercise = 0}) {
  final EnergyBudgetResult result = computeEnergyBudget(
    profile: _profile,
    intakeKcal: intake,
    exerciseKcal: exercise,
    today: _today,
  );
  return switch (result) {
    final EnergyBudget budget => budget,
    ProfileIncomplete() => fail('expected a complete profile'),
  };
}

void main() {
  group('SignedBalance sign convention (surplus vs deficit not swapped)', () {
    test('deficit fixture: budget 2236 - intake 1936 -> 缺口 +300', () {
      final SignedBalance balance = SignedBalance.fromBudget(
        _budget(intake: 1936, exercise: 257),
      );
      expect(balance.kind, BalanceKind.deficit);
      expect(balance.label, '缺口(相对额度)');
      expect(balance.valueKcal, 300);
    });

    test('surplus fixture: intake 2536 - budget 2236 -> 盈余 +300', () {
      final SignedBalance balance = SignedBalance.fromBudget(
        _budget(intake: 2536, exercise: 257),
      );
      expect(balance.kind, BalanceKind.surplus);
      expect(balance.label, '盈余(相对额度)');
      expect(balance.valueKcal, 300);
    });

    test('exactly on budget -> 平衡 0 (neither 缺口 nor 盈余)', () {
      final SignedBalance balance = SignedBalance.fromBudget(
        _budget(intake: 2236, exercise: 257),
      );
      expect(balance.kind, BalanceKind.balanced);
      expect(balance.label, '平衡');
      expect(balance.valueKcal, 0);
    });

    test('缺口 value is budget - intake, shown POSITIVE (never negated)', () {
      final EnergyBudget budget = _budget(intake: 1500);
      expect(budget.deficitKcal, 479); // 1979 - 1500
      final SignedBalance balance = SignedBalance.fromBudget(budget);
      expect(balance.label, '缺口(相对额度)');
      expect(balance.valueKcal, 479);
      expect(balance.valueKcal, isNot(-479));
    });

    test('盈余 value is intake - budget, shown POSITIVE', () {
      final EnergyBudget budget = _budget(intake: 2500);
      expect(budget.energyBalanceKcal, 521); // 2500 - 1979
      final SignedBalance balance = SignedBalance.fromBudget(budget);
      expect(balance.label, '盈余(相对额度)');
      expect(balance.valueKcal, 521);
      expect(balance.valueKcal, isNot(-521));
    });
  });

  group('formatDailyNumber (macros; energy uses AppFormat.integer)', () {
    test('drops a trailing .0 for whole numbers', () {
      expect(formatDailyNumber(300), '300');
      expect(formatDailyNumber(0), '0');
      expect(formatDailyNumber(5), '5');
    });

    test('keeps the exact fractional macro value otherwise', () {
      expect(formatDailyNumber(193.75), '193.75');
      expect(formatDailyNumber(74.25), '74.25');
      expect(formatDailyNumber(3.5), '3.5');
    });
  });
}
