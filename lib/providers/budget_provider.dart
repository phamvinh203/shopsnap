import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget_model.dart';
import '../services/notification_service.dart';
import '../core/constants/app_constants.dart';
import 'all_budgets_provider.dart';

/// Ngân sách tổng đang chạy hôm nay (cho BudgetProgressCard ở home).
///
/// Wave 4: dẫn xuất từ [allBudgetsProvider] thay vì đọc DAO trực tiếp —
/// allBudgetsProvider đã merge server + local (server tính spent theo
/// purchase_date, kèm ngày đã căn theo kỳ) nên card hiển thị đúng giá trị
/// server khi online, tự rơi về tính toán local khi offline. Budget "tổng"
/// = budget không gắn vào 1 danh mục cụ thể (category_id null).
class BudgetStatusNotifier extends AsyncNotifier<BudgetStatus?> {
  @override
  Future<BudgetStatus?> build() async {
    final all = await ref.watch(allBudgetsProvider.future);
    for (final status in all) {
      if (status.budget.categoryId == null) return status;
    }
    return null;
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
