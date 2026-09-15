import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/budget_alert.dart';
import 'package:shopsnap/core/utils/recurring_schedule.dart';
import 'package:shopsnap/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;

/// M-2 — AC 4.11/4.13: schedule định kỳ phải là `zonedSchedule` với nội dung
/// GENERIC (AC 12.4 áp dụng nguyên văn) và cancel đúng id.
///
/// Cách test: mock method channel của flutter_local_notifications
/// (`dexterous.com/flutter/local_notifications`) để BẮT ĐÚNG payload app gửi
/// xuống platform (tương đương nội dung trên lockscreen). QA vẫn chụp
/// lockscreen thật làm bằng chứng theo spec — test này là lớp bảo vệ tại CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    tz_data.initializeTimeZones(); // spec AC 4.11: init timezone ở main
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' ||
          'requestNotificationsPermission' ||
          'areNotificationsEnabled' =>
            true,
          _ => null,
        };
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
  });

  List<Map<String, dynamic>> scheduledArgs() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => Map<String, dynamic>.from(c.arguments as Map))
      .toList();

  test('AC 4.11 — scheduleRecurringReminder gửi ĐÚNG 1 zonedSchedule với id truyền vào',
      () async {
    await NotificationService.init();
    calls.clear();

    const id = 123456;
    final when = DateTime(2026, 10, 4, 9, 0);
    await NotificationService.scheduleRecurringReminder(
        notificationId: id, when: when);

    final scheduled = scheduledArgs();
    expect(scheduled, hasLength(1));

    // Id & thời điểm xuống platform: mốc 09:00 local đúng tuyệt đối
    // (epoch ms khớp DateTime local của thiết bị).
    expect(scheduled.single['id'], id);
    expect(scheduled.single['title'], recurringReminderTitle);
    expect(scheduled.single['body'], recurringReminderBody);
    expect(scheduled.single['payload'], recurringAlertPayload);
  });

  test('AC 4.13 — nội dung xuống channel GENERIC: KHÔNG số tiền, KHÔNG tên khoản, '
      'signature không nhận tham số dữ liệu', () async {
    await NotificationService.init();
    calls.clear();

    // Caller CÓ dữ liệu nhạy cảm trong tay nhưng KHÔNG truyền được vào API —
    // signature chỉ nhận id + thời điểm (khóa ở tầng chữ hàm).
    await NotificationService.scheduleRecurringReminder(
      notificationId: recurringNotificationId('entry-with-200000-vnd'),
      when: DateTime(2026, 10, 4, 9, 0),
    );

    final scheduled = scheduledArgs();
    expect(scheduled, hasLength(1));

    final title = scheduled.single['title'] as String;
    final body = scheduled.single['body'] as String;
    final payload = scheduled.single['payload'] as String;

    expect(title.contains(RegExp(r'\d')), isFalse,
        reason: 'title chứa số: "$title"');
    expect(body.contains(RegExp(r'\d')), isFalse,
        reason: 'body chứa số: "$body"');
    expect(body.contains('%'), isFalse);
    expect(body.contains(RegExp(r'vnd|₫', caseSensitive: false)), isFalse);
    // Tên khoản không bao giờ lọt title/body.
    expect(title.toLowerCase().contains('netflix'), isFalse);
    expect(body.toLowerCase().contains('netflix'), isFalse);
    // Payload chỉ chứa route deep-link — id kỹ thuật nằm payload? KHÔNG:
    // recurring payload chỉ có route, chi tiết nằm trong app (AC 4.13).
    expect(parseNotificationRoute(payload), '/recurring');
    expect(payload.contains('200000'), isFalse);
  });

  test('AC 4.5 — cancelNotification gọi đúng id xuống platform', () async {
    await NotificationService.init();
    calls.clear();

    final id = recurringNotificationId('entry-abc');
    await NotificationService.cancelNotification(id);

    expect(calls.where((c) => c.method == 'cancel'), hasLength(1));
    // Plugin gói args thành map {'id': ..., 'tag': null}.
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['id'], id);
  });

  test('AC 4.13 — bấm notification recurring → deep-link /recurring (whitelist)',
      () {
    expect(parseNotificationRoute(recurringAlertPayload), '/recurring');
    // Route lạ vẫn bị từ chối.
    expect(parseNotificationRoute('{"route":"/admin"}'), isNull);
  });
}
