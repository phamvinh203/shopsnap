import '../core/constants/app_constants.dart';
import '../core/utils/recurring_schedule.dart';
import '../database/daos/recurring_expense_dao.dart';
import '../models/recurring_expense_model.dart';

/// Abstraction mỏng quanh NotificationService để test được hành vi
/// schedule/cancel mà không cần plugin (provider dưới wire tới plugin thật).
class RecurringReminderScheduler {
  final Future<void> Function(int notificationId, DateTime when) schedule;
  final Future<void> Function(int notificationId) cancel;

  const RecurringReminderScheduler({
    required this.schedule,
    required this.cancel,
  });
}

/// Điều phối CRUD khoản định kỳ + nhắc trước hạn (AC 4.11–4.12).
///
/// Nguyên tắc:
/// - Mọi ghi chỉ chạm SQLite (AC 4.7 offline) — KHÔNG sync queue (AC 4.15).
/// - Mỗi thao tác làm đổi trạng thái bật của entry đều **cancel schedule cũ
///   trước** rồi **schedule lại đúng 1 pending** với id deterministic từ
///   `entry.id` (AC 4.11) → không bao giờ nhân bản notification.
/// - Tắt (AC 4.5): hủy pending NGAY; bật lại (AC 4.6): re-arm chu kỳ kế tiếp
///   (mốc chu kỳ hiện tại đã qua → tự nhảy sang tháng sau, không nhắc bù).
/// - Mọi lỗi notification được nuốt ở tầng caller (provider) — thiếu quyền
///   hay plugin chưa sẵn sàng KHÔNG được làm vỡ thao tác lưu (AC 4.14).
class RecurringExpenseService {
  final RecurringExpenseDao dao;
  final RecurringReminderScheduler scheduler;

  /// Inject được để test ranh giới ngày/chu kỳ.
  final DateTime Function() now;

  RecurringExpenseService({
    required this.dao,
    required this.scheduler,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  Future<RecurringExpense?> create(CreateRecurringExpenseDto dto) async {
    final created = await dao.insert(dto);
    if (created == null) return null;
    if (created.isActive) await _arm(created);
    return created;
  }

  /// Sửa (AC 4.4): id + lịch sử giữ nguyên, chỉ updated_at đổi; đang bật →
  /// reschedule theo tham số mới.
  Future<RecurringExpense?> update(
    String id, {
    String? name,
    int? amount,
    int? dueDay,
    int? remindDaysBefore,
  }) async {
    await dao.updateFields(
      id,
      name: name,
      amount: amount,
      dueDay: dueDay,
      remindDaysBefore: remindDaysBefore,
    );
    final updated = await dao.findById(id);
    if (updated == null) return null;
    if (updated.isActive) await _arm(updated);
    return updated;
  }

  /// Tắt/bật (AC 4.5/4.6). Trả về trạng thái `isActive` mới.
  Future<bool> setActive(String id, bool active) async {
    final newState = await dao.setActive(id, active);
    final entry = await dao.findById(id);
    if (entry == null) return newState;
    if (entry.isActive) {
      await _arm(entry);
    } else {
      // AC 4.5: tắt → pending reminder của entry bị HỦY NGAY.
      await scheduler.cancel(recurringNotificationId(entry.id));
    }
    return newState;
  }

  /// AC 4.11(b)/4.12 — re-arm khi app mở lên: với MỖI entry đang bật, hủy
  /// schedule cũ rồi đặt đúng 1 pending cho chu kỳ KẾ TIẾP. Chu kỳ đã fire
  /// trước đó có mốc trong quá khứ → `computeNextReminder` trả chu kỳ sau →
  /// không nhắc bù, không nhân bản.
  Future<void> rearmAll() async {
    for (final entry in await dao.getActive()) {
      await _arm(entry);
    }
  }

  Future<void> _arm(RecurringExpense entry) async {
    final id = recurringNotificationId(entry.id);
    await scheduler.cancel(id); // HỦY schedule cũ TRƯỚC KHI đặt mới (AC 4.11)
    final target = computeNextReminder(
      dueDay: entry.dueDay,
      remindDaysBefore: entry.remindDaysBefore,
      now: now(),
    );
    if (target == null) return; // dữ liệu lệch chuẩn → không schedule rác
    await scheduler.schedule(id, target.scheduledAt);
    await dao.setLastReminderCycle(entry.id, target.cycleKey);
  }

  /// Ngưỡng quét gợi ý — để UI/provider dùng chung nguồn duy nhất.
  static int get scanDays => AppConstants.recurringScanDays;
}
