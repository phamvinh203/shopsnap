import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/core/utils/budget_alert.dart';
import 'package:shopsnap/core/utils/recurring_schedule.dart';

/// AC 4.11/4.12/4.13 — Pure function tính mốc nhắc trước hạn + hằng generic.
void main() {
  group('computeNextReminder (AC 4.11)', () {
    test('Chu kỳ kế tiếp trong tháng: hạn ngày 15, nhắc trước 1 → 14/09 09:00',
        () {
      final target = computeNextReminder(
        dueDay: 15,
        remindDaysBefore: 1,
        now: DateTime(2026, 9, 1, 8, 0),
      );

      expect(target, isNotNull);
      expect(target!.scheduledAt, DateTime(2026, 9, 14, 9, 0));
      expect(target.cycleKey, '2026-09');
    });

    test('Nhắc đúng 09:00 local theo AppConstants (giờ nhắc MỘT nơi)', () {
      expect(AppConstants.recurringReminderHour, 9);
      expect(AppConstants.recurringReminderMinute, 0);

      final target = computeNextReminder(
        dueDay: 10,
        remindDaysBefore: 0,
        now: DateTime(2026, 9, 1, 23, 59),
      );
      expect(target!.scheduledAt.hour, 9);
      expect(target.scheduledAt.minute, 0);
      expect(target.scheduledAt.day, 10);
    });

    test('AC 4.6 — mốc nhắc chu kỳ hiện tại ĐÃ QUA → chu kỳ tháng sau, không nhắc bù',
        () {
      final target = computeNextReminder(
        dueDay: 5,
        remindDaysBefore: 1,
        now: DateTime(2026, 9, 5, 10, 0), // 04/09 09:00 đã qua
      );

      expect(target!.scheduledAt, DateTime(2026, 10, 4, 9, 0));
      expect(target.cycleKey, '2026-10');
    });

    test('AC 4.6 — đúng NGAY mốc nhắc (== now) → không tính chu kỳ này', () {
      final target = computeNextReminder(
        dueDay: 5,
        remindDaysBefore: 1,
        now: DateTime(2026, 9, 4, 9, 0),
      );
      expect(target!.cycleKey, '2026-10');
    });

    test('due_day nhỏ + nhắc trước nhiều ngày → mốc nhắc tràn về tháng trước, '
        'cycleKey vẫn là tháng ĐẾN HẠN', () {
      final target = computeNextReminder(
        dueDay: 1,
        remindDaysBefore: 3,
        now: DateTime(2026, 8, 20, 12, 0),
      );

      // Hạn 01/09 09:00 lùi 3 ngày = 29/08 09:00; chu kỳ = '2026-09'.
      expect(target!.scheduledAt, DateTime(2026, 8, 29, 9, 0));
      expect(target.cycleKey, '2026-09');
    });

    test('Tham số ngoài miền → null (phòng thủ cuối, không schedule rác)', () {
      expect(
        computeNextReminder(
            dueDay: 0, remindDaysBefore: 1, now: DateTime(2026, 9, 1)),
        isNull,
      );
      expect(
        computeNextReminder(
            dueDay: 29, remindDaysBefore: 1, now: DateTime(2026, 9, 1)),
        isNull,
      );
      expect(
        computeNextReminder(
            dueDay: 5, remindDaysBefore: -1, now: DateTime(2026, 9, 1)),
        isNull,
      );
      expect(
        computeNextReminder(
            dueDay: 5, remindDaysBefore: 4, now: DateTime(2026, 9, 1)),
        isNull,
      );
    });
  });

  group('AC 4.11/4.12 — notification id deterministic từ entry.id', () {
    test('Cùng id → cùng notification id (dùng chung cancel/schedule)', () {
      expect(recurringNotificationId('entry-abc'),
          recurringNotificationId('entry-abc'));
    });

    test('Khác entry → id khác nhau; luôn nằm trong [0, 2^31)', () {
      final a = recurringNotificationId('entry-abc');
      final b = recurringNotificationId('entry-xyz');
      expect(a, isNot(b));

      for (final id in [a, b, recurringNotificationId('')]) {
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThan(0x80000000));
      }
    });
  });

  group('AC 4.13 — nội dung notification GENERIC (AC 12.4 nguyên văn)', () {
    test('title cố định "Khoản định kỳ sắp đến hạn", KHÔNG số, KHÔNG tên khoản',
        () {
      expect(recurringReminderTitle, 'Khoản định kỳ sắp đến hạn');
      expect(recurringReminderTitle.contains(RegExp(r'\d')), isFalse);
    });

    test('body generic — KHÔNG số tiền, KHÔNG tên khoản, KHÔNG đơn vị tiền', () {
      expect(recurringReminderBody.contains(RegExp(r'\d')), isFalse);
      expect(recurringReminderBody.contains('%'), isFalse);
      expect(
          recurringReminderBody.contains(RegExp(r'vnd|₫', caseSensitive: false)),
          isFalse);
    });

    test('payload deep-link → /recurring, nằm trong whitelist tap', () {
      expect(parseNotificationRoute(recurringAlertPayload), '/recurring');
      expect(notificationTapRoutes, contains('/recurring'));
      expect(recurringAlertPayload.contains('amount'), isFalse);
      expect(recurringAlertPayload.contains('name'), isFalse);
    });
  });

  test('RecurringReminderTarget ==/hashCode theo scheduledAt + cycleKey', () {
    final t1 = RecurringReminderTarget(
        scheduledAt: DateTime(2026, 9, 14, 9), cycleKey: '2026-09');
    final t2 = RecurringReminderTarget(
        scheduledAt: DateTime(2026, 9, 14, 9), cycleKey: '2026-09');
    final t3 = RecurringReminderTarget(
        scheduledAt: DateTime(2026, 9, 14, 9), cycleKey: '2026-10');

    expect(t1, equals(t2));
    expect(t1.hashCode, t2.hashCode);
    expect(t1, isNot(t3));
  });
}
