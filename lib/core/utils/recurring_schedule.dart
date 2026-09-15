/// M-2 — Lịch nhắc trước ngày đến hạn: logic thuần KHÔNG phụ thuộc
/// Flutter/Riverpod/DB (unit test độc lập, cùng phong cách `price_watch.dart`).
///
/// Phủ các AC:
/// - AC 4.11: entry bật → đặt ĐÚNG 1 zonedSchedule tại ngày
///   (due_day − remind_days_before) của chu kỳ KẾ TIẾP, lúc 09:00 giờ local
///   [ASSUMPTION giờ nhắc — AppConstants.recurringReminderHour]. Chu kỳ hiện
///   tại đã qua mốc nhắc → chuỗi nhắc bắt đầu từ chu kỳ tháng sau (AC 4.6,
///   không nhắc bù).
/// - AC 4.12 (dedup theo chu kỳ): mỗi entry xác định bởi 1 notification id
///   deterministic từ `entry.id` — cancel + re-arm luôn cho TỐI ĐA 1 pending
///   schedule, không nhân bản, không nhắc bù chu kỳ cũ (pattern AC 6.15).
/// - AC 4.13 (security lockscreen — AC 12.4 áp dụng nguyên văn): title/body
///   là HẰNG generic định nghĩa MỘT NƠI tại đây — KHÔNG số tiền, KHÔNG tên
///   khoản. `NotificationService.scheduleRecurringReminder` CỐ Ý không nhận
///   tham số dữ liệu nhạy cảm (khóa ở tầng chữ hàm, như showBudgetWarning).
library;

import '../constants/app_constants.dart';
import 'budget_alert.dart' show recurringAlertRoute;

/// Title notification recurring — cố định theo AC 4.13.
const String recurringReminderTitle = 'Khoản định kỳ sắp đến hạn';

/// Body generic — KHÔNG tên khoản, KHÔNG số tiền (AC 4.13: chỉ title + body
/// generic trên lockscreen; chi tiết trong app khi user bấm mở).
const String recurringReminderBody =
    'Một khoản chi định kỳ của bạn sắp đến hạn. Mở ứng dụng để xem chi tiết.';

/// Payload deep-link (AC 4.13): bấm notification → mở `/recurring`.
const String recurringAlertPayload = '{"route":"$recurringAlertRoute"}';

/// Notification id DETERMINISTIC từ entry id — dùng chung để cancel khi sửa/
/// tắt/re-arm (AC 4.11: tại mọi thời điểm mỗi entry tối đa 1 pending).
/// Plugin cần id int 32-bit không âm → hash &gt;= 0 bằng mặt nạ bit.
int recurringNotificationId(String entryId) =>
    entryId.hashCode & 0x7fffffff;

/// Đích nhắc của MỘT chu kỳ: mốc giờ sẽ bấm notification + chu kỳ được nhắc.
class RecurringReminderTarget {
  /// Thời điểm bấm notification — "09:00 giờ local" của ngày
  /// (due_day − remind_days_before) tính bằng DateTime local của thiết bị.
  final DateTime scheduledAt;

  /// 'yyyy-MM' của tháng ĐẾN HẠN (chu kỳ K được nhắc) — lưu vào
  /// `last_reminder_cycle` để dedup (AC 4.12). Lưu ý mốc nhắc có thể rơi
  /// vào tháng trước khi due_day nhỏ (vd hạn ngày 1, nhắc trước 3 ngày).
  final String cycleKey;

  const RecurringReminderTarget({
    required this.scheduledAt,
    required this.cycleKey,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringReminderTarget &&
          runtimeType == other.runtimeType &&
          scheduledAt == other.scheduledAt &&
          cycleKey == other.cycleKey;

  @override
  int get hashCode => Object.hash(scheduledAt, cycleKey);
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatCycleKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}';

/// Mốc nhắc KẾ TIẾP cho một khoản định kỳ, nhìn từ thời điểm [now].
///
/// - Do ngày nhắc = ngày đến hạn lùi [remindDaysBefore] ngày (mốc 09:00),
///   phép lùi tự tràn đúng qua tháng trước khi due_day nhỏ (hạn ngày 1,
///   nhắc trước 3 → 26–28 tháng trước). Cách này khớp trực diện định nghĩa
///   "nhắc trước N ngày" thay vì cấm đoán tổ hợp due_day × remind.
/// - Mốc nhắc của chu kỳ này đã qua (`!isAfter(now)`) → trả chu kỳ tháng sau
///   (AC 4.6 — không nhắc bù).
/// - Trả `null` khi tham số ngoài miền hợp lệ (due_day 1..28, remind 0..3) —
///   tầng UI/DAO đã chặn, đây là phòng thủ cuối để không bao giờ schedule rác.
RecurringReminderTarget? computeNextReminder({
  required int dueDay,
  required int remindDaysBefore,
  required DateTime now,
  int reminderHour = AppConstants.recurringReminderHour,
  int reminderMinute = AppConstants.recurringReminderMinute,
}) {
  if (dueDay < AppConstants.recurringDueDayMin ||
      dueDay > AppConstants.recurringDueDayMax) {
    return null;
  }
  if (remindDaysBefore < AppConstants.recurringRemindDaysBeforeMin ||
      remindDaysBefore > AppConstants.recurringRemindDaysBeforeMax) {
    return null;
  }

  RecurringReminderTarget build(int monthOffset) {
    final due = DateTime(
        now.year, now.month + monthOffset, dueDay, reminderHour, reminderMinute);
    return RecurringReminderTarget(
      scheduledAt: due.subtract(Duration(days: remindDaysBefore)),
      cycleKey: formatCycleKey(due),
    );
  }

  final thisCycle = build(0);
  if (thisCycle.scheduledAt.isAfter(now)) return thisCycle;
  return build(1);
}
