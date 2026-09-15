/// M-2 — Phát hiện "có vẻ là khoản định kỳ" từ lịch sử mua: logic thuần
/// KHÔNG phụ thuộc Flutter/Riverpod/DB (unit test độc lập, cùng phong cách
/// `receipt_duplicate.dart`).
///
/// Phủ các AC:
/// - AC 4.8 (điều kiện nhận diện — ĐỒNG THỜI): nhóm theo
///   `normalizeMatchKey(name)` + số tiền CHÍNH XÁC (±0%); xuất hiện
///   ≥ [AppConstants.recurringMinOccurrences] lần; khoảng cách các lần mua
///   liên tiếp có TRUNG VỊ trong [25, 35] ngày và không có gap nào > 45 ngày.
/// - AC 4.9 (edge): giá lệch 1 đồng → KHÔNG gợi ý (±0% nghiêm ngặt); item
///   price ≤ 0 bị loại; entry recurring đang bật cùng match_key → không gợi ý
///   lại (caller truyền `activeMatchKeys`).
/// - Mọi ngưỡng (90/25/35/45/3) là constants đọc từ `AppConstants` —
///   đặt MỘT nơi duy nhất, test có thể override qua tham số.
library;

import '../constants/app_constants.dart';
import 'price_watch.dart' show normalizeMatchKey;

/// Một lần mua (từ items local 90 ngày qua, `is_deleted = 0`) dùng để quét.
class RecurringScanEntry {
  final String name;
  final int price;
  final DateTime purchasedAt;

  const RecurringScanEntry({
    required this.name,
    required this.price,
    required this.purchasedAt,
  });
}

/// Một nhóm được đề xuất biến thành khoản định kỳ.
class RecurringSuggestion {
  /// Tên hiển thị = nguyên văn của lần mua GẦN NHẤT trong nhóm.
  final String name;

  /// Khóa nhóm = normalizeMatchKey(name).
  final String matchKey;

  /// Số tiền mỗi lần mua (±0% nên mọi lần trong nhóm bằng nhau).
  final int amount;

  /// Số lần xuất hiện trong cửa sổ quét (UI: "xuất hiện N lần/3 tháng").
  final int occurrences;

  /// Ngày của lần mua gần nhất — prefill "ngày đến hạn" khi convert (AC 4.10).
  final DateTime lastPurchasedAt;

  const RecurringSuggestion({
    required this.name,
    required this.matchKey,
    required this.amount,
    required this.occurrences,
    required this.lastPurchasedAt,
  });
}

/// Trung vị của danh sách số KHÔNG RỖNG: giữa với số lẻ phần tử, trung bình
/// 2 phần tử giữa với số chẵn (vd 2 gap [30, 30] → 30.0; [25, 40] → 32.5).
double _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid].toDouble()
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
}

/// Quét danh sách lần mua → các gợi ý khoản định kỳ.
///
/// - Cửa sổ: chỉ nhận entry có `purchasedAt` trong [scanDays] ngày tính từ
///   đầu ngày [now] (cùng quy ước "90 ngày" với `bestPriceWithinDays` —
///   so theo mốc ngày, không phụ thuộc giờ trong ngày).
/// - Entry `price <= 0` hoặc tên rỗng bị loại khỏi phép quét (AC 4.9).
/// - Nhóm key = `matchKey` + `price` (±0% nghiêm ngặt — lệch 1 đồng là nhóm
///   khác, không bao giờ gộp — AC 4.9).
/// - Nhóm đủ điều kiện: ≥ [minOccurrences] lần VÀ median gap nằm trong
///   [minMedianGapDays, maxMedianGapDays] (inclusive) VÀ không gap nào
///   > [maxGapDays] (inclusive — 45 ngày vẫn tính, 46 bị loại).
/// - Nhóm có match_key trùng entry đang bật trong `activeMatchKeys`
///   → KHÔNG gợi ý lần nữa (AC 4.9).
/// - Kết quả sắp theo occurrences giảm dần, rồi lần mua gần nhất trước —
///   deterministic để UI và test ổn định.
List<RecurringSuggestion> detectRecurringSuggestions({
  required List<RecurringScanEntry> entries,
  Set<String> activeMatchKeys = const {},
  DateTime? now,
  int scanDays = AppConstants.recurringScanDays,
  int minOccurrences = AppConstants.recurringMinOccurrences,
  int minMedianGapDays = AppConstants.recurringMinMedianGapDays,
  int maxMedianGapDays = AppConstants.recurringMaxMedianGapDays,
  int maxGapDays = AppConstants.recurringMaxGapDays,
}) {
  final end = now ?? DateTime.now();

  // Cửa sổ tính từ ĐẦU NGÀY của [scanDays] ngày trước (pattern
  // bestPriceWithinDays) — một entry hôm nay luôn tính là trong cửa sổ.
  final cutoff = DateTime(end.year, end.month, end.day)
      .subtract(Duration(days: scanDays))
      .millisecondsSinceEpoch;

  // 1. Lọc + nhóm theo (matchKey, price) — ±0% nghiêm ngặt.
  final groups = <String, List<RecurringScanEntry>>{};
  for (final e in entries) {
    final name = e.name.trim();
    if (name.isEmpty || e.price <= 0) continue; // AC 4.9: loại khỏi phép quét
    final at = DateTime(e.purchasedAt.year, e.purchasedAt.month,
        e.purchasedAt.day);
    if (at.millisecondsSinceEpoch < cutoff) continue; // ngoài 90 ngày

    final matchKey = normalizeMatchKey(name);
    if (activeMatchKeys.contains(matchKey)) continue; // AC 4.9: đã khai báo
    groups.putIfAbsent('$matchKey\u0000${e.price}', () => []).add(e);
  }

  // 2. Kiểm tra chu kỳ của từng nhóm.
  final suggestions = <RecurringSuggestion>[];
  for (final group in groups.values) {
    if (group.length < minOccurrences) continue; // AC 4.8: < 3 lần là chưa đủ

    final sorted = [...group]..sort((a, b) =>
        a.purchasedAt.millisecondsSinceEpoch -
        b.purchasedAt.millisecondsSinceEpoch);

    final gaps = <int>[];
    var tooWide = false;
    for (var i = 1; i < sorted.length; i++) {
      final gap = DateTime(
              sorted[i].purchasedAt.year,
              sorted[i].purchasedAt.month,
              sorted[i].purchasedAt.day)
          .difference(DateTime(
              sorted[i - 1].purchasedAt.year,
              sorted[i - 1].purchasedAt.month,
              sorted[i - 1].purchasedAt.day))
          .inDays;
      gaps.add(gap);
      if (gap > maxGapDays) tooWide = true; // AC 4.8: chống nhiễu
    }
    if (tooWide) continue;

    final median = _median(gaps);
    if (median < minMedianGapDays || median > maxMedianGapDays) continue;

    final newest = sorted.last;
    suggestions.add(RecurringSuggestion(
      name: newest.name.trim(),
      matchKey: normalizeMatchKey(newest.name),
      amount: newest.price,
      occurrences: sorted.length,
      lastPurchasedAt: newest.purchasedAt,
    ));
  }

  suggestions.sort((a, b) {
    final byCount = b.occurrences.compareTo(a.occurrences);
    if (byCount != 0) return byCount;
    return b.lastPurchasedAt.millisecondsSinceEpoch -
        a.lastPurchasedAt.millisecondsSinceEpoch;
  });
  return suggestions;
}
