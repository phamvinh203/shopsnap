import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/network/api_exception.dart';
import '../database/daos/budget_dao.dart';
import '../models/budget_model.dart';
import '../services/budget_api_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

const _uuid = Uuid();

/// Service gọi /budgets/* (Wave 4) — tái sử dụng ApiClient chung.
final budgetApiServiceProvider = Provider<BudgetApiService>((ref) {
  return BudgetApiService(ref.watch(apiClientProvider));
});

/// Danh sách ngân sách đang chạy hôm nay — offline-first (Wave 4):
///
/// 1. Luôn đọc sqflite trước (nhanh, dùng được cả khi offline).
/// 2. Đã đăng nhập → GET /budgets/current (server tính sẵn spent/remaining/%),
///    upsert về sqflite (lấy ngày đã căn lại theo kỳ: week T2–CN, month đầu–
///    cuối tháng) rồi emit list: budget server (giá trị server) + budget
///    local-only (chưa từng lên server, tính spent từ items local).
/// 3. API lỗi (mất mạng / 401 expired) → lặng lẽ fallback dữ liệu local.
///
/// Rebuild khi auth đổi trạng thái: login → sync server; logout → local only.
/// Public API giữ nguyên shape cũ (`watch(allBudgetsProvider)` → AsyncValue
/// của List<BudgetStatus>) nên budget_settings/budget_status không phải đổi.
class AllBudgetsNotifier extends AsyncNotifier<List<BudgetStatus>> {
  @override
  Future<List<BudgetStatus>> build() async {
    final api = ref.watch(budgetApiServiceProvider);
    final db  = await ref.watch(databaseProvider.future);
    final dao = BudgetDao(db);

    final local = await dao.getActiveBudgetsWithSpent();

    // authStateProvider đổi → provider này tự rebuild
    final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) return local;

    try {
      final server = await api.current();
      for (final budget in server) {
        await dao.upsertSynced(budget);
      }
      // Budget server là nguồn truth khi online (spent tính theo purchase_date,
      // khác cách tính created_at của local). Custom period không persist được
      // nhưng vẫn hiển thị trong phiên nhờ emit thẳng từ response.
      final serverIds = server.map((b) => b.id).toSet();
      final serverStatuses = server
          .map((b) => BudgetStatus(budget: b, spent: b.spentAmount ?? 0));
      final localOnly =
          local.where((s) => !serverIds.contains(s.budget.id));
      return [...serverStatuses, ...localOnly];
    } catch (_) {
      // Mất mạng / token chết giữa chừng → dùng local, không báo lỗi vỡ UI
      return local;
    }
  }

  /// Thêm ngân sách:
  ///
  /// - Đã đăng nhập → POST /budgets (server căn lại ngày + overlap check),
  ///   upsert response về sqflite. Lỗi nghiệp vụ có response (409 trùng kỳ,
  ///   400 allocated > total...) → ném [ApiException] lên UI hiện snackbar.
  /// - Chưa đăng nhập / NETWORK_ERROR (statusCode null) → insert local như cũ.
  Future<void> addBudget({
    required int          amount,
    required BudgetPeriod period,
    String?               categoryId,
  }) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = BudgetDao(db);

    final now   = DateTime.now();
    final dates = _periodDates(period, now);

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final created = await ref.read(budgetApiServiceProvider).create(BudgetPayload(
          name:        _defaultBudgetName(period, dates.$1),
          periodType:  period.name,
          startDate:   dates.$1,
          endDate:     dates.$2,
          totalAmount: amount,
          // Ngân sách theo 1 danh mục → phân bổ toàn bộ amount cho danh mục đó
          categoryBudgets: categoryId == null
              ? null
              : [CategoryBudgetPayload(categoryId: categoryId, allocatedAmount: amount)],
        ));
        await dao.upsertSynced(created); // ngày đã căn từ server
        ref.invalidateSelf();
        return;
      } on ApiException catch (e) {
        // NETWORK_ERROR (statusCode null) → rơi xuống insert local bên dưới;
        // lỗi server thật (409/422/400) → ném lên để UI xử lý.
        if (e.statusCode != null) rethrow;
      }
    }

    await dao.insert(BudgetModel(
      id:         _uuid.v4(),
      amount:     amount,
      period:     period,
      categoryId: categoryId,
      startDate:  dates.$1,
      endDate:    dates.$2,
      isActive:   true,
      createdAt:  now.millisecondsSinceEpoch,
    ));
    ref.invalidateSelf();
  }

  /// Sửa số tiền (PATCH total_amount khi online; offline → update local).
  /// 404 BUDGET_NOT_FOUND = budget tạo offline chưa từng lên server → vẫn
  /// update local. Server chặn tổng allocated > total mới (400) → ném lên UI.
  Future<void> updateAmount(String id, int newAmount) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = BudgetDao(db);
    final current = _findById(id);
    if (current == null) return;

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final updated = await ref.read(budgetApiServiceProvider).update(
          id,
          totalAmount: newAmount,
        );
        await dao.upsertSynced(updated);
        ref.invalidateSelf();
        return;
      } on ApiException catch (e) {
        if (e.statusCode != null && e.code != 'BUDGET_NOT_FOUND') rethrow;
        // 404 (chưa có trên server) hoặc mất mạng → update local bên dưới
      }
    }

    final b = current.budget;
    await dao.update(BudgetModel(
      id:         b.id,
      amount:     newAmount,
      period:     b.period,
      categoryId: b.categoryId,
      startDate:  b.startDate,
      endDate:    b.endDate,
      isActive:   b.isActive,
      createdAt:  b.createdAt,
    ));
    ref.invalidateSelf();
  }

  /// Tạm dừng / kích hoạt lại (PATCH status khi online; offline → is_active
  /// local). Chưa có UI gọi — sẵn sàng cho tính năng pause sau này.
  Future<void> setStatus(String id, {required bool active}) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = BudgetDao(db);

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        final updated = await ref.read(budgetApiServiceProvider).update(
          id,
          status: active ? 'active' : 'paused',
        );
        await dao.upsertSynced(updated);
        ref.invalidateSelf();
        return;
      } on ApiException catch (e) {
        if (e.statusCode != null && e.code != 'BUDGET_NOT_FOUND') rethrow;
      }
    }

    final current = _findById(id);
    if (current == null) return;
    final b = current.budget;
    await dao.update(BudgetModel(
      id:         b.id,
      amount:     b.amount,
      period:     b.period,
      categoryId: b.categoryId,
      startDate:  b.startDate,
      endDate:    b.endDate,
      isActive:   active,
      createdAt:  b.createdAt,
    ));
    ref.invalidateSelf();
  }

  /// Xoá ngân sách (soft delete trên server):
  /// - Online → DELETE /budgets + xoá local; budget tạo offline (chưa từng lên
  ///   server) server trả 404 → vẫn xoá local cho UX mượt.
  /// - Offline / chưa đăng nhập → xoá local như cũ.
  Future<void> deleteBudget(String id) async {
    final db  = await ref.read(databaseProvider.future);
    final dao = BudgetDao(db);

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (authenticated) {
      try {
        await ref.read(budgetApiServiceProvider).delete(id);
      } on ApiException catch (e) {
        if (e.statusCode != null && e.code != 'BUDGET_NOT_FOUND') rethrow;
        // 404 = chưa có trên server / đã xoá — vẫn xoá local
      }
    }

    await dao.delete(id);
    ref.invalidateSelf();
  }

  /// Tìm budget trong state hiện tại (không ném nếu chưa load / không có).
  BudgetStatus? _findById(String id) {
    for (final s in state.valueOrNull ?? const <BudgetStatus>[]) {
      if (s.budget.id == id) return s;
    }
    return null;
  }

  /// Tên mặc định cho budget tạo từ app (form không hỏi tên).
  static String _defaultBudgetName(BudgetPeriod period, String startDate) {
    // '2026-09-07' → ['2026', '09', '07']
    final p = startDate.split('-');
    final label = switch (period) {
      BudgetPeriod.day   => 'ngày ${p.length > 2 ? '${p[2]}/${p[1]}' : startDate}',
      BudgetPeriod.week  => 'tuần ${p.length > 2 ? '${p[2]}/${p[1]}' : startDate}',
      BudgetPeriod.month => 'tháng ${p.length > 1 ? p[1] : ''}/${p.isNotEmpty ? p[0] : ''}',
      BudgetPeriod.custom => 'tùy chỉnh $startDate',
    };
    return 'Ngân sách $label';
  }

  static (String, String) _periodDates(BudgetPeriod period, DateTime now) {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (period) {
      case BudgetPeriod.day:
        return (fmt(now), fmt(now));
      case BudgetPeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return (fmt(monday), fmt(sunday));
      case BudgetPeriod.month:
        final start = DateTime(now.year, now.month, 1);
        final end   = DateTime(now.year, now.month + 1, 0);
        return (fmt(start), fmt(end));
      case BudgetPeriod.custom:
        // Không tạo custom từ app — coi như ngân sách hôm nay để switch đủ casos
        return (fmt(now), fmt(now));
    }
  }
}

final allBudgetsProvider =
    AsyncNotifierProvider<AllBudgetsNotifier, List<BudgetStatus>>(
  AllBudgetsNotifier.new,
);
