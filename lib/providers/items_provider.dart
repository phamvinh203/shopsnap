import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/network/api_exception.dart';
import '../database/daos/item_dao.dart';
import '../models/item_model.dart';
import '../services/item_api_service.dart';
import 'auth_provider.dart';
import 'all_budgets_provider.dart';
import 'budget_provider.dart';
import 'categories_provider.dart';
import 'database_provider.dart';
import 'shopping_list_provider.dart';

// Selected date for viewing (default = today)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Service gọi /items/* (Wave 3) — tái sử dụng ApiClient chung.
final itemApiServiceProvider = Provider<ItemApiService>((ref) {
  return ItemApiService(ref.watch(apiClientProvider));
});

/// M-3 (AC 7.4/7.14): gợi ý "Nơi mua" xếp theo TẦN SUẤT giảm dần — thuần
/// SQLite local qua `ItemDao.getStoreSuggestions` (nguyên văn user đã dùng,
/// tối đa `AppConstants.storeSuggestionLimit`, bỏ item đã xoá mềm), không gọi
/// API → dùng được offline. DB hỏng/lỗi → rỗng (không chips), không vỡ UI.
final storeSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    return await ItemDao(db).getStoreSuggestions();
  } catch (_) {
    return const [];
  }
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

    // F-#12 (AC 12.1): chụp tổng chi TRƯỚC khi lưu làm mốc so sánh ngưỡng.
    final spentBefore = await _captureSpentBeforeChange();

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final created = await ref.read(itemApiServiceProvider).create(ItemPayload(
          name:       dto.name,
          price:      dto.price,
          categoryId: dto.categoryId,
          note:       dto.note,
          barcode:    dto.barcode,
          storeName:  sanitizeStoreName(dto.storeName), // M-3 AC 7.3
          source:     source,
          location: (dto.latitude != null && dto.longitude != null)
              ? ItemLocation(latitude: dto.latitude!, longitude: dto.longitude!)
              : null,
        ), force: force);
        await dao.upsertSynced(created.copyWith(imagePath: dto.imagePath));
        ref.invalidateSelf();
        ref.invalidate(storeSuggestionsProvider); // tần suất nơi mua đổi
        // Spent của budget đổi theo item mới → làm mới danh sách budget
        ref.invalidate(allBudgetsProvider);
        await ref.read(budgetStatusProvider.notifier).checkAndAlert(spentBefore: spentBefore);
        // F-#6: item vừa TẠO (record mới nhất trong price history bị loại
        // khỏi baseline khi check — AC 6.13).
        unawaited(_runPriceWatchCheck(
          name: dto.name,
          barcode: dto.barcode,
          price: dto.price,
          excludeLatestRecord: true,
        ));
        return;
      } on ApiException catch (e) {
        // NETWORK_ERROR (statusCode null) → rơi xuống insert local bên dưới;
        // lỗi server thật (409/404/400) → ném lên để UI xử lý.
        if (e.statusCode != null) rethrow;
      }
    }

    await dao.insert(dto);
    ref.invalidateSelf();
    ref.invalidate(storeSuggestionsProvider); // tần suất nơi mua đổi
    ref.invalidate(allBudgetsProvider);
    // Check budget after adding
    await ref.read(budgetStatusProvider.notifier).checkAndAlert(spentBefore: spentBefore);
    // F-#6: watch check sau khi thêm offline (record vừa ghi bị loại khỏi
    // baseline — xem _runPriceWatchCheck).
    unawaited(_runPriceWatchCheck(
      name: dto.name,
      barcode: dto.barcode,
      price: dto.price,
      excludeLatestRecord: true,
    ));
  }

  /// F-#5 P1 (AC 5.6/5.7): tạo HÀNG LOẠT qua POST /items/bulk (source 'ocr'
  /// nằm trong từng [ItemPayload] — caller gán) cho flow confirm hóa đơn.
  ///
  /// - Trả [BulkCreateResult] { created, failed } — partial failure có sẵn,
  ///   UI tự hiện từng dòng fail kèm lý do và cho thử lại CHỈ các dòng đó.
  /// - Item tạo thành công được upsert về sqflite (best-effort — server là
  ///   nguồn truth, mất local cache không làm vỡ flow) + invalidate providers.
  /// - Lỗi (mất mạng / 429 / validation) → ném [ApiException] lên UI giữ nguyên
  ///   trạng thái màn confirm để thử lại (AC 5.9/5.10).
  ///
  /// - Watch check (AC 5.13a/5.14): sau khi bulk trả ≥ 1 item thành công,
  ///   chạy ĐÚNG 1 LẦN cho toàn batch (`PriceWatchService.checkAfterBulkSaved`
  ///   — tối đa 1 notification/batch). Budget check KHÔNG gọi thêm: BE
  ///   `bulkCreate` tự chạy 1 lần sau cả batch (server-side, AC 5.13b).
  /// - Lỗi (mất mạng / 429 / validation) → ném [ApiException] lên UI giữ nguyên
  ///   trạng thái màn confirm để thử lại (AC 5.9/5.10).
  Future<BulkCreateResult> bulkAdd(
    List<ItemPayload> items, {
    String? storeName,
  }) async {
    final result = await ref
        .read(itemApiServiceProvider)
        .bulkCreate(items, storeName: storeName);

    try {
      final db  = await ref.read(databaseProvider.future);
      final dao = ItemDao(db);
      for (final item in result.created) {
        await dao.upsertSynced(item);
      }
    } catch (_) {
      // Upsert cache local lỗi → bỏ qua (server đã lưu, sync sau sẽ kéo về).
    }

    // F-#5 P1 (AC 5.13a/5.14): watch check 1 lần/batch sau khi có ≥ 1 item
    // tạo thành công. Record vừa ghi đã lên history → loại khỏi baseline.
    // Fire-and-forget, lỗi được nuốt bên trong service — không chặn confirm.
    if (result.created.isNotEmpty) {
      final created = result.created
          .map((i) => (name: i.name, barcode: i.barcode, price: i.price))
          .toList();
      unawaited(ref
          .read(priceWatchServiceProvider)
          .checkAfterBulkSaved(items: created, excludeLatestRecord: true));
    }

    ref.invalidateSelf();
    ref.invalidate(allBudgetsProvider);
    return result;
  }

  /// Sửa item (PATCH khi online; offline → update local + enqueue sync).
  /// 404 ITEM_NOT_FOUND = item tạo offline chưa từng lên server → vẫn update local.
  ///
  /// [storeName] M-3 (AC 7.6): `null` = không đổi nơi mua; `''` = user xoá
  /// trắng → local về NULL, server nhận `store_name: ''` (BE @IsString hợp lệ).
  Future<void> updateItem(
    String id, {
    String? name,
    int? price,
    String? categoryId,
    String? note,
    String? barcode,
    String? storeName,
  }) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = ItemDao(db);

    // F-#12 (AC 12.1): sửa item cũng có thể đẩy tổng chi qua ngưỡng → chụp
    // mốc TRƯỚC khi lưu (cả 2 nhánh online/offline đều check sau khi lưu).
    final spentBefore = await _captureSpentBeforeChange();

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final updated = await ref.read(itemApiServiceProvider).update(
          id,
          name: name, price: price, categoryId: categoryId, note: note, barcode: barcode,
          // AC 7.6: xoá trắng → gửi '' (BE @IsString hợp lệ, set rỗng phía
          // server) — KHÔNG sanitize về null vì null sẽ bị omit khỏi PATCH body.
          storeName: storeName == null
              ? null
              : (storeName.trim().isEmpty ? '' : storeName.trim()),
        );
        await dao.upsertSynced(updated);
        ref.invalidateSelf();
        ref.invalidate(storeSuggestionsProvider);
        ref.invalidate(allBudgetsProvider); // giá item đổi → spent đổi
        // F-#12: giá mới có thể đẩy tổng chi qua ngưỡng (AC 12.1).
        await ref.read(budgetStatusProvider.notifier).checkAndAlert(spentBefore: spentBefore);
        // F-#6: watch check sau khi SỬA item (history chưa có record mới →
        // không loại record nào khỏi baseline).
        unawaited(_runPriceWatchCheck(
          name: updated.name,
          barcode: updated.barcode,
          price: updated.price,
          excludeLatestRecord: false,
        ));
        return;
      } on ApiException catch (e) {
        if (e.statusCode != null && e.code != 'ITEM_NOT_FOUND') rethrow;
        // 404 (chưa có trên server) hoặc mất mạng → update local bên dưới
      }
    }

    await dao.updateLocal(id,
        name: name, price: price, categoryId: categoryId, note: note, barcode: barcode,
        storeName: storeName);
    ref.invalidateSelf();
    ref.invalidate(storeSuggestionsProvider);
    ref.invalidate(allBudgetsProvider); // giá item đổi → spent đổi
    // F-#12: giá mới có thể đẩy tổng chi qua ngưỡng (AC 12.1).
    await ref.read(budgetStatusProvider.notifier).checkAndAlert(spentBefore: spentBefore);
    // F-#6: watch check sau khi sửa offline — đọc lại snapshot item vừa cập
    // nhật để có name/price/barcode đầy đủ (params có thể null = giữ nguyên).
    final snap = await _queryItemSnapshot(await ref.read(databaseProvider.future), id);
    if (snap.$1.isNotEmpty) {
      unawaited(_runPriceWatchCheck(
        name: snap.$1,
        barcode: snap.$2,
        price: snap.$3,
        excludeLatestRecord: false,
      ));
    }
  }

  /// F-#12 (AC 12.1): đọc tổng chi hiện tại của budget tổng làm mốc so sánh
  /// ngưỡng trước khi item được lưu. Lỗi (DB hỏng…) → null → checkAndAlert
  /// bỏ qua lần này thay vì bắn alert sai.
  Future<int?> _captureSpentBeforeChange() async {
    try {
      return (await ref.read(budgetStatusProvider.future))?.spent;
    } catch (_) {
      return null;
    }
  }

  /// F-#6 Price Watch: check LOCAL chạy ngay sau khi thêm/sửa item thành công
  /// (spec: event-driven, không timer). Lỗi watch (DB/notification) phải không
  /// bao giờ làm vỡ flow thêm/sửa item.
  Future<void> _runPriceWatchCheck({
    required String name,
    String? barcode,
    required int price,
    required bool excludeLatestRecord,
  }) async {
    try {
      await ref.read(priceWatchServiceProvider).checkAfterItemSaved(
            name: name,
            barcode: barcode,
            price: price,
            excludeLatestRecord: excludeLatestRecord,
          );
    } catch (_) {}
  }

  Future<(String, String?, int)> _queryItemSnapshot(Database db, String id) async {
    try {
      final rows = await db.query(
        'items',
        columns: ['name', 'barcode', 'price'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return ('', null, 0);
      final r = rows.first;
      return (
        r['name'] as String? ?? '',
        r['barcode'] as String?,
        (r['price'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return ('', null, 0);
    }
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
    ref.invalidate(storeSuggestionsProvider); // item xoá mềm hết đóng góp tần suất
    ref.invalidate(allBudgetsProvider); // xoá item → spent giảm
  }
}

final itemsProvider = AsyncNotifierProvider<ItemsNotifier, List<ItemModel>>(ItemsNotifier.new);
