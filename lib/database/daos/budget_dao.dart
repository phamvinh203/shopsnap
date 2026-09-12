import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget_model.dart';
import '../../core/utils/date_helper.dart';

const _uuid = Uuid();

class BudgetDao {
  final Database db;
  BudgetDao(this.db);

  Future<String> insert(BudgetModel budget) async {
    await db.insert('budgets', budget.toMap());
    return budget.id;
  }

  Future<void> update(BudgetModel budget) async {
    await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<void> delete(String id) async {
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BudgetStatus>> getActiveBudgetsWithSpent() async {
    final now = DateTime.now();
    final isoToday = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final budgets = await db.query(
      'budgets',
      where: "is_active = 1 AND start_date <= ? AND end_date >= ?",
      whereArgs: [isoToday, isoToday],
    );

    final result = <BudgetStatus>[];
    for (final row in budgets) {
      final budget = BudgetModel.fromMap(row);
      final startMs = _isoToMs(budget.startDate);
      final endMs   = _isoToMs(budget.endDate) + 86400000;

      final spentRows = await db.rawQuery('''
        SELECT COALESCE(SUM(price), 0) AS total
        FROM items
        WHERE created_at >= ? AND created_at < ?
          AND is_deleted = 0
          ${budget.categoryId != null ? 'AND category_id = ?' : ''}
      ''', [
        startMs, endMs,
        if (budget.categoryId != null) budget.categoryId,
      ]);

      final spent = (spentRows.first['total'] as num).toInt();
      result.add(BudgetStatus(budget: budget, spent: spent));
    }
    return result;
  }

  static int _isoToMs(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
    ).millisecondsSinceEpoch;
  }

  Future<BudgetStatus?> getTodayOverallBudget() async {
    final all = await getActiveBudgetsWithSpent();
    try {
      return all.firstWhere((s) => s.budget.categoryId == null);
    } catch (_) {
      return null;
    }
  }
}
