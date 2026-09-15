/// M-1 — F-#5 Phase 2 (Auto-Match) — logic thuần KHÔNG phụ thuộc
/// Flutter/Riverpod/DB (unit test độc lập, cùng phong cách
/// `receipt_duplicate.dart`).
///
/// Phủ các AC:
/// - AC 5.15: dòng OCR khớp "chắc chắn" một record sổ giá local → auto-match
///   (tự tick + badge "Tự khớp: <tên record>"). Nhánh tên: `normalizeMatchKey`
///   trùng + giá trong dải ±10% (`receiptDuplicatePriceTolerance` — dùng lại
///   constant của p1).
/// - AC 5.16: nhánh barcode — barcode dòng OCR khớp `barcode` một record sổ
///   giá → auto-match BẤKỂ giá lệch bao nhiêu; cả hai nhánh cùng khớp nhưng
///   trỏ hai sản phẩm khác nhau → barcode thắng (định danh mạnh hơn tên).
///   Barcode vắng (response chưa có — contract pending) → nhánh inert, không
///   crash, không badge nào gắn do barcode.
/// - AC 5.17 (edge): tên sau trim dài ≤ 2 ký tự, hoặc giá ≤ 0 → KHÔNG
///   auto-match dưới bất kỳ nhánh nào (kể cả barcode khớp).
/// - AC 5.18 (precedence): record khớp nằm trong cửa sổ trùng ≤ 7 ngày
///   (`receiptDuplicateWindowDays`) → KHÔNG auto-match — cảnh báo trùng p1
///   thắng, không bao giờ tự tick một dòng đang nghi trùng.
/// - Cửa sổ tra cứu: `priceHistoryDays` = 90 ngày (dùng lại constant sẵn có —
///   auto-match là "nhận diện sản phẩm quen", rộng hơn cửa sổ trùng 7 ngày).
/// - AC 5.20: ngưỡng tin cậy = `AppConstants.receiptAutoMatchConfidence`
///   (0.80) — điểm nhánh barcode = 1.0, nhánh tên = 0.85 khai báo MỘT nơi
///   cùng matcher; không hardcode rải rác.
/// - Nhiều record khớp → lấy MỚI NHẤT (pattern AC 5.3).
library;

import '../constants/app_constants.dart';
import 'price_watch.dart' show normalizeMatchKey;

/// Điểm tin cậy của nhánh barcode (AC 5.20 — khai báo MỘT nơi cùng matcher,
/// không hardcode ở nơi khác).
const double kReceiptAutoMatchBarcodeConfidence = 1.0;

/// Điểm tin cậy của nhánh tên normalize + giá ±10%.
const double kReceiptAutoMatchNameConfidence = 0.85;

/// Nhánh đã tạo ra match — dùng để định danh + test.
enum AutoMatchBy { barcode, name }

/// Một record sổ giá local (bảng `price_history`: `item_name` lowercase,
/// `barcode`, `price`, `purchased_at`) dùng để auto-match. Nguồn dữ liệu match
/// theo spec là sổ giá (log mua thuần), KHÔNG phải bảng items.
class PriceHistoryMatchRecord {
  final String name;
  final int price;

  /// `null` khi BE chưa ghi barcode cho record (contract pending — AC 5.16).
  final String? barcode;
  final DateTime purchasedAt;

  const PriceHistoryMatchRecord({
    required this.name,
    required this.price,
    this.barcode,
    required this.purchasedAt,
  });
}

/// Kết quả auto-match của một dòng OCR.
class AutoMatchResult {
  /// Tên record khớp — hiển thị trong badge "Tự khớp: <tên record>" (AC 5.15).
  final String matchedName;

  /// Giá record khớp.
  final int matchedPrice;

  /// Ngày mua của record khớp.
  final DateTime purchasedAt;

  /// Điểm tin cậy: 1.0 (barcode) / 0.85 (tên) — luôn >= ngưỡng chung.
  final double confidence;

  /// Nhánh đã khớp.
  final AutoMatchBy matchedBy;

  const AutoMatchResult({
    required this.matchedName,
    required this.matchedPrice,
    required this.purchasedAt,
    required this.confidence,
    required this.matchedBy,
  });
}

/// Tuổi record có nằm ngoài cửa sổ cho phép không?
///
/// - Ngoài cửa sổ tra cứu [maxAge] (90 ngày) → bỏ.
/// - Trong cửa sổ trùng [dupWindow] (≤ 7 ngày, ranh giới inclusive như AC 5.3)
///   → bỏ (AC 5.18 — cảnh báo trùng p1 thắng auto-match).
/// - Record "tương lai" do lệch đồng hồ → coi như trong cửa sổ trùng → bỏ.
bool _rejectedByWindow(DateTime now, DateTime purchasedAt,
    Duration maxAge, Duration dupWindow) {
  final age = now.difference(purchasedAt);
  return age > maxAge || age <= dupWindow;
}

/// Tìm auto-match cho một dòng OCR trong sổ giá local.
///
/// Trả `null` khi dòng KHÔNG đủ điều kiện tự tick (→ đi luồng uncertain p1,
/// AC 5.19 — không đổi default nào). Điều kiện biên nằm hết trong function để
/// unit test không cần DB:
///
/// - Guard tuyệt đối (CẢ HAI nhánh — AC 5.17): giá OCR > 0; tên sau trim dài
///   hơn 2 ký tự.
/// - Nhánh (a) barcode (AC 5.16): barcode khác rỗng VÀ khớp `barcode` một
///   record trong [history] — không xét giá. Barcode vắng (null/rỗng/whitespace)
///   → nhánh inert.
/// - Nhánh (b) tên + giá (AC 5.15): `normalizeMatchKey(tên)` trùng một record
///   VÀ |giá OCR − giá record| / giá record ≤ [tolerance]. Chỉ chạy khi nhánh
///   barcode CHƯA khớp (barcode thắng khi hai nhánh trỏ hai sản phẩm khác
///   nhau — AC 5.16).
/// - Cả hai nhánh: record phải trong cửa sổ [windowDays] (90 ngày) và NGOÀI
///   cửa sổ trùng [duplicateWindowDays] (7 ngày — AC 5.18).
/// - Nhiều record khớp cùng nhánh → lấy record MỚI NHẤT.
/// - Điểm nhánh < [minConfidence] → không auto (AC 5.20 — cơ chế ngưỡng).
AutoMatchResult? findAutoMatch({
  required String name,
  required int price,
  String? barcode,
  required List<PriceHistoryMatchRecord> history,
  DateTime? now,
  int windowDays = AppConstants.priceHistoryDays,
  int duplicateWindowDays = AppConstants.receiptDuplicateWindowDays,
  double tolerance = AppConstants.receiptDuplicatePriceTolerance,
  double minConfidence = AppConstants.receiptAutoMatchConfidence,
}) {
  // AC 5.17 — tên rác / giá rác: chặn tuyệt đối cả hai nhánh.
  if (price <= 0) return null;
  if (name.trim().length <= 2) return null;

  final refTime = now ?? DateTime.now();
  final maxAge = Duration(days: windowDays);
  final dupWindow = Duration(days: duplicateWindowDays);

  PriceHistoryMatchRecord? best;
  var bestConfidence = 0.0;
  var bestBy = AutoMatchBy.name;

  // (a) Nhánh barcode — xét trước, định danh mạnh hơn tên (AC 5.16).
  final bc = barcode?.trim();
  if (bc != null && bc.isNotEmpty) {
    for (final r in history) {
      final rBc = r.barcode?.trim();
      if (rBc == null || rBc.isEmpty || rBc != bc) continue;
      if (_rejectedByWindow(refTime, r.purchasedAt, maxAge, dupWindow)) {
        continue;
      }
      if (best == null || r.purchasedAt.isAfter(best.purchasedAt)) {
        best = r;
        bestConfidence = kReceiptAutoMatchBarcodeConfidence;
        bestBy = AutoMatchBy.barcode;
      }
    }
  }

  // (b) Nhánh tên + giá — chỉ khi barcode chưa khớp sản phẩm nào (AC 5.16:
  // hai nhánh trỏ hai sản phẩm khác nhau → barcode thắng).
  if (best == null) {
    final key = normalizeMatchKey(name);
    for (final r in history) {
      if (normalizeMatchKey(r.name) != key) continue;
      if (r.price <= 0) continue; // không so được (chia 0) → bỏ record
      if (((price - r.price) / r.price).abs() > tolerance) continue;
      if (_rejectedByWindow(refTime, r.purchasedAt, maxAge, dupWindow)) {
        continue;
      }
      if (best == null || r.purchasedAt.isAfter(best.purchasedAt)) {
        best = r;
        bestConfidence = kReceiptAutoMatchNameConfidence;
        bestBy = AutoMatchBy.name;
      }
    }
  }

  if (best == null) return null;
  // AC 5.20 — chỉ auto khi điểm nhánh đạt ngưỡng tin cậy chung.
  if (bestConfidence < minConfidence) return null;

  return AutoMatchResult(
    matchedName: best.name,
    matchedPrice: best.price,
    purchasedAt: best.purchasedAt,
    confidence: bestConfidence,
    matchedBy: bestBy,
  );
}
