import '../core/constants/app_constants.dart';
import '../core/utils/price_watch.dart';
import '../models/shopping_list_item_model.dart';

typedef WatchedItemsLoader = Future<List<ShoppingListItem>> Function();
typedef WatchBaselineLoader = Future<WatchBaseline?> Function({
  required String name,
  String? barcode,
  required bool excludeLatestRecord,
});
typedef PriceWatchNotifier = Future<void> Function({
  required String itemName,
  required int price,
  required PriceWatchReason reason,
  String? itemId,
});
typedef AlertPersister = Future<void> Function(String itemId, int price);

/// F-#6 Price Watch — check LOCAL, event-driven (spec: chạy NGAY LÚC user
/// scan/thêm/sửa item thành công; KHÔNG timer/cron client).
///
/// Flow: item vừa lưu (name/barcode/price) → tìm món watched khớp (barcode
/// ưu tiên, fallback tên normalize) → đọc baseline price history (local trước,
/// merge server khi online — do provider wiring cung cấp) → [evaluatePriceWatch]
/// (threshold AC 6.13/6.14 + dedup AC 6.15) → local notification + badge
/// (AC 6.13).
///
/// Mọi phụ thuộc là callback injectable → unit test không cần Flutter binding
/// (notification được thay bằng recorder).
class PriceWatchService {
  final WatchedItemsLoader loadWatchedItems;
  final WatchBaselineLoader loadBaseline;
  final PriceWatchNotifier notify;
  final AlertPersister persistAlert;

  PriceWatchService({
    required this.loadWatchedItems,
    required this.loadBaseline,
    required this.notify,
    required this.persistAlert,
  });

  /// F-#5 P1 (AC 5.13a/5.14): watch check sau `POST /items/bulk` — quét các
  /// món watched với dữ liệu mới ĐÚNG 1 LẦN cho TOÀN batch (KHÔNG chạy 1 lần
  /// mỗi dòng). Với mỗi món watched khớp BẤT KỲ dòng vừa tạo, dùng giá THẤP
  /// NHẤT trong batch làm giá mới (thuận lợi hơn cho alert — newLowest).
  /// Dừng ngay sau alert ĐẦU TIÊN → tối đa 1 local notification cho toàn batch
  /// (AC 5.14; dedup giá lặp vẫn do AC 6.15 giữ nguyên).
  ///
  /// [excludeLatestRecord] = true khi các record vừa tạo đã được ghi history
  /// (flow bulk add) — bị loại khỏi baseline như flow thêm đơn lẻ.
  Future<int> checkAfterBulkSaved({
    required List<({String name, String? barcode, int price})> items,
    required bool excludeLatestRecord,
  }) async {
    try {
      final fresh = items
          .where((i) => i.name.trim().isNotEmpty && i.price > 0)
          .toList();
      if (fresh.isEmpty) return 0;

      final watched = await loadWatchedItems();
      for (final item in watched) {
        // Giá thấp nhất trong các dòng vừa tạo khớp món watched này.
        int? newPrice;
        for (final f in fresh) {
          if (!matchesProductKey(
            aBarcode: item.barcode,
            aName: item.name,
            bBarcode: f.barcode,
            bName: f.name,
          )) {
            continue;
          }
          if (newPrice == null || f.price < newPrice) newPrice = f.price;
        }
        if (newPrice == null) continue;

        final baseline = await loadBaseline(
          name: item.name,
          barcode: item.barcode,
          excludeLatestRecord: excludeLatestRecord,
        );

        final evaluation = evaluatePriceWatch(
          watched: true,
          newPrice: newPrice,
          knownMinPrice: baseline?.minPrice,
          lastPurchasePrice: baseline?.lastPrice,
          lastAlertedPrice: item.lastAlertPrice,
          dropPercentThreshold: AppConstants.priceWatchDropPercent,
        );

        if (!evaluation.shouldAlert || evaluation.reason == null) continue;

        await persistAlert(item.id, newPrice);
        await notify(
          itemName: item.name,
          price: newPrice,
          reason: evaluation.reason!,
          itemId: item.id, // AC 12.5 — deep-link mở đúng món trong list
        );
        // AC 5.14 — tối đa 1 notification cho toàn batch.
        return 1;
      }
      return 0;
    } catch (_) {
      // Watch là tính năng phụ — lỗi không được làm vỡ flow bulk confirm.
      return 0;
    }
  }

  /// Gọi sau khi item được TẠO ([excludeLatestRecord] = true — record vừa ghi
  /// bị loại khỏi baseline) hoặc SỬA (= false — history chưa có record mới).
  ///
  /// Trả về số alert đã bắn. KHÔNG bao giờ ném lỗi lên caller — watch là
  /// tính năng phụ, lỗi phải không chặn flow thêm/sửa item.
  Future<int> checkAfterItemSaved({
    required String name,
    String? barcode,
    required int price,
    required bool excludeLatestRecord,
  }) async {
    try {
      if (name.trim().isEmpty || price <= 0) return 0;

      final watched = await loadWatchedItems();
      var fired = 0;
      for (final item in watched) {
        if (!matchesProductKey(
          aBarcode: item.barcode,
          aName: item.name,
          bBarcode: barcode,
          bName: name,
        )) {
          continue;
        }

        final baseline = await loadBaseline(
          name: item.name,
          barcode: item.barcode,
          excludeLatestRecord: excludeLatestRecord,
        );

        final evaluation = evaluatePriceWatch(
          watched: true,
          newPrice: price,
          knownMinPrice: baseline?.minPrice,
          lastPurchasePrice: baseline?.lastPrice,
          lastAlertedPrice: item.lastAlertPrice,
          dropPercentThreshold: AppConstants.priceWatchDropPercent,
        );

        if (!evaluation.shouldAlert || evaluation.reason == null) continue;

        await persistAlert(item.id, price);
        await notify(
          itemName: item.name,
          price: price,
          reason: evaluation.reason!,
          itemId: item.id, // AC 12.5 — deep-link mở đúng món trong list
        );
        fired++;
      }
      return fired;
    } catch (_) {
      // Món watched lỗi tra cứu/notification → bỏ qua, không làm vỡ flow add.
      return 0;
    }
  }
}
