import 'package:sqflite/sqflite.dart';
import '../../models/budget_model.dart';

class BudgetDao {
  final Database db;
  BudgetDao(this.db);

  Future<String> insert(BudgetModel budget) async {
    await db.insert('budgets', budget.toMap());
    return budget.id;
  }

  /// Upsert budget nhận về từ server (Wave 4 — sync một chiều server → local).
  ///
  /// - `ConflictAlgorithm.replace`: id trùng → đè bằng bản mới nhất của server
  ///   (kèm ngày đã căn lại theo kỳ — week T2–CN, month đầu–cuối tháng).
  /// - computed fields (spent/percentage...) không có cột tương ứng → chỉ giữ
  ///   in-memory trên model, offline vẫn tính lại từ items.
  /// - Budget `custom` không lưu được (CHECK period IN day/week/month) → bỏ qua
  ///   persist, budget này chỉ hiển thị trong phiên nhờ provider merge server.
  /// - FK(category_id → categories): category chỉ tồn tại trên server → tạo row
  ///   category tối thiểu từ category nhúng trong response (cách ItemDao làm).
  Future<void> upsertSynced(BudgetModel budget) async {
    if (budget.period == BudgetPeriod.custom) return;
    await db.transaction((txn) async {
      if (budget.categoryId != null) {
        final catExists = await txn.query('categories',
            where: 'id = ?', whereArgs: [budget.categoryId], limit: 1);
        if (catExists.isEmpty) {
          final line = budget.categoryBudgets.isNotEmpty ? budget.categoryBudgets.first : null;
          await txn.insert('categories', {
            'id':         budget.categoryId,
            'name':       (line?.categoryName?.isNotEmpty ?? false) ? line!.categoryName! : 'Danh mục',
            'icon':       line?.categoryIcon ?? '🛍️',
            'color':      line?.categoryColor ?? '#6C63FF',
            'is_default': 0,
            'sort_order': 10000, // xếp cuối danh sách, dưới seed + custom
            'created_at': budget.createdAt,
          });
        }
      }
      await txn.insert('budgets', budget.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
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
