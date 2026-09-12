import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/daos/budget_dao.dart';
import '../models/budget_model.dart';
import '../services/notification_service.dart';
import '../core/constants/app_constants.dart';
import 'database_provider.dart';

class BudgetStatusNotifier extends AsyncNotifier<BudgetStatus?> {
  @override
  Future<BudgetStatus?> build() async {
    final db = await ref.watch(databaseProvider.future);
    return BudgetDao(db).getTodayOverallBudget();
  }

  Future<void> checkAndAlert() async {
    final status = await future;
    if (status == null) return;

    if (status.usageRatio >= AppConstants.budgetDangerRatio) {
      await NotificationService.showBudgetExceeded(
        spent: status.spent, total: status.budget.amount,
      );
    } else if (status.usageRatio >= AppConstants.budgetWarnRatio) {
      await NotificationService.showBudgetWarning(
        spent: status.spent, total: status.budget.amount,
      );
    }
    ref.invalidateSelf();
  }
}

final budgetStatusProvider = AsyncNotifierProvider<BudgetStatusNotifier, BudgetStatus?>(BudgetStatusNotifier.new);
