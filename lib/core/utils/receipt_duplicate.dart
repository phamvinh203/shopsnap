/// F-#5 Phase 1 (Receipt Intelligence) — logic thuần KHÔNG phụ thuộc
/// Flutter/Riverpod/DB (unit test độc lập, cùng phong cách `price_watch.dart`).
///
/// Phủ các AC:
/// - AC 5.3: dòng OCR bị gắn nhãn "có thể trùng" khi TÊN NORMALIZE khớp một
///   item đã tạo trong ≤ 7 ngày gần nhất VÀ |giá mới − giá cũ| / giá cũ ≤ 10%.
///   Tham số khung (7 ngày / 10%) đọc từ `AppConstants` — configurable, chỉ
///   đặt MỘT nơi duy nhất.
/// - Khớp nhiều item → so với item MỚI NHẤT.
/// - AC 5.8: chặn batch > `AppConstants.receiptBulkMax` (BULK_MAX của BE) TRƯỚC
///   khi gọi API.
library;

import '../constants/app_constants.dart';
import '../../models/item_model.dart';
import 'price_watch.dart' show normalizeMatchKey;

/// Một khoản đã mua (từ item local) dùng để đối chiếu trùng.
class ReceiptHistoryEntry {
  final String name;
  final int price;
  final DateTime purchasedAt;

  const ReceiptHistoryEntry({
    required this.name,
    required this.price,
    required this.purchasedAt,
  });
}

/// Kết quả match trùng của một dòng OCR.
class ReceiptDuplicateMatch {
  /// Tên item local bị trùng (hiển thị trong nhãn "Có thể trùng với <tên>").
  final String matchedName;

  /// Giá của item local bị trùng.
  final int matchedPrice;

  /// Ngày mua của item local bị trùng.
  final DateTime purchasedAt;

  /// |giá mới − giá cũ| / giá cũ (0.0 – tolerance).
  final double priceDiffRatio;

  const ReceiptDuplicateMatch({
    required this.matchedName,
    required this.matchedPrice,
    required this.purchasedAt,
    required this.priceDiffRatio,
  });
}

/// Tìm match trùng cho một dòng OCR trong danh sách item local.
///
/// - Tên so bằng [normalizeMatchKey] (lowercase + trim + gộp khoảng trắng —
///   cùng chuẩn với F-#6 `matchesProductKey`; OCR không có barcode nên bỏ qua
///   nhánh barcode).
/// - Cửa sổ thời gian: `purchasedAt` cách [now] không quá [windowDays] ngày
///   (soDuration — đúng ranh giới, kể cả mili-giây; item "tương lai" do lệch
///   đồng hồ vẫn tính là trong cửa sổ).
/// - Giá: |mới − cũ| / cũ ≤ [tolerance] (inclusive). Giá cũ ≤ 0 → không so được
///   (chia 0) → bỏ qua entry đó.
/// - Nhiều entry khớp → trả entry MỚI NHẤT (spec AC 5.3).
ReceiptDuplicateMatch? findReceiptDuplicate({
  required String name,
  required int price,
  required List<ReceiptHistoryEntry> existing,
  DateTime? now,
  int windowDays = AppConstants.receiptDuplicateWindowDays,
  double tolerance = AppConstants.receiptDuplicatePriceTolerance,
}) {
  if (name.trim().isEmpty || price <= 0) return null;

  final refTime = now ?? DateTime.now();
  final maxAge = Duration(days: windowDays);
  final key = normalizeMatchKey(name);

  ReceiptHistoryEntry? newest;
  var newestRatio = 0.0;

  for (final e in existing) {
    if (normalizeMatchKey(e.name) != key) continue;
    if (e.price <= 0) continue;
    final ratio = ((price - e.price) / e.price).abs();
    if (ratio > tolerance) continue;
    if (refTime.difference(e.purchasedAt) > maxAge) continue;

    if (newest == null || e.purchasedAt.isAfter(newest.purchasedAt)) {
      newest = e;
      newestRatio = ratio;
    }
  }

  if (newest == null) return null;
  return ReceiptDuplicateMatch(
    matchedName: newest.name,
    matchedPrice: newest.price,
    purchasedAt: newest.purchasedAt,
    // Làm tròn 4 chữ số để so sánh/hiển thị ổn định (né nhiễu double).
    priceDiffRatio: double.parse(newestRatio.toStringAsFixed(4)),
  );
}

/// Map item local → entry đối chiếu. `createdAt` của [ItemModel] = thời điểm
/// mua (item server: purchase_date — xem `ItemModel.fromApiJson`; item local:
/// lúc insert) nên dùng làm mốc "đã tạo trong ≤ 7 ngày".
List<ReceiptHistoryEntry> receiptEntriesFromItems(Iterable<ItemModel> items) =>
    items
        .map((i) => ReceiptHistoryEntry(
              name: i.name,
              price: i.price,
              purchasedAt:
                  DateTime.fromMillisecondsSinceEpoch(i.createdAt),
            ))
        .toList();

/// AC 5.8 — chặn batch vượt BULK_MAX TRƯỚC khi gọi API.
/// Trả message lỗi, hoặc `null` nếu batch hợp lệ.
String? bulkBatchLimitError(int itemCount,
        {int maxItems = AppConstants.receiptBulkMax}) =>
    itemCount > maxItems ? 'Tối đa $maxItems món mỗi lần thêm' : null;
