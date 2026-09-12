import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/budget_model.dart';

BudgetModel _budget({int amount = 100000}) => BudgetModel(
  id: 'b1',
  amount: amount,
  period: BudgetPeriod.day,
  startDate: '2024-01-01',
  endDate: '2024-01-01',
  isActive: true,
  createdAt: 0,
);

void main() {
  group('BudgetStatus computed properties', () {
    test('remaining = amount - spent', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 40000);
      expect(s.remaining, 60000);
    });

    test('remaining is negative when overspent', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 120000);
      expect(s.remaining, -20000);
    });

    test('usageRatio is 0 when amount is 0', () {
      final s = BudgetStatus(budget: _budget(amount: 0), spent: 0);
      expect(s.usageRatio, 0.0);
    });

    test('isWarning true when usage 80-99%', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 85000);
      expect(s.isWarning, isTrue);
      expect(s.isDanger, isFalse);
    });

    test('isWarning false below 80%', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 50000);
      expect(s.isWarning, isFalse);
    });

    test('isDanger true at 100% usage', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 100000);
      expect(s.isDanger, isTrue);
      expect(s.isWarning, isFalse);
    });

    test('isDanger true when overspent', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 150000);
      expect(s.isDanger, isTrue);
    });
  });
}
