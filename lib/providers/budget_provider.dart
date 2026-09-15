import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/budget_alert.dart';
import '../models/budget_model.dart';
import '../services/notification_service.dart';
import 'all_budgets_provider.dart';
import 'notification_preferences_provider.dart';
import 'notification_provider.dart';

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

  /// F-#12 (AC 12.1–12.3) — budget alert LOCAL chạy ngay sau khi add/sửa item:
  /// caller (ItemsNotifier) chụp tổng chi [spentBefore] TRƯỚC khi lưu item,
  /// còn spent "sau" đọc lại từ provider (đã rebuild sau invalidate) →
  /// BudgetAlertService xác định ngưỡng VỪA vượt (80%/100%) và dedup mỗi
  /// ngưỡng tối đa 1 notification mỗi kỳ.
  ///
  /// - [spentBefore] null (không chụp được mốc) → không bắn: không xác định
  ///   được bước "vừa vượt", tránh alert sai khi app mở lại/provider rebuild.
  /// - Toggle "Budget alerts" tắt (AC 12.7) → không bắn local notification;
  ///   FEED `GET /notifications` vẫn hiện record BudgetAlert do BE enqueue.
  /// - AC 12.13: không có quyền hiển thị notification → đặt cờ cho banner
  ///   hướng dẫn trên Home thay thế, không bắn (không bao giờ crash).
  Future<void> checkAndAlert({int? spentBefore}) async {
    final status = await future;
    if (status == null) return;

    final prefs = await loadNotificationPreferences(ref);
    if (prefs?.budgetAlerts == false) return;
    if (spentBefore == null) return;

    if (!await NotificationService.canDeliver) {
      ref.read(notificationPermissionDeniedProvider.notifier).state = true;
      ref.invalidateSelf();
      return;
    }

    await ref.read(budgetAlertServiceProvider).checkAfterSpendChange(
          spentBefore: spentBefore,
          spentAfter: status.spent,
          budgetAmount: status.budget.amount,
          budgetId: status.budget.id,
          periodStart: status.budget.startDate,
          periodEnd: status.budget.endDate,
          // AC 12.15 — ngưỡng đã có record BE trong kỳ → không bắn local
          // (record BE đã là kênh hiển thị; tránh double-fire cùng sự kiện).
          serverAlertedThresholds: _serverAlertedForCurrentPeriod(ref, status.budget),
        );
    ref.invalidateSelf();
  }
}

/// AC 12.15 — suy ra ngưỡng đã có record `budget_alert` từ cache feed
/// (`GET /notifications`, đã poll khi app vào foreground) cho CÙNG budget và
/// CÙNG kỳ ngân sách hiện tại. Không có cache / ngày kỳ không parse được →
/// tập rỗng (giữ hành vi cũ: bắn local bình thường, an toàn hơn là im lặng).
Set<BudgetAlertThreshold> _serverAlertedForCurrentPeriod(
  Ref ref,
  BudgetModel budget,
) {
  final start = DateTime.tryParse(budget.startDate);
  final end = DateTime.tryParse(budget.endDate);
  if (start == null || end == null) return const {};

  final items = ref.read(notificationFeedProvider).valueOrNull?.items;
  if (items == null || items.isEmpty) return const {};

  return serverAlertedThresholds(
    records: [
      for (final n in items)
        (type: n.type, payload: n.payload, createdAt: n.createdAt),
    ],
    budgetId: budget.id,
    periodStart: start,
    periodEnd: end,
  );
}

final budgetStatusProvider = AsyncNotifierProvider<BudgetStatusNotifier, BudgetStatus?>(BudgetStatusNotifier.new);
