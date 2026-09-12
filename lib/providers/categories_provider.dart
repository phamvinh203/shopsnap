import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/network/api_exception.dart';
import '../database/daos/category_dao.dart';
import '../models/category_model.dart';
import '../services/category_api_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Service gọi /categories/* (Wave 2) — tái sử dụng ApiClient chung.
final categoryApiServiceProvider = Provider<CategoryApiService>((ref) {
  return CategoryApiService(ref.watch(apiClientProvider));
});

/// Danh mục — offline-first:
///
/// 1. Luôn đọc sqflite trước (nhanh, dùng được cả khi offline).
/// 2. Đã đăng nhập → lấy từ API, upsert về sqflite rồi emit lại danh sách
///    merged (server ∪ local-only) từ DAO — offline DB vẫn là nguồn truth,
///    các screen offline + category selector không bị vỡ.
/// 3. API lỗi (mất mạng / 401 expired) → lặng lẽ fallback dữ liệu local.
///
/// Rebuild khi auth đổi trạng thái: login → sync server; logout → local only.
/// Public API giữ nguyên shape cũ (`watch(categoriesProvider)` → AsyncValue
/// của List<CategoryModel>) nên home/add_item/budget_settings không phải đổi.
class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() async {
    final api = ref.watch(categoryApiServiceProvider);
    final db  = await ref.watch(databaseProvider.future);
    final dao = CategoryDao(db);

    final local = await dao.findAll();

    // authStateProvider đổi → provider này tự rebuild
    final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) return local;

    try {
      final remote = await api.fetchCategories();
      await dao.upsertAll(remote);
      return await dao.findAll(); // merged: server categories + local-only
    } catch (_) {
      // Mất mạng / token chết giữa chừng → dùng local, không báo lỗi vỡ UI
      return local;
    }
  }

  /// Tạo category custom (quick-create trong add_item).
  ///
  /// - Đã đăng nhập → POST /categories; lỗi nghiệp vụ (vd. 409 trùng tên)
  ///   ném lên để UI hiện message; MẤT MẠNG → tạo local bên dưới.
  /// - Chưa đăng nhập / mất mạng → tạo local-only với id prefix `local_`
  ///   (phân biệt với id server để sync sau này), UI không bị chặn.
  ///
  /// Trả về model vừa tạo — caller nên chọn luôn category này.
  Future<CategoryModel> createCategory({
    required String name,
    required String color,
    required String icon,
  }) async {
    final trimmed = name.trim();
    final db  = await ref.read(databaseProvider.future);
    final dao = CategoryDao(db);

    CategoryModel? created;

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        created = await ref
            .read(categoryApiServiceProvider)
            .createCategory(name: trimmed, color: color, icon: icon);
      } on ApiException catch (e) {
        // Lỗi nghiệp vụ có response từ server (409/422/...) → ném lên UI.
        // NETWORK_ERROR (statusCode null) → rơi xuống tạo local bên dưới.
        if (e.statusCode != null) rethrow;
      }
    }

    if (created == null) {
      final all   = await dao.findAll();
      final lower = trimmed.toLowerCase();
      if (all.any((c) => c.name.toLowerCase() == lower)) {
        throw const ApiException(
          code: 'CATEGORY_DUPLICATE_NAME',
          message: 'Tên danh mục đã tồn tại.',
          statusCode: 409,
        );
      }
      final maxOrder = all.fold<int>(0, (m, c) => c.sortOrder > m ? c.sortOrder : m);
      created = CategoryModel(
        id:        'local_${const Uuid().v4()}',
        name:      trimmed,
        icon:      icon,
        color:     color,
        isDefault: false,
        sortOrder: maxOrder + 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final cat = created;
    await dao.insert(cat);
    // Append thẳng vào state (không refetch) → chip mới dùng được ngay, không nhấp nháy
    state = state.whenData((cats) => [...cats, cat]);
    return cat;
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(CategoriesNotifier.new);
