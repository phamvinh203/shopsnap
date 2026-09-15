/// F-#12 Smart Notification — logic thuần KHÔNG phụ thuộc Flutter/Riverpod/DB
/// (unit test độc lập, cùng phong cách `price_watch.dart` / `budget_insights.dart`).
///
/// Phủ các AC:
/// - Xác định ngưỡng budget VỪA bị vượt khi tổng chi thay đổi vì thêm/sửa item
///   (AC 12.1 ngưỡng 80%, AC 12.2 ngưỡng 100% — giữ 2 ngưỡng theo hành vi BE,
///   hằng số dùng chung `AppConstants.budgetWarnRatio`/`budgetDangerRatio`).
/// - Dedup theo KỲ NGÂN SÁCH (AC 12.3): mỗi ngưỡng tối đa 1 notification mỗi
///   kỳ — key gắn budget + start/end kỳ + ngưỡng, lưu state bên ngoài (prefs).
/// - Nội dung notification GENERIC (AC 12.4 — yêu cầu CỨNG): title/body định
///   nghĩa MỘT NƠI DUY NHẤT ở đây, không bao giờ chứa số tiền / % / tên món.
///   `NotificationService` chỉ render các chuỗi này — không thể lộ dữ liệu.
library;

import '../constants/app_constants.dart';

/// Ngưỡng budget alert (F-#12 AC 12.1/12.2).
enum BudgetAlertThreshold {
  /// 80% budget — "cần chú ý".
  warning(AppConstants.budgetWarnRatio),

  /// 100% budget — "vượt ngân sách".
  exceeded(AppConstants.budgetDangerRatio);

  /// Tỉ lệ ngưỡng (0.80 / 1.00) — nguồn truth từ AppConstants (cùng số BE).
  final double ratio;

  const BudgetAlertThreshold(this.ratio);
}

/// Ngưỡng CAO NHẤT vừa bị vượt bởi một lần thay đổi tổng chi
/// ([spentBefore] → [spentAfter]); rỗng = không ngưỡng nào vừa vượt.
///
/// **AC 12.14:** vượt THẲNG từ dưới 80% lên ≥ 100% chỉ bắn DUY NHẤT ngưỡng
/// 100% — KHÔNG bắn thêm ngưỡng 80% "trễ". Lý do: 1 lần lưu item = 1 sự kiện
/// = 1 notification, tránh 2 thông báo dồn dập cho cùng một hành động (ngưỡng
/// 80% khi đó đã là thông tin cũ, người dùng đã vượt qua nó).
///
/// Ranh giới (khớp hành vi `BudgetStatus.usageRatio >= ratio`):
/// - "Chạm ngưỡng" là `spent >= ratio × budget` (đúng 80% được tính).
/// - Chỉ tính BƯỚC VƯỢT MỚI: `spentBefore < ngưỡng <= spentAfter`. Trước đó
///   đã ở trên ngưỡng (sửa item không đổi tổng qua ngưỡng) → không tính.
/// - Giảm chi (delete/giảm giá) hoặc không đổi → không bao giờ có ngưỡng.
/// - `budget <= 0` → rỗng (không xác định được tỉ lệ, không crash/chia 0).
List<BudgetAlertThreshold> evaluateBudgetThresholdCrossings({
  required int spentBefore,
  required int spentAfter,
  required int budget,
}) {
  if (budget <= 0) return const [];
  if (spentAfter <= spentBefore) return const [];

  BudgetAlertThreshold? highest;
  for (final threshold in BudgetAlertThreshold.values) {
    final mark = threshold.ratio * budget;
    if (spentBefore < mark && spentAfter >= mark) {
      // `values` xếp TĂNG DẦN (warning 80% → exceeded 100%) → ngưỡng vượt
      // CUỐI CÙNG trong vòng lặp chính là ngưỡng cao nhất (AC 12.14).
      highest = threshold;
    }
  }
  return highest == null ? const [] : [highest];
}

/// Key dedup cho MỘT ngưỡng TRONG MỘT kỳ ngân sách (AC 12.3): budget + khoảng
/// kỳ + ngưỡng. Kỳ mới (start/end đổi) → key mới → được alert lại đúng 1 lần.
String budgetAlertDedupKey({
  required String budgetId,
  required String periodStart,
  required String periodEnd,
  required BudgetAlertThreshold threshold,
}) =>
    'budget_alert|$budgetId|$periodStart..$periodEnd|${threshold.name}';

// ── Nội dung notification GENERIC (AC 12.4 — CỨNG) ──────────────────────────
//
// Quy ước an toàn: KHÔNG số (kể cả %), KHÔNG đơn vị tiền, KHÔNG tên món.
// Đây là chuỗi duy nhất được đưa vào payload local notification của cả 2 loại
// alert; chi tiết số tiền/tên món chỉ hiển thị trong app sau khi user mở
// (AC 12.5 — deep-link tới đúng ngữ cảnh).

/// Title budget alert — cố định theo AC 12.1.
const String budgetAlertTitle = 'Ngân sách cần chú ý';

/// Body ngưỡng 80% — generic, không số tiền / không % (AC 12.1 + 12.4).
const String budgetWarningBody =
    'Chi tiêu sắp chạm mức bạn đặt ra cho kỳ này. Mở ứng dụng để xem chi tiết.';

/// Body ngưỡng 100% — generic, không số tiền / không % (AC 12.2 + 12.4).
const String budgetExceededBody =
    'Bạn đã vượt mức chi tiêu đã đặt ra. Mở ứng dụng để xem chi tiết.';

/// Title price alert — cố định theo AC 12.6.
const String priceAlertTitle = 'Cập nhật giá đáng chú ý';

/// Body price alert — generic, KHÔNG tên món / không giá (AC 12.4 + 12.6).
const String priceAlertBody =
    'Một món bạn đang theo dõi vừa có mức giá tốt. Mở ứng dụng để xem chi tiết.';

/// Deep-link đích khi user bấm notification (AC 12.5): budget → màn ngân sách
/// (nơi có chi tiết budget), price → Shopping List (nơi có price intel).
const String budgetAlertRoute = '/budget';
const String priceAlertRoute = '/shopping-list';

/// M-2 (AC 4.13): recurring reminder bấm vào → mở màn quản lý khoản định kỳ
/// (nơi có chi tiết tên/số tiền/ngày hạn — notification chỉ là generic).
const String recurringAlertRoute = '/recurring';

/// Các route được phép deep-link từ notification tap — whitelist để payload
/// lạ (hoặc BE gửi tùy tiện) không điều hướng tới route không tồn tại.
const Set<String> notificationTapRoutes = {
  budgetAlertRoute,
  priceAlertRoute,
  recurringAlertRoute,
};

/// Payload gắn vào local notification budget alert.
const String budgetAlertPayload = '{"route":"$budgetAlertRoute"}';

/// Payload gắn vào local notification price alert — không có món cụ thể.
const String priceAlertPayload = '{"route":"$priceAlertRoute"}';

/// Payload price alert CÓ món cụ thể (AC 12.5 — deep-link mở Shopping List
/// đúng món để scroll-to + highlight). `itemId` là ID kỹ thuật (uuid), KHÔNG
/// phải dữ liệu nhạy cảm và không bao giờ được hiển thị trên lockscreen
/// (title/body vẫn là hằng generic — AC 12.4).
String priceAlertPayloadFor(String? itemId) {
  final id = itemId?.trim();
  if (id == null || id.isEmpty) return priceAlertPayload;
  return '{"route":"$priceAlertRoute","item":"$id"}';
}

/// Đọc item id từ payload notification (AC 12.5). `null` khi payload không có
/// item / rỗng / hỏng → màn đích mở bình thường, không scroll-to.
String? parseNotificationItemId(String? payload) {
  if (payload == null || payload.trim().isEmpty) return null;
  final match = RegExp(r'"item"\s*:\s*"([^"]+)"').firstMatch(payload);
  final id = match?.group(1)?.trim();
  return (id == null || id.isEmpty) ? null : id;
}

/// AC 12.8 — nhãn badge bell trên Home: đếm số notification chưa đọc; quá 99
/// hiển thị "99+" (badge không phình theo số thật). Badge ẩn khi count = 0 là
/// việc của UI (`isLabelVisible`), hàm này chỉ lo phần chữ.
String notificationBadgeLabel(int unreadCount) =>
    unreadCount > 99 ? '99+' : '$unreadCount';

// ── AC 12.15 — reconcile 2 nguồn notification ───────────────────────────────

/// Một record notification BE đã cache ở client (`GET /notifications`) — chỉ
/// giữ phần cần cho việc reconcile.
typedef ServerBudgetAlertRecord = ({
  String type,
  Map<String, dynamic> payload,
  DateTime createdAt,
});

/// AC 12.15 — tập ngưỡng ĐÃ CÓ record BE (`type = budget_alert`) cho CÙNG
/// budget trong CÙNG kỳ ngân sách. Với các ngưỡng này mobile **SKIP** local
/// notification: record BE đã là kênh hiển thị của sự kiện đó (badge + feed
/// tính theo record server), bắn thêm local sẽ double-fire cùng một sự kiện.
///
/// Khớp theo payload thật của BE (`budget-alert-checker.service.ts:230-237`):
/// `budget_id` + `threshold_percentage` + `type`, cộng điều kiện thời gian
/// `createdAt` nằm trong kỳ [periodStart, periodEnd] (payload BE không chứa
/// kỳ nên dùng mốc thời gian của record).
Set<BudgetAlertThreshold> serverAlertedThresholds({
  required Iterable<ServerBudgetAlertRecord> records,
  required String budgetId,
  required DateTime periodStart,
  required DateTime periodEnd,
}) {
  // Hết ngày cuối kỳ: record trong ngày periodEnd vẫn phải tính (periodEnd
  // thường là mốc 00:00 của ngày cuối).
  final endExclusive =
      DateTime(periodEnd.year, periodEnd.month, periodEnd.day + 1);
  final hit = <BudgetAlertThreshold>{};

  for (final record in records) {
    if (record.type != 'budget_alert') continue;

    final payloadBudgetId = record.payload['budget_id'];
    if (payloadBudgetId is! String || payloadBudgetId != budgetId) continue;

    final ratio = record.payload['threshold_percentage'];
    if (ratio is! num) continue;

    final at = record.createdAt;
    if (at.isBefore(periodStart) || !at.isBefore(endExclusive)) continue;

    for (final threshold in BudgetAlertThreshold.values) {
      if ((threshold.ratio - ratio.toDouble()).abs() < 0.001) hit.add(threshold);
    }
  }
  return hit;
}

/// Đọc payload notification → route hợp lệ trong whitelist, `null` nếu payload
/// rỗng/hỏng/route không được phép (tap không điều hướng, không crash).
String? parseNotificationRoute(String? payload) {
  if (payload == null || payload.trim().isEmpty) return null;
  final match = RegExp(r'"route"\s*:\s*"([^"]+)"').firstMatch(payload);
  final route = match?.group(1);
  if (route == null || !notificationTapRoutes.contains(route)) return null;
  return route;
}
