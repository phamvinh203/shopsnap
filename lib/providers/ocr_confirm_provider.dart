import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/receipt_auto_match.dart';
import '../core/utils/receipt_duplicate.dart';
import '../database/daos/item_dao.dart';
import '../database/daos/price_history_dao.dart';
import '../services/category_classifier.dart';
import 'database_provider.dart';

/// Giới hạn BULK_MAX của POST /items/bulk — provider để widget test override
/// (app thật luôn đọc `AppConstants.receiptBulkMax` = 50).
final bulkMaxProvider = Provider<int>((ref) => AppConstants.receiptBulkMax);

/// F-#5 P1 — dữ liệu đối chiếu cho màn confirm hóa đơn:
///
/// - Trả về danh sách item local gần đây (30 ngày, MỚI → CŨ) dưới dạng
///   [ReceiptHistoryEntry] để `findReceiptDuplicate` chạy thuần trên UI
///   (offline-friendly, không gọi API khi review — theo Notes của spec).
/// - Cùng lúc seed lớp tự học của [CategoryClassifier] từ lịch sử (AC 5.2:
///   "lần sau OCR ra dòng cùng tên X → mặc định chọn lại category user đã
///   chọn" — item mới nhất cùng tên quyết định).
///
/// Provider riêng (thay vì đọc thẳng databaseProvider trong widget) để widget
/// test override dễ dàng bằng dữ liệu cắm vào, không chạm SQLite.
final ocrRecentEntriesProvider =
    FutureProvider<List<ReceiptHistoryEntry>>((ref) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    final items = await ItemDao(db).findRecent(days: 30);
    // AC 5.2: seed lớp tự học — findRecent sắp MỚI → CŨ nên item mới nhất
    // cùng tên thắng (seedFromHistory không ghi đè key đã có).
    CategoryClassifier.seedFromHistory(items.map((i) => (i.name, i.categoryId)));
    return receiptEntriesFromItems(items);
  } catch (_) {
    // DB hỏng/chưa mở được → coi như không có dữ liệu đối chiếu; màn confirm
    // vẫn mở được (chỉ mất cảnh báo trùng, không chặn flow OCR).
    return const [];
  }
});

/// M-1 — dữ liệu AUTO-MATCH cho màn confirm hóa đơn: toàn bộ record SỔ GIÁ
/// local (`price_history` — nguồn match theo spec, NOT bảng items) trong cửa
/// sổ `AppConstants.priceHistoryDays` = 90 ngày, MỚI → CŨ. Query 1 lần khi
/// mở màn (pattern [ocrRecentEntriesProvider]), thuần SQLite, KHÔNG gọi API
/// → auto-match (badge + auto-tick) chạy y hệt khi offline (AC 5.25).
final ocrMatchRecordsProvider =
    FutureProvider<List<PriceHistoryMatchRecord>>((ref) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    return await PriceHistoryDao(db).findRecentRecords();
  } catch (_) {
    // DB hỏng/chưa mở được → không có dữ liệu auto-match; màn confirm vẫn
    // mở được, mọi dòng đi luồng uncertain p1 (AC 5.19).
    return const [];
  }
});
