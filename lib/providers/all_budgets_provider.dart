import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/daos/budget_dao.dart';
import '../models/budget_model.dart';
import 'database_provider.dart';

const _uuid = Uuid();

class AllBudgetsNotifier extends AsyncNotifier<List<BudgetStatus>> {
  @override
  Future<List<BudgetStatus>> build() async {
    final db = await ref.watch(databaseProvider.future);
    return BudgetDao(db).getActiveBudgetsWithSpent();
  }

  Future<void> addBudget({
    required int          amount,
    required BudgetPeriod period,
    String?               categoryId,
  }) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = BudgetDao(db);

    final now   = DateTime.now();
    final dates = _periodDates(period, now);

    await dao.insert(BudgetModel(
      id:         _uuid.v4(),
      amount:     amount,
      period:     period,
      categoryId: categoryId,
      startDate:  dates.$1,
      endDate:    dates.$2,
      isActive:   true,
      createdAt:  now.millisecondsSinceEpoch,
    ));
    ref.invalidateSelf();
  }

  Future<void> updateAmount(String id, int newAmount) async {
    final db      = await ref.read(databaseProvider.future);
    final current = state.valueOrNull?.firstWhere((s) => s.budget.id == id);
    if (current == null) return;

    final updated = BudgetModel(
      id:         current.budget.id,
      amount:     newAmount,
      period:     current.budget.period,
      categoryId: current.budget.categoryId,
      startDate:  current.budget.startDate,
      endDate:    current.budget.endDate,
      isActive:   current.budget.isActive,
      createdAt:  current.budget.createdAt,
    );
    await BudgetDao(db).update(updated);
    ref.invalidateSelf();
  }

  Future<void> deleteBudget(String id) async {
    final db = await ref.read(databaseProvider.future);
    await BudgetDao(db).delete(id);
    ref.invalidateSelf();
  }

  static (String, String) _periodDates(BudgetPeriod period, DateTime now) {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (period) {
      case BudgetPeriod.day:
        return (fmt(now), fmt(now));
      case BudgetPeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return (fmt(monday), fmt(sunday));
      case BudgetPeriod.month:
        final start = DateTime(now.year, now.month, 1);
        final end   = DateTime(now.year, now.month + 1, 0);
        return (fmt(start), fmt(end));
    }
  }
}

final allBudgetsProvider =
    AsyncNotifierProvider<AllBudgetsNotifier, List<BudgetStatus>>(
  AllBudgetsNotifier.new,
);
