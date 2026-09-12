import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../database/daos/item_dao.dart';
import '../models/item_model.dart';
import '../services/item_api_service.dart';
import 'auth_provider.dart';
import 'all_budgets_provider.dart';
import 'budget_provider.dart';
import 'categories_provider.dart';
import 'database_provider.dart';

// Selected date for viewing (default = today)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Service gọi /items/* (Wave 3) — tái sử dụng ApiClient chung.
final itemApiServiceProvider = Provider<ItemApiService>((ref) {
  return ItemApiService(ref.watch(apiClientProvider));
});

/// Items trong ngày đang chọn — offline-first (Wave 3):
///
/// 1. Luôn đọc sqflite trước (nhanh, dùng được cả khi offline).
/// 2. Đã đăng nhập → GET /items lọc theo purchase_date của ngày đang chọn,
///    upsert về sqflite (sync một chiều server → local) rồi emit lại list từ
///    DAO — offline DB vẫn là nguồn truth cho UI.
/// 3. API lỗi (mất mạng / 401 expired) → lặng lẽ fallback dữ liệu local.
///
/// Rebuild khi auth đổi trạng thái hoặc [selectedDateProvider] đổi ngày.
/// Public API giữ nguyên shape cũ (`watch(itemsProvider)` → AsyncValue của
/// List<ItemModel>) nên home/item card/summary không phải đổi.
class ItemsNotifier extends AsyncNotifier<List<ItemModel>> {
  @override
  Future<List<ItemModel>> build() async {
    final api  = ref.watch(itemApiServiceProvider);
    final db   = await ref.watch(databaseProvider.future);
    final dao  = ItemDao(db);
    final date = ref.watch(selectedDateProvider);

    final local = await dao.findByDay(date);

    // authStateProvider đổi → provider này tự rebuild
    final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) return local;

    try {
      // Đợi categories sync xong trước: item server có thể thuộc category chưa
      // có trong sqflite → FK(category_id) fail. categoriesProvider tự fallback
      // local khi lỗi nên future này luôn hoàn tất (không chết chờ).
      await ref.watch(categoriesProvider.future);

      // Lọc theo purchase_date đúng khoảng [dayStart, dayEnd] như findByDay.
      final start = DateTime(date.year, date.month, date.day);
      final end   = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      // 1 trang tối đa 100 item (limit max của backend) — lặp page tiếp nếu còn.
      var page = await api.fetchItems(
        dateFrom: start,
        dateTo:   end,
        sort:     'purchase_date',
        order:    'desc',
        limit:    100,
      );
      var all = page.items;
      while (page.meta.hasNext && page.meta.page < 10) {
        page = await api.fetchItems(
          page:     page.meta.page + 1,
          dateFrom: start,
          dateTo:   end,
          sort:     'purchase_date',
          order:    'desc',
          limit:    100,
        );
        all = [...all, ...page.items];
      }

      for (final item in all) {
        await dao.upsertSynced(item);
      }
      return await dao.findByDay(date); // merged: server + local-only của ngày này
    } catch (_) {
      // Mất mạng / token chết giữa chừng → dùng local, không báo lỗi vỡ UI
      return local;
    }
  }

  /// Thêm item:
  ///
  /// - Đã đăng nhập + có response server → POST /items (server trả canonical
  ///   id + auto-classified category khi [CreateItemDto.categoryId] bỏ trống),
  ///   upsert về sqflite. Ảnh file local không gửi lên server (image_url là
  ///   URL) — giữ lại ở row local qua upsertSynced.
  /// - Lỗi nghiệp vụ có response (409/404/400...) → ném [ApiException] lên UI
  ///   (add_item hiện dialog "Ghi lại lần nữa" với 409 ITEM_DUPLICATE).
  /// - Chưa đăng nhập / NETWORK_ERROR (statusCode null) → insert local như cũ.
  Future<void> addItem(CreateItemDto dto, {bool force = false, String? source}) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = ItemDao(db);

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final created = await ref.read(itemApiServiceProvider).create(ItemPayload(
          name:       dto.name,
          price:      dto.price,
          categoryId: dto.categoryId,
          note:       dto.note,
          barcode:    dto.barcode,
          source:     source,
          location: (dto.latitude != null && dto.longitude != null)
              ? ItemLocation(latitude: dto.latitude!, longitude: dto.longitude!)
              : null,
        ), force: force);
        await dao.upsertSynced(created.copyWith(imagePath: dto.imagePath));
        ref.invalidateSelf();
        // Spent của budget đổi theo item mới → làm mới danh sách budget
        ref.invalidate(allBudgetsProvider);
        await ref.read(budgetStatusProvider.notifier).checkAndAlert();
        return;
      } on ApiException catch (e) {
        // NETWORK_ERROR (statusCode null) → rơi xuống insert local bên dưới;
        // lỗi server thật (409/404/400) → ném lên để UI xử lý.
        if (e.statusCode != null) rethrow;
      }
    }

    await dao.insert(dto);
    ref.invalidateSelf();
    ref.invalidate(allBudgetsProvider);
    // Check budget after adding
    await ref.read(budgetStatusProvider.notifier).checkAndAlert();
  }

  /// Sửa item (PATCH khi online; offline → update local + enqueue sync).
  /// 404 ITEM_NOT_FOUND = item tạo offline chưa từng lên server → vẫn update local.
  Future<void> updateItem(
    String id, {
    String? name,
    int? price,
    String? categoryId,
    String? note,
    String? barcode,
  }) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = ItemDao(db);

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final updated = await ref.read(itemApiServiceProvider).update(
          id,
          name: name, price: price, categoryId: categoryId, note: note, barcode: barcode,
        );
        await dao.upsertSynced(updated);
        ref.invalidateSelf();
        ref.invalidate(allBudgetsProvider); // giá item đổi → spent đổi
        return;
      } on ApiException catch (e) {
        if (e.statusCode != null && e.code != 'ITEM_NOT_FOUND') rethrow;
        // 404 (chưa có trên server) hoặc mất mạng → update local bên dưới
      }
    }

    await dao.updateLocal(id,
        name: name, price: price, categoryId: categoryId, note: note, barcode: barcode);
    ref.invalidateSelf();
    ref.invalidate(allBudgetsProvider); // giá item đổi → spent đổi
  }

  /// Xoá item (soft delete):
  /// - Online → DELETE /items + mark local; item tạo offline (id local, chưa
  ///   từng lên server) server trả 404 → vẫn soft delete local.
  /// - Offline / chưa đăng nhập → soft delete local như cũ.
  Future<void> deleteItem(String id) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = ItemDao(db);

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        await ref.read(itemApiServiceProvider).delete(id);
      } on ApiException catch (e) {
        if (e.statusCode != null && e.code != 'ITEM_NOT_FOUND') rethrow;
        // 404 = chưa có trên server / đã xoá — vẫn xoá local cho UX mượt
      }
    }

    await dao.softDelete(id);
    ref.invalidateSelf();
    ref.invalidate(allBudgetsProvider); // xoá item → spent giảm
  }
}

final itemsProvider = AsyncNotifierProvider<ItemsNotifier, List<ItemModel>>(ItemsNotifier.new);
