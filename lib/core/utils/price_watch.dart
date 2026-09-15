/// F-#6 Price Watch + Price Intelligence — logic thuần KHÔNG phụ thuộc
/// Flutter/Riverpod/DB (unit test độc lập, cùng phong cách `deal_badge.dart`).
///
/// Phủ các AC:
/// - Match sản phẩm theo barcode (ưu tiên khi cả hai có) hoặc tên normalize
///   (lowercase + trim + gộp khoảng trắng — khớp tự nhiên với
///   `price_history.item_name` lowercase của BE).
/// - Trigger alert (AC 6.13): giá mới < mức thấp nhất đã biết, HOẶC giảm
///   ≥ `AppConstants.priceWatchDropPercent` so với lần mua gần nhất.
/// - Chưa có baseline (0 record history) → không alert (AC 6.16).
/// - Dedup: mỗi lần giảm giá chỉ alert đúng 1 lần (AC 6.15) — so giá đã alert
///   gần nhất (`lastAlertedPrice`); trùng → bỏ qua.
/// - "Giá tốt nhất trong 90 ngày" (AC 6.9): chọn record rẻ nhất trong cửa sổ
///   thời gian, dùng chung `AppConstants.priceHistoryDays`.
library;

import '../constants/app_constants.dart';
import '../../models/price_history_model.dart';

/// Chuẩn hoá tên để match: lowercase + trim + gộp nhiều khoảng trắng thành 1.
/// BE lưu `PriceHistory.item_name` lowercase → khớp tự nhiên (spec F-#6).
String normalizeMatchKey(String raw) =>
    raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Hai sản phẩm có khớp nhau không — barcode (nếu CẢ HAI có) ưu tiên,
/// fallback tên normalize (spec F-#6 Notes: match key).
bool matchesProductKey({
  required String? aBarcode,
  required String aName,
  required String? bBarcode,
  required String bName,
}) {
  final aBc = aBarcode?.trim();
  final bBc = bBarcode?.trim();
  if (aBc != null && aBc.isNotEmpty && bBc != null && bBc.isNotEmpty) {
    return aBc == bBc;
  }
  return normalizeMatchKey(aName) == normalizeMatchKey(bName);
}

/// Lý do bật alert (AC 6.13).
enum PriceWatchReason {
  /// (a) Giá mới THẤP HƠN mức thấp nhất đã biết trong history.
  newLowest,

  /// (b) Giảm ≥ PRICE_WATCH_DROP_PERCENT so với lần mua gần nhất.
  droppedEnough,
}

/// Kết quả đánh giá một lần check watch.
class PriceWatchEvaluation {
  final bool shouldAlert;
  final PriceWatchReason? reason;

  /// % giảm của giá mới so với lần mua gần nhất (dương = giảm).
  final double dropPercent;

  const PriceWatchEvaluation._({
    required this.shouldAlert,
    this.reason,
    required this.dropPercent,
  });

  const PriceWatchEvaluation._noAlert(this.dropPercent)
      : shouldAlert = false,
        reason = null;
}

/// Đánh giá xem một mức giá mới có bật alert cho món đang watched hay không.
///
/// [knownMinPrice] / [lastPurchasePrice] = baseline TRƯỚC khi record mới được
/// ghi (với flow add: caller loại record vừa thêm). Cả hai `null` → chưa có
/// baseline → không alert (AC 6.16).
/// [lastAlertedPrice] = giá P đã alert gần nhất; trùng giá mới → không lặp
/// (AC 6.15). Threshold mặc định đọc từ `AppConstants.priceWatchDropPercent`
/// (AC 6.14 — một nơi duy nhất).
PriceWatchEvaluation evaluatePriceWatch({
  required bool watched,
  required int newPrice,
  required int? knownMinPrice,
  required int? lastPurchasePrice,
  required int? lastAlertedPrice,
  double dropPercentThreshold = AppConstants.priceWatchDropPercent,
}) {
  double dropPercent(int last) =>
      last > 0 ? ((last - newPrice) / last) * 100 : 0.0;

  if (!watched) return const PriceWatchEvaluation._noAlert(0);
  // AC 6.16: chưa có baseline (≥ 1 record history) → chưa alert.
  if (knownMinPrice == null || lastPurchasePrice == null) {
    return const PriceWatchEvaluation._noAlert(0);
  }

  final drop = dropPercent(lastPurchasePrice);
  final isNewLowest = newPrice < knownMinPrice;
  final isDroppedEnough = drop >= dropPercentThreshold;

  if (!isNewLowest && !isDroppedEnough) {
    return PriceWatchEvaluation._noAlert(drop);
  }
  // AC 6.15: lần giảm ở mức P đã alert rồi mà giá mới nhất vẫn là P → bỏ qua.
  if (lastAlertedPrice != null && lastAlertedPrice == newPrice) {
    return PriceWatchEvaluation._noAlert(drop);
  }

  return PriceWatchEvaluation._(
    shouldAlert: true,
    reason: isNewLowest ? PriceWatchReason.newLowest : PriceWatchReason.droppedEnough,
    dropPercent: double.parse(drop.toStringAsFixed(2)),
  );
}

/// Một record giá tốt nhất trong cửa sổ thời gian (AC 6.9).
class BestPriceRecord {
  final int price;
  final DateTime date;

  const BestPriceRecord({required this.price, required this.date});
}

/// Baseline giá của một sản phẩm TRƯỚC khi record mới được ghi:
/// [minPrice] = mức thấp nhất đã biết, [lastPrice] = lần mua gần nhất.
/// `null` (không có record nào) → chưa có baseline (AC 6.16).
typedef WatchBaseline = ({int minPrice, int lastPrice});

/// "Giá tốt nhất trong 90 ngày": record RẺ NHẤT trong [days] ngày tính từ
/// [now]. Trả `null` khi không có point nào trong cửa sổ (UI ẩn cả khối —
/// AC 6.10, không hiện "0 đ").
/// [points] accept bất kỳ thứ tự nào; so sánh theo mốc ngày (không phụ thuộc
/// giờ trong ngày).
BestPriceRecord? bestPriceWithinDays(
  List<PriceHistoryPoint> points, {
  int days = AppConstants.priceHistoryDays,
  DateTime? now,
}) {
  if (points.isEmpty) return null;
  final end = (now ?? DateTime.now());
  final start = DateTime(end.year, end.month, end.day)
      .subtract(Duration(days: days))
      .millisecondsSinceEpoch;

  BestPriceRecord? best;
  for (final p in points) {
    final at = DateTime(
        p.purchasedAt.year, p.purchasedAt.month, p.purchasedAt.day);
    if (at.millisecondsSinceEpoch < start) continue;
    if (best == null || p.price < best.price) {
      best = BestPriceRecord(price: p.price, date: p.purchasedAt);
    }
  }
  return best;
}

/// Baseline cho watch check từ danh sách points (bất kỳ thứ tự — hàm tự sắp
/// giảm dần theo thời gian). Với flow THÊM item, [excludeLatestRecord] = true
/// để loại record vừa ghi (mới nhất) khỏi baseline.
/// Trả `null` khi không còn record nào → AC 6.16 (chưa có baseline).
WatchBaseline? baselineFromPoints(
  List<PriceHistoryPoint> points, {
  required bool excludeLatestRecord,
}) {
  final sorted = [...points]..sort((a, b) =>
      b.purchasedAt.millisecondsSinceEpoch -
      a.purchasedAt.millisecondsSinceEpoch);
  if (excludeLatestRecord && sorted.isNotEmpty) sorted.removeAt(0);
  if (sorted.isEmpty) return null;

  var min = sorted.first.price;
  for (final p in sorted.skip(1)) {
    if (p.price < min) min = p.price;
  }
  return (minPrice: min, lastPrice: sorted.first.price);
}
