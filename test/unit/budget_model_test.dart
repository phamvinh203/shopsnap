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

/// JSON shape backend đã verify bằng curl (GET /budgets/current).
Map<String, dynamic> apiBudgetJson({
  String status = 'active',
  String periodType = 'month',
  List<Map<String, dynamic>>? categoryBudgets,
}) => {
  'id': 'srv-b1',
  'name': 'Tháng 9',
  'period_type': periodType,
  'start_date': '2026-09-01',
  'end_date': '2026-09-30',
  'total_amount': 5000000,
  'alert_threshold': 0.8,
  'status': status,
  'is_recurring': false,
  'spent_amount': 104000,
  'remaining_amount': 4896000,
  'spent_percentage': 0.0208,
  'category_budgets': categoryBudgets ??
      [
        {
          'id': 'cb1', 'budget_id': 'srv-b1', 'category_id': 'cat_food',
          'category': {'id': 'cat_food', 'name': 'Ăn uống', 'color': '#FF6B6B', 'icon': '🍜'},
          'allocated_amount': 2000000,
          'spent_amount': 32000,
          'remaining_amount': 1968000,
          'spent_percentage': 0.016,
        }
      ],
  'created_at': '2026-09-12T20:40:06.720Z',
  'updated_at': '2026-09-12T20:40:06.720Z',
  'deleted_at': null,
};

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

  group('BudgetModel.fromApiJson (Wave 4)', () {
    test('map snake_case + computed fields, giữ nguyên toMap cho sqflite', () {
      final b = BudgetModel.fromApiJson(apiBudgetJson());

      expect(b.id, 'srv-b1');
      expect(b.name, 'Tháng 9');
      expect(b.amount, 5000000);
      expect(b.period, BudgetPeriod.month);
      expect(b.startDate, '2026-09-01'); // chuỗi YYYY-MM-DD giữ nguyên
      expect(b.endDate, '2026-09-30');
      expect(b.isActive, isTrue);
      expect(b.alertThreshold, 0.8);
      expect(b.spentAmount, 104000);
      expect(b.remainingAmount, 4896000);
      expect(b.spentPercentage, 0.0208);
      expect(b.daysRemaining, isNull); // chỉ có ở /current
      expect(b.categoryId, 'cat_food'); // đúng 1 dòng category_budgets
      expect(b.categoryBudgets.single.allocatedAmount, 2000000);
      expect(b.categoryBudgets.single.categoryName, 'Ăn uống');

      // toMap chỉ chứa 8 cột sqflite — computed fields không persist
      expect(b.toMap().keys.toSet(), {
        'id', 'amount', 'period', 'category_id',
        'start_date', 'end_date', 'is_active', 'created_at',
      });
      expect(b.toMap()['start_date'], '2026-09-01');
    });

    test('status paused / deleted → isActive=false (DAO sẽ lọc khỏi danh chạy)', () {
      expect(BudgetModel.fromApiJson(apiBudgetJson(status: 'paused')).isActive, isFalse);
      expect(
        BudgetModel.fromApiJson({
          ...apiBudgetJson(),
          'deleted_at': '2026-09-12T21:00:00.000Z',
        }).isActive,
        isFalse,
      );
    });

    test('period custom / nhiều category_budgets: custom enum + categoryId null', () {
      final custom = BudgetModel.fromApiJson(apiBudgetJson(
        periodType: 'custom',
        categoryBudgets: [],
      ));
      expect(custom.period, BudgetPeriod.custom);
      expect(custom.categoryId, isNull); // 0 dòng → ngân sách tổng

      final multi = BudgetModel.fromApiJson(apiBudgetJson(categoryBudgets: [
        {'id': 'cb1', 'budget_id': 'srv-b1', 'category_id': 'cat_food', 'allocated_amount': 100},
        {'id': 'cb2', 'budget_id': 'srv-b1', 'category_id': 'cat_tech', 'allocated_amount': 200},
      ]));
      expect(multi.categoryId, isNull); // >1 dòng → coi như ngân sách tổng
    });

    test('BudgetStatus dựng từ model server (spent = server trả về) đúng màu', () {
      final b = BudgetModel.fromApiJson(apiBudgetJson());
      // Provider construct BudgetStatus với spent = spent_amount của server
      final s = BudgetStatus(budget: b, spent: b.spentAmount ?? 0);
      expect(s.spent, 104000);
      expect(s.usageRatio, closeTo(0.0208, 0.0001));
      expect(s.isWarning, isFalse);
      expect(s.isDanger, isFalse);

      // Field server được ưu tiên: dù truyền spent khác đi, usageRatio vẫn lấy
      // spent_percentage của server (provider luôn truyền spent = spentAmount
      // nên 2 nguồn luôn khớp nhau — đây là test khoá đúng thứ tự ưu tiên).
      expect(BudgetStatus(budget: b, spent: 4200000).usageRatio, closeTo(0.0208, 0.0001));

      // Không có field server (budget local) → màu tính từ spent truyền vào
      final localLike = BudgetModel.fromApiJson({
        ...apiBudgetJson(),
        'spent_amount': null,
        'remaining_amount': null,
        'spent_percentage': null,
      });
      // Spent 84% → warning; vượt → danger
      expect(BudgetStatus(budget: localLike, spent: 4200000).isWarning, isTrue);
      expect(BudgetStatus(budget: localLike, spent: 5200000).isDanger, isTrue);
    });

    test('BudgetStatus không có field server → fallback công thức local', () {
      final s = BudgetStatus(budget: _budget(amount: 100000), spent: 40000);
      expect(s.spent, 40000);
      expect(s.remaining, 60000);
    });
  });
}
