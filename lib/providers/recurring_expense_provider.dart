import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/recurring_schedule.dart';
import '../core/utils/recurring_suggest.dart';
import '../database/daos/item_dao.dart';
import '../database/daos/recurring_expense_dao.dart';
import '../models/item_model.dart';
import '../models/recurring_expense_model.dart';
import '../services/notification_service.dart';
import '../services/recurring_expense_service.dart';
import 'database_provider.dart';

// ── DAO / Service ────────────────────────────────────────────────────────────

final recurringExpenseDaoProvider = FutureProvider<RecurringExpenseDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return RecurringExpenseDao(db);
});

/// Wire scheduler tới plugin thật. Lỗi plugin (thiếu quyền / thiết bị không
/// hỗ trợ) được NUỐT ở đây để thao tác lưu KHÔNG bao giờ vỡ vì notification
/// (AC 4.14 — fail-open như pattern `canDeliver` của F-#12).
final recurringReminderSchedulerProvider = Provider<RecurringReminderScheduler>((ref) {
  return RecurringReminderScheduler(
    schedule: (id, when) async {
      try {
        await NotificationService.scheduleRecurringReminder(
            notificationId: id, when: when);
      } catch (_) {}
    },
    cancel: (id) async {
      try {
        await NotificationService.cancelNotification(id);
      } catch (_) {}
    },
  );
});

final recurringExpenseServiceProvider =
    FutureProvider<RecurringExpenseService>((ref) async {
  final dao = await ref.watch(recurringExpenseDaoProvider.future);
  return RecurringExpenseService(
    dao: dao,
    scheduler: ref.watch(recurringReminderSchedulerProvider),
  );
});

// ── Danh sách khoản định kỳ (offline hoàn toàn — AC 4.7) ─────────────────────

/// Notifier danh sách khoản định kỳ — MỌI thao tác chỉ chạm SQLite; sau mỗi
/// thay đổi trạng thái bật, nhắc được re-arm/hủy đúng (AC 4.5/4.6/4.11).
class RecurringExpensesNotifier extends AsyncNotifier<List<RecurringExpense>> {
  @override
  Future<List<RecurringExpense>> build() async {
    final dao = await ref.watch(recurringExpenseDaoProvider.future);
    return dao.getAll();
  }

  Future<RecurringExpenseService> _service() =>
      ref.read(recurringExpenseServiceProvider.future);

  /// Thêm mới (AC 4.3). Trả entry vừa tạo, `null` khi vi phạm validation
  /// (UI đã chặn inline; DAO chặn lần nữa).
  Future<RecurringExpense?> add(CreateRecurringExpenseDto dto) async {
    final created = await (await _service()).create(dto);
    ref.invalidateSelf();
    ref.invalidate(recurringSuggestionsProvider); // match_key mới → lọc gợi ý
    return created;
  }

  /// Sửa (AC 4.4) — trả entry cập nhật, `null` khi id không còn tồn tại.
  /// (Tên `updateEntry` để không đụng `AsyncNotifier.update` của Riverpod.)
  Future<RecurringExpense?> updateEntry(
    String id, {
    String? name,
    int? amount,
    int? dueDay,
    int? remindDaysBefore,
  }) async {
    final updated = await (await _service()).update(
      id,
      name: name,
      amount: amount,
      dueDay: dueDay,
      remindDaysBefore: remindDaysBefore,
    );
    ref.invalidateSelf();
    ref.invalidate(recurringSuggestionsProvider);
    return updated;
  }

  /// Tắt/bật (AC 4.5/4.6).
  Future<void> setActive(String id, bool active) async {
    await (await _service()).setActive(id, active);
    ref.invalidateSelf();
    ref.invalidate(recurringSuggestionsProvider);
  }

  /// AC 4.11(b)/4.12 — mở màn → re-arm: hủy schedule cũ, đặt đúng 1 pending
  /// cho chu kỳ kế tiếp của mỗi entry đang bật.
  Future<void> rearmReminders() async {
    await (await _service()).rearmAll();
  }
}

final recurringExpensesProvider =
    AsyncNotifierProvider<RecurringExpensesNotifier, List<RecurringExpense>>(
  RecurringExpensesNotifier.new,
);

// ── Gợi ý "có vẻ là khoản định kỳ" (AC 4.8–4.10) ─────────────────────────────

/// Quét items local [AppConstants.recurringScanDays] ngày qua (chỉ khi user
/// vào `/recurring` — không quét mỗi lần mở Home, AC 4.10), loại nhóm trùng
/// match_key với entry đang bật, trả gợi ý cho card.
final recurringSuggestionsProvider =
    FutureProvider<List<RecurringSuggestion>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final dao = await ref.watch(recurringExpenseDaoProvider.future);

  final items = await ItemDao(db)
      .findRecent(days: AppConstants.recurringScanDays);
  final activeKeys = await dao.activeMatchKeys();

  return detectRecurringSuggestions(
    entries: items.map(_entryFromItem).toList(),
    activeMatchKeys: activeKeys,
  );
});

RecurringScanEntry _entryFromItem(ItemModel item) => RecurringScanEntry(
      name: item.name,
      price: item.price,
      purchasedAt: DateTime.fromMillisecondsSinceEpoch(item.createdAt),
    );

/// Ngày đến hạn prefill khi convert gợi ý (AC 4.10): ngày của lần mua gần
/// nhất, chặn vào miền hợp lệ 1..28 (mua ngày 29–31 → 28; due_day CHECK).
int prefillDueDayFrom(DateTime purchasedAt) =>
    purchasedAt.day.clamp(
        AppConstants.recurringDueDayMin, AppConstants.recurringDueDayMax);

/// Nhắc id dùng chung schedule/cancel — expose cho UI/qa cần hủy thủ công.
int notificationIdFor(String entryId) => recurringNotificationId(entryId);
