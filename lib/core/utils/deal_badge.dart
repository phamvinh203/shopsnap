/// F-#1 Deal Badge — Smart Purchase Recommendation (SIGNATURE FEATURE).
///
/// Pure logic KHÔNG phụ thuộc Flutter/Riverpod — unit test được độc lập.
/// Input: current / avg / min / previous + threshold (%). Output: mức badge,
/// % lệch so avg (1 chữ số thập phân) và dòng gợi ý theo AC 1.7–1.9.
///
/// Ranh giới theo spec:
/// - current <  avg − threshold% → DEAL TỐT
/// - current >  avg + threshold% → GIÁ CAO
/// - trong khoảng (KỂ CẢ == biên hoặc == avg) → GIÁ BÌNH THƯỜNG
///
/// Threshold đọc từ BE config (`deal_threshold_percent` trong response
/// price-history, env `DEAL_BADGE_THRESHOLD_PERCENT`) — đổi config là badge
/// đổi theo, không cần deploy lại mobile (AC 1.11). Thiếu/invalid → default 5%.
library;

/// Ngưỡng mặc định ±5% so với trung bình (spec F-#1 — chỉ là fallback,
/// KHÔNG hardcode đè config BE).
const double kDefaultDealThresholdPercent = 5.0;

/// 3 mức badge.
enum DealBadgeLevel { goodDeal, highPrice, normal }

/// Kết quả đánh giá giá cho một item.
class DealBadgeResult {
  /// Mức badge hiện tại.
  final DealBadgeLevel level;

  /// % lệch của current so với avg, đã làm tròn 1 chữ số thập phân.
  /// Âm = rẻ hơn avg, dương = đắt hơn avg, 0 = bằng avg.
  final double deviationPercent;

  /// Ngưỡng thực tế đã dùng (sau resolve) — % so với avg.
  final double thresholdPercent;

  /// `true` khi price history có ≥ 2 records (đủ dữ liệu để đánh giá).
  final bool hasEnoughData;

  /// Note khi THIẾU dữ liệu (đúng 1 record — AC 1.5); `null` nếu đủ dữ liệu.
  final String? insufficientNote;

  const DealBadgeResult({
    required this.level,
    required this.deviationPercent,
    required this.thresholdPercent,
    required this.hasEnoughData,
    this.insufficientNote,
  });

  /// Nhãn badge hiển thị trên UI.
  String get label => switch (level) {
        DealBadgeLevel.goodDeal => 'DEAL TỐT',
        DealBadgeLevel.highPrice => 'GIÁ CAO',
        DealBadgeLevel.normal => 'GIÁ BÌNH THƯỜNG',
      };

  /// Dòng mô tả % lệch so avg — "Rẻ hơn trung bình 7.2%" / "Đắt hơn trung
  /// bình 12.5%" (AC 1.2/1.3); bằng avg → "Giá bằng trung bình các lần mua".
  String get deviationLabel {
    if (deviationPercent == 0) return 'Giá bằng trung bình các lần mua';
    final abs = deviationPercent.abs().toStringAsFixed(1);
    return deviationPercent < 0
        ? 'Rẻ hơn trung bình $abs%'
        : 'Đắt hơn trung bình $abs%';
  }

  /// Dòng gợi ý tự nhiên theo mức badge (AC 1.7/1.8/1.9).
  String get suggestion => switch (level) {
        DealBadgeLevel.goodDeal =>
          'Nếu bạn đang cần mua trong tuần này, đây là mức giá khá tốt.',
        DealBadgeLevel.highPrice =>
          'Giá đang cao hơn mức thường thấy — cân nhắc chờ hoặc so cửa hàng khác.',
        DealBadgeLevel.normal =>
          'Giá ở mức tương đương trung bình các lần mua trước.',
      };
}

/// Chuẩn hoá threshold từ BE config: thiếu / NaN / <= 0 → default 5% (AC 1.11).
double resolveDealThreshold(num? raw) {
  if (raw == null) return kDefaultDealThresholdPercent;
  final value = raw.toDouble();
  if (value.isNaN || value <= 0) return kDefaultDealThresholdPercent;
  return value;
}

/// Tính Deal Badge từ các mốc giá (pure function — không side effect).
///
/// [recordCount] là số records trong price history của CHÍNH user này
/// (user-scoped, AC 1.10): < 2 → badge GIÁ BÌNH THƯỜNG + note thiếu dữ liệu.
DealBadgeResult computeDealBadge({
  required int current,
  required int avg,
  int? min,
  int? previous,
  int recordCount = 0,
  double thresholdPercent = kDefaultDealThresholdPercent,
}) {
  final threshold = resolveDealThreshold(thresholdPercent);
  final hasEnoughData = recordCount >= 2;

  // % lệch so avg — avg <= 0 (dữ liệu suy biến) thì coi như 0 để tránh chia 0.
  final deviation =
      avg > 0 ? ((current - avg) / avg) * 100 : 0.0;
  final rounded = double.parse(deviation.toStringAsFixed(1));

  if (!hasEnoughData) {
    return DealBadgeResult(
      level: DealBadgeLevel.normal,
      deviationPercent: rounded,
      thresholdPercent: threshold,
      hasEnoughData: false,
      insufficientNote: 'Chưa đủ dữ liệu để đánh giá giá',
    );
  }

  final delta = avg * threshold / 100;
  // avg <= 0 (dữ liệu suy biến): không có mốc so sánh hợp lệ → coi như bình
  // thường thay vì so current với 0 (tránh false-positive GIÁ CAO).
  final level = avg <= 0
      ? DealBadgeLevel.normal
      : current < avg - delta
          ? DealBadgeLevel.goodDeal
          : current > avg + delta
              ? DealBadgeLevel.highPrice
              : DealBadgeLevel.normal;

  return DealBadgeResult(
    level: level,
    deviationPercent: rounded,
    thresholdPercent: threshold,
    hasEnoughData: true,
  );
}
