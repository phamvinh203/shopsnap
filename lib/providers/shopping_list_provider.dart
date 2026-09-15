import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/price_watch.dart';
import '../database/daos/price_history_dao.dart';
import '../database/daos/shopping_list_dao.dart';
import '../models/price_history_model.dart';
import '../models/shopping_list_item_model.dart';
import '../services/notification_service.dart';
import '../services/price_watch_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'notification_preferences_provider.dart';
import 'notification_provider.dart';
import 'price_history_provider.dart';

// ── DAO ──────────────────────────────────────────────────────────────────────

final shoppingListDaoProvider = FutureProvider<ShoppingListItemDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShoppingListItemDao(db);
});

// ── Danh sách mua (offline hoàn toàn — AC 6.7/6.8) ──────────────────────────

/// Notifier của Shopping List — MỌI thao tác chỉ chạm SQLite, không bao giờ
/// gọi API (AC 6.8), cũng KHÔNG enqueue sync (AC 6.17 — local-only).
class ShoppingListNotifier extends AsyncNotifier<List<ShoppingListItem>> {
  @override
  Future<List<ShoppingListItem>> build() async {
    final dao = await ref.watch(shoppingListDaoProvider.future);
    return dao.getAll();
  }

  Future<ShoppingListItemDao> _dao() => ref.read(shoppingListDaoProvider.future);

  /// Quick-add (AC 6.2/6.3): tên trim; rỗng/toàn space → trả `false`, không
  /// tạo dòng. Sau khi thêm, làm mới luôn price intel (món mới có thể đã khớp
  /// sản phẩm đã mua).
  Future<bool> addQuick(String rawName) async {
    final dao = await _dao();
    final created = await dao.insert(CreateShoppingListItemDto(name: rawName));
    if (created == null) return false;
    ref.invalidateSelf();
    ref.invalidate(shoppingItemPriceIntelProvider);
    return true;
  }

  /// Tick mua xong — đổi NGAY ở DB local, UI đọc lại (AC 6.4).
  Future<void> toggleChecked(String id) async {
    final dao = await _dao();
    await dao.toggleChecked(id);
    ref.invalidateSelf();
  }

  /// Bật/tắt "Theo dõi giá" (AC 6.12).
  Future<void> toggleWatched(String id) async {
    final dao = await _dao();
    await dao.toggleWatched(id);
    ref.invalidateSelf();
  }

  /// Sửa số lượng / giá dự kiến / danh mục — mọi trường tuỳ chọn (AC 6.6).
  Future<void> updateDetails(
    String id, {
    int? quantity,
    int? expectedPrice,
    String? categoryId,
    bool clearQuantity = false,
    bool clearExpectedPrice = false,
    bool clearCategoryId = false,
  }) async {
    final dao = await _dao();
    await dao.update(
      id,
      quantity: quantity,
      expectedPrice: expectedPrice,
      categoryId: categoryId,
      clearQuantity: clearQuantity,
      clearExpectedPrice: clearExpectedPrice,
      clearCategoryId: clearCategoryId,
    );
    ref.invalidateSelf();
  }

  /// Xoá dòng — xoá cứng không xác nhận (AC 6.5).
  Future<void> remove(String id) async {
    final dao = await _dao();
    await dao.delete(id);
    ref.invalidateSelf();
  }

  /// User mở màn list → badge alert được coi là đã xem (AC 6.13).
  Future<void> markAlertsSeen() async {
    final dao = await _dao();
    final cleared = await dao.clearUnseenAlerts();
    if (cleared > 0) ref.invalidate(shoppingListUnseenAlertsProvider);
  }
}

final shoppingListProvider =
    AsyncNotifierProvider<ShoppingListNotifier, List<ShoppingListItem>>(
  ShoppingListNotifier.new,
);

// ── Badge alert chưa xem trên entry Shopping List (AC 6.13) ─────────────────

final shoppingListUnseenAlertsProvider = FutureProvider<int>((ref) async {
  final dao = await ref.watch(shoppingListDaoProvider.future);
  return dao.countUnseenAlerts();
});

// ── Price Watch service (wiring mặc định cho app) ───────────────────────────

/// Đọc points giá khớp sản phẩm theo match key của spec (barcode HOẶC tên
/// normalize exact): LOCAL trước (AC 6.11), khi đăng nhập + có mạng thì merge
/// thêm điểm từ `GET /items/price-history` (timeout ngắn → chậm/bị ngắt thì
/// vẫn render local tức thì; offline chỉ dùng local).
Future<List<PriceHistoryPoint>> loadMatchPoints(
  Ref ref, {
  required String name,
  String? barcode,
}) async {
  final db = await ref.read(databaseProvider.future);
  final points = await PriceHistoryDao(db)
      .getMatchRecords(name: name, barcode: barcode);

  final authenticated =
      ref.read(authStateProvider).value?.isAuthenticated == true;
  if (authenticated) {
    try {
      final server = await ref
          .read(priceHistoryApiServiceProvider)
          .getPriceHistory(name: name, barcode: barcode, days: 90)
          .timeout(const Duration(milliseconds: 1500));
      if (server != null) points.addAll(server.points);
    } catch (_) {
      // Mất mạng / chậm → chỉ dùng local (AC 6.11).
    }
  }

  // Merge local + server: sort giảm dần, khử trùng lặp cùng (giá, mốc thời gian).
  points.sort((a, b) =>
      b.purchasedAt.millisecondsSinceEpoch -
      a.purchasedAt.millisecondsSinceEpoch);
  final seen = <String>{};
  points.retainWhere((p) => seen.add('${p.price}_${p.purchasedAt.millisecondsSinceEpoch}'));
  return points;
}

final priceWatchServiceProvider = Provider<PriceWatchService>((ref) {
  Future<ShoppingListItemDao> dao() async =>
      ShoppingListItemDao(await ref.read(databaseProvider.future));

  return PriceWatchService(
    loadWatchedItems: () => dao().then((d) => d.getWatched()),
    loadBaseline: ({required name, barcode, required excludeLatestRecord}) async {
      final points =
          await loadMatchPoints(ref, name: name, barcode: barcode);
      return baselineFromPoints(points, excludeLatestRecord: excludeLatestRecord);
    },
    notify: ({required itemName, required price, required reason, String? itemId}) async {
      // AC 12.7: toggle "Price alerts" tắt → KHÔNG local notification (badge
      // trong app vẫn bật để user tự thấy khi mở list). Đọc prefs ĐÃ LOAD
      // (await .future) để không fail-open khi provider còn AsyncLoading.
      final prefs = await loadNotificationPreferences(ref);
      if (prefs?.priceAlerts == false) {
        ref.invalidate(shoppingListUnseenAlertsProvider);
        return;
      }
      // Notification plugin chỉ có trên thiết bị — bọc try/catch để môi
      // trường test/không hỗ trợ không vỡ flow.
      try {
        // AC 12.13: bị chặn quyền hiển thị → cờ banner hướng dẫn trên Home.
        if (!await NotificationService.canDeliver) {
          ref.read(notificationPermissionDeniedProvider.notifier).state = true;
        } else {
          // AC 12.4/12.6: payload generic "Cập nhật giá đáng chú ý" — tên món
          // / giá KHÔNG đi vào notification, chỉ hiện trong app khi user mở.
          // AC 12.5: kèm item id để deep-link mở đúng món trong Shopping List.
          await NotificationService.showPriceWatch(itemId: itemId);
        }
      } catch (_) {}
      // Bật badge trên entry Shopping List (AC 6.13).
      ref.invalidate(shoppingListUnseenAlertsProvider);
    },
    persistAlert: (id, price) => dao().then((d) => d.markAlertFired(id, price)),
  );
});

// ── Price intelligence cho từng dòng list (AC 6.9/6.10/6.11) ────────────────

/// Key match sản phẩm cho family provider (== / hashCode để cache đúng).
class ShoppingMatchKey {
  final String name;
  final String? barcode;

  const ShoppingMatchKey({required this.name, this.barcode});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingMatchKey &&
          runtimeType == other.runtimeType &&
          normalizeMatchKey(name) == normalizeMatchKey(other.name) &&
          barcode == other.barcode;

  @override
  int get hashCode => Object.hash(normalizeMatchKey(name), barcode);
}

/// Khối price intelligence của một món trong list — `null` khi KHÔNG khớp sản
/// phẩm nào đã mua → UI ẩn toàn bộ khối (AC 6.10, không chart rỗng/“0 đ”).
class ShoppingItemPriceIntel {
  /// Points xếp TĂNG dần theo thời gian (quá khứ → nay) để vẽ sparkline.
  final List<PriceHistoryPoint> points;

  /// "Giá tốt nhất trong 90 ngày" (AC 6.9) — có thể null nếu mọi record cũ
  /// hơn 90 ngày.
  final BestPriceRecord? bestIn90Days;

  final int latestPrice;
  final int? previousPrice;

  const ShoppingItemPriceIntel({
    required this.points,
    required this.bestIn90Days,
    required this.latestPrice,
    required this.previousPrice,
  });
}

final shoppingItemPriceIntelProvider = FutureProvider.family<
    ShoppingItemPriceIntel?, ShoppingMatchKey>((ref, key) async {
  final points = await loadMatchPoints(ref, name: key.name, barcode: key.barcode);
  if (points.isEmpty) return null;

  final desc = points; // loadMatchPoints trả giảm dần (mới nhất đầu)
  return ShoppingItemPriceIntel(
    points: desc.reversed.toList(),
    bestIn90Days: bestPriceWithinDays(points),
    latestPrice: desc.first.price,
    previousPrice: desc.length > 1 ? desc[1].price : null,
  );
});
