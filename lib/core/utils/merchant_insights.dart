/// M-3 — F-#7 Merchant Intelligence: logic thuần KHÔNG phụ thuộc
/// Flutter/Riverpod/DB (unit test độc lập — cùng phong cách
/// `spending_dashboard.dart` / `receipt_duplicate.dart`).
///
/// Input là danh sách lượt mua `{name, storeName, price}` lấy từ SQLite local
/// (caller truyền vào) → chạy được cả offline (AC 7.14).
///
/// Phủ các AC:
/// - AC 7.8: top 5 nơi mua theo tổng chi GIẢM DẦN, mỗi nơi kèm số lần mua.
/// - AC 7.11: insight so sánh giá trung bình CÙNG MÓN giữa các nơi mua khi đủ
///   dữ liệu (≥ 2 nơi, mỗi nơi ≥ 2 lần mua); Y = round((baseline − cheapest) /
///   baseline × 100), tối đa 3 dòng, sắp theo Y giảm dần.
/// - AC 7.12: Y ≤ 0 hoặc baseline ≤ 0 → không insight; giá 0 KHÔNG tính vào
///   avg và không làm baseline; thiếu ngưỡng dữ liệu → không insight cho món
///   đó, phần còn lại hoạt động bình thường.
/// - AC 7.13: nhóm nơi mua theo NGUYÊN VĂN (không merge "CoopMart" và
///   "coop mart" — normalization là scope BE); nhóm "cùng món" thì dùng
///   `normalizeMatchKey` (lowercase + trim + gộp khoảng trắng) tái dùng từ
///   `price_watch.dart`.
library;

import 'price_watch.dart';

/// Một lượt mua tối giản cho phân tích nơi mua.
class MerchantPurchase {
  final String name;

  /// Nguyên văn nơi mua — null/rỗng = không biết nơi mua (bỏ qua).
  final String? storeName;
  final int price;

  const MerchantPurchase({
    required this.name,
    this.storeName,
    required this.price,
  });
}

/// Tổng chi của MỘT nơi mua (nguyên văn) trong kỳ.
class MerchantSpend {
  final String storeName;
  final int totalSpent;
  final int purchaseCount;

  const MerchantSpend({
    required this.storeName,
    required this.totalSpent,
    required this.purchaseCount,
  });
}

/// Một dòng insight "Bạn thường mua <itemName> rẻ hơn ~<percentSaved>% ở
/// <cheapestStore>".
class MerchantPriceInsight {
  final String itemName;
  final String cheapestStore;

  /// % tiết kiệm so với baseline (số nguyên > 0 — AC 7.11/7.12).
  final int percentSaved;
  final int cheapestAvgPrice;
  final int baselineAvgPrice;

  const MerchantPriceInsight({
    required this.itemName,
    required this.cheapestStore,
    required this.percentSaved,
    required this.cheapestAvgPrice,
    required this.baselineAvgPrice,
  });
}

/// Kết quả phân tích nơi mua cho 1 kỳ — card Summary đọc cả 2 phần.
class MerchantSummary {
  final List<MerchantSpend> topStores;
  final List<MerchantPriceInsight> insights;

  const MerchantSummary({
    required this.topStores,
    required this.insights,
  });

  /// AC 7.10: kỳ không có lượt mua nào có nơi mua → card ẩn.
  bool get isEmpty => topStores.isEmpty;
}

/// Key nhóm "cùng món" — chuẩn hoá tên (lowercase + trim + gộp khoảng trắng)
/// để "Sữa Vinamilk" và "sữa   vinamilk" về cùng nhóm (AC 7.11 + Notes spec).
String merchantProductKey(String rawName) => normalizeMatchKey(rawName);

/// storeName hợp lệ để tính toán: khác null và khác rỗng (sau trim).
bool hasStore(String? storeName) {
  final s = storeName;
  return s != null && s.trim().isNotEmpty;
}

/// AC 7.8 — top [limit] (mặc định 5) nơi mua theo tổng chi GIẢM DẦN, đếm theo
/// nguyên văn store_name (AC 7.13 — không merge biến thể chữ hoa/thường).
/// Lượt mua không có nơi mua (null/rỗng) bị bỏ qua. Tie-break ổn định:
/// tổng chi → số lần mua → tên (A→Z) để UI không nhấp nháy thứ tự.
List<MerchantSpend> topStoresBySpend(
  List<MerchantPurchase> purchases, {
  int limit = 5,
}) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  for (final p in purchases) {
    if (!hasStore(p.storeName)) continue;
    final store = p.storeName!;
    totals[store] = (totals[store] ?? 0) + p.price;
    counts[store] = (counts[store] ?? 0) + 1;
  }
  final stores = totals.keys.toList()
    ..sort((a, b) {
      final byTotal = totals[b]!.compareTo(totals[a]!);
      if (byTotal != 0) return byTotal;
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return a.compareTo(b);
    });
  return [
    for (final s in stores.take(limit))
      MerchantSpend(
        storeName: s,
        totalSpent: totals[s]!,
        purchaseCount: counts[s]!,
      ),
  ];
}

/// AC 7.11/7.12 — insight so sánh giá trung bình cùng món giữa các nơi mua.
///
/// Thuật toán từng món (nhóm theo [merchantProductKey]):
/// 1. Bỏ lượt mua giá ≤ 0 (không vào avg, không làm baseline — AC 7.12).
/// 2. Nhóm theo nơi mua NGUYÊN VĂN; chỉ nơi có ≥ [minPurchasesPerStore] lần
///    mua đủ điều kiện.
/// 3. Số nơi đủ điều kiện < [minStores] → không insight cho món đó.
/// 4. avg nơi = trung bình giá tại nơi; `cheapest` = avg nhỏ nhất; `baseline`
///    = trung bình trên TẤT CẢ lần mua của các nơi đủ điều kiện.
/// 5. Y = round((baseline − cheapest) / baseline × 100); Y ≤ 0 → không insight
///    (không chia 0 vì baseline > 0 đã bảo đảm bởi bước 1).
///
/// Kết quả sắp Y GIẢM DẦN, tối đa [maxInsights] dòng (AC 7.11).
List<MerchantPriceInsight> merchantPriceInsights(
  List<MerchantPurchase> purchases, {
  int minStores = 2,
  int minPurchasesPerStore = 2,
  int maxInsights = 3,
}) {
  // 1. Lọc hợp lệ: có nơi mua + giá > 0.
  final valid = purchases
      .where((p) => hasStore(p.storeName) && p.price > 0)
      .toList();

  // Nhóm theo món.
  final byProduct = <String, List<MerchantPurchase>>{};
  for (final p in valid) {
    byProduct.putIfAbsent(merchantProductKey(p.name), () => []).add(p);
  }

  final insights = <MerchantPriceInsight>[];
  for (final entry in byProduct.entries) {
    final group = entry.value;

    // 2. Nhóm theo nơi mua nguyên văn + đếm số lần mua.
    final pricesByStore = <String, List<int>>{};
    for (final p in group) {
      pricesByStore.putIfAbsent(p.storeName!, () => []).add(p.price);
    }
    final qualifying = pricesByStore.entries
        .where((e) => e.value.length >= minPurchasesPerStore)
        .map((e) => MapEntry(e.key, e.value))
        .toList();

    // 3. Không đủ ngưỡng số nơi → bỏ món này (AC 7.12).
    if (qualifying.length < minStores) continue;

    // 4. avg từng nơi + baseline trên tất cả lần mua các nơi đủ điều kiện.
    var cheapestStore = '';
    var cheapestAvg = double.infinity;
    var grandTotal = 0;
    var grandCount = 0;
    for (final e in qualifying) {
      final avg = e.value.fold<int>(0, (s, p) => s + p) / e.value.length;
      if (avg < cheapestAvg) {
        cheapestAvg = avg;
        cheapestStore = e.key;
      }
      grandTotal += e.value.fold<int>(0, (s, p) => s + p);
      grandCount += e.value.length;
    }
    final baseline = grandTotal / grandCount;

    // 5. Y — baseline ≤ 0 không thể xảy ra sau bước 1 nhưng vẫn chặn (AC 7.12).
    if (baseline <= 0) continue;
    final y = ((baseline - cheapestAvg) / baseline * 100).round();
    if (y <= 0) continue; // nơi "rẻ nhất" không thực sự rẻ hơn (AC 7.12)

    insights.add(MerchantPriceInsight(
      itemName: _representativeName(group),
      cheapestStore: cheapestStore,
      percentSaved: y,
      cheapestAvgPrice: cheapestAvg.round(),
      baselineAvgPrice: baseline.round(),
    ));
  }

  // Sắp Y giảm dần, tên A→Z cho ổn định; lấy tối đa maxInsights (AC 7.11).
  insights.sort((a, b) {
    final byY = b.percentSaved.compareTo(a.percentSaved);
    if (byY != 0) return byY;
    return a.itemName.compareTo(b.itemName);
  });
  return insights.take(maxInsights).toList();
}

/// Tên hiển thị của nhóm món: biến thể NGUYÊN VĂN xuất hiện nhiều nhất,
/// hòa ở số lần thì chọn biến thể đầu tiên gặp (deterministic).
String _representativeName(List<MerchantPurchase> group) {
  final counts = <String, int>{};
  final firstSeen = <String, int>{};
  var order = 0;
  for (final p in group) {
    counts[p.name] = (counts[p.name] ?? 0) + 1;
    firstSeen.putIfAbsent(p.name, () => order++);
  }
  String best = group.first.name;
  for (final e in counts.entries) {
    final curBestCount = counts[best]!;
    if (e.value > curBestCount ||
        (e.value == curBestCount &&
            firstSeen[e.key]! < firstSeen[best]!)) {
      best = e.key;
    }
  }
  return best;
}

/// Gộp cả 2 phép tính cho 1 kỳ — entry point provider Summary gọi.
MerchantSummary buildMerchantSummary(List<MerchantPurchase> purchases) =>
    MerchantSummary(
      topStores: topStoresBySpend(purchases),
      insights: merchantPriceInsights(purchases),
    );
