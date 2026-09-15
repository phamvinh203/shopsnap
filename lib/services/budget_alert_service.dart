import '../core/utils/budget_alert.dart';

typedef FiredKeysLoader = Future<Set<String>> Function();
typedef FiredKeyPersister = Future<void> Function(String key);
typedef BudgetAlertNotifier = Future<void> Function(
    BudgetAlertThreshold threshold);

/// F-#12 Budget alert LOCAL (nguồn 1) — chạy ngay tại thời điểm add/sửa item
/// (in-process, spec: không cần background service).
///
/// Flow: caller (BudgetStatusNotifier.checkAndAlert) truyền tổng chi TRƯỚC và
/// SAU khi lưu item + định danh kỳ ngân sách → [evaluateBudgetThresholdCrossings]
/// (AC 12.1/12.2) → lọc key đã alert theo [budgetAlertDedupKey] (AC 12.3: mỗi
/// ngưỡng tối đa 1 notification mỗi kỳ) → persist key RỒI notify (giữ thứ tự
/// persist-trước như PriceWatchService để không bắn kép khi notify chậm).
///
/// Toggle "Budget alerts" (AC 12.7) được kiểm tra Ở TẦNG PROVIDER trước khi
/// gọi service — service chỉ lo crossing + dedup.
///
/// Mọi phụ thuộc là callback injectable → unit test không cần plugin/prefs
/// (recorder thay notify/persist). KHÔNG bao giờ ném lỗi lên caller — alert là
/// tính năng phụ, lỗi phải không chặn flow thêm/sửa item.
class BudgetAlertService {
  final FiredKeysLoader loadFiredKeys;
  final FiredKeyPersister persistFiredKey;
  final BudgetAlertNotifier notify;

  /// AC 12.15 — các ngưỡng ĐÃ có record BE (`budget_alert`) cho cùng kỳ.
  /// Với ngưỡng nằm trong tập này, service **KHÔNG** bắn local notification
  /// (record BE là kênh hiển thị; bắn thêm sẽ double-fire cùng sự kiện), nhưng
  /// vẫn persist dedup key để không phải kiểm tra lại mỗi lần lưu item.
  final Set<BudgetAlertThreshold> serverAlertedThresholds;

  const BudgetAlertService({
    required this.loadFiredKeys,
    required this.persistFiredKey,
    required this.notify,
    this.serverAlertedThresholds = const {},
  });

  /// Trả về số alert ĐÃ bắn (0 = không ngưỡng vừa vượt / đã alert hết trong kỳ).
  ///
  /// [serverAlertedThresholds] (AC 12.15) truyền theo TỪNG lần check để caller
  /// quyết định theo kỳ ngân sách hiện tại; mặc định dùng tập trên instance.
  Future<int> checkAfterSpendChange({
    required int spentBefore,
    required int spentAfter,
    required int budgetAmount,
    required String budgetId,
    required String periodStart,
    required String periodEnd,
    Set<BudgetAlertThreshold>? serverAlertedThresholds,
  }) async {
    final skipThresholds = serverAlertedThresholds ?? this.serverAlertedThresholds;
    try {
      final crossings = evaluateBudgetThresholdCrossings(
        spentBefore: spentBefore,
        spentAfter: spentAfter,
        budget: budgetAmount,
      );
      if (crossings.isEmpty) return 0;

      final firedKeys = await loadFiredKeys();
      var fired = 0;
      for (final threshold in crossings) {
        final key = budgetAlertDedupKey(
          budgetId: budgetId,
          periodStart: periodStart,
          periodEnd: periodEnd,
          threshold: threshold,
        );
        if (firedKeys.contains(key)) continue; // AC 12.3 — dedup mỗi kỳ

        await persistFiredKey(key);
        // AC 12.15 — record BE đã có cho ngưỡng này trong kỳ: không bắn local
        // (badge/feed tính theo record server), key đã persist nên lần sau bỏ qua.
        if (skipThresholds.contains(threshold)) continue;
        try {
          await notify(threshold);
        } catch (_) {
          // Notification lỗi (plugin chưa sẵn sàng…) — key đã persist nên
          // không bắn lại trong cùng kỳ; vẫn tiếp tục ngưỡng kế tiếp.
        }
        fired++;
      }
      return fired;
    } catch (_) {
      // Lỗi đọc/ghi dedup state → bỏ qua, không làm vỡ flow thêm/sửa item.
      return 0;
    }
  }
}
