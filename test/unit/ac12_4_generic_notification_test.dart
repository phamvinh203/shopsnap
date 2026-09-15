import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/budget_alert.dart';
import 'package:shopsnap/services/budget_alert_service.dart';
import 'package:shopsnap/services/notification_service.dart';

/// F-#12 — AC 12.4 (Security — CỨNG): nội dung notification (title/body/payload)
/// đẩy xuống hệ điều hành phải GENERIC — KHÔNG số tiền, KHÔNG %, KHÔNG tên món.
///
/// Cách test: mock method channel của flutter_local_notifications
/// (`dexterous.com/flutter/local_notifications`) để BẮT ĐÚNG payload mà app
/// gửi xuống platform (tương đương nội dung sẽ xuất hiện trên lockscreen),
/// thay vì chỉ test string rời rạc. QA vẫn phải chụp lockscreen thật trên máy
/// để làm bằng chứng (theo spec) — test này là lớp bảo vệ tại CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// (method, args) của MỌI method call xuống plugin.
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      // Ghi nhận MỌI method call; 'initialize' phải trả bool (plugin cast kết
      // quả) — những method khác trả null an toàn.
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
    NotificationService.onNotificationTap = null;
  });

  Future<void> initAndFireAll() async {
    await NotificationService.init();
    await NotificationService.showBudgetWarning();
    await NotificationService.showBudgetExceeded();
    await NotificationService.showPriceWatch();
  }

  List<Map<String, dynamic>> shownPayloads() => calls
      .where((c) => c.method == 'show')
      .map((c) => Map<String, dynamic>.from(c.arguments as Map))
      .toList();

  test('AC 12.4 — cả 3 loại alert đẩy title/body generic, không chữ số / % / đơn vị tiền',
      () async {
    await initAndFireAll();
    final shown = shownPayloads();

    // Đủ 3 notification: budget 80%, budget 100%, price watch.
    expect(shown.length, 3);

    for (final payload in shown) {
      final title = payload['title'] as String;
      final body = payload['body'] as String;

      // Không chữ số nào (chặn mọi số tiền VÀ mọi % chi tiêu).
      expect(title.contains(RegExp(r'\d')), isFalse,
          reason: 'title chứa số: "$title"');
      expect(body.contains(RegExp(r'\d')), isFalse,
          reason: 'body chứa số: "$body"');
      // Không ký hiệu % / đơn vị tiền.
      expect(title.contains('%'), isFalse, reason: 'title chứa %: "$title"');
      expect(body.contains('%'), isFalse, reason: 'body chứa %: "$body"');
      expect(body.contains(RegExp(r'vnd|₫', caseSensitive: false)), isFalse,
          reason: 'body chứa đơn vị tiền: "$body"');
    }
  });

  test('AC 12.1/12.2 — budget alert dùng ĐÚNG title "Ngân sách cần chú ý" + body generic cố định',
      () async {
    await initAndFireAll();
    final shown = shownPayloads();
    final budget = shown.where((p) => p['title'] == budgetAlertTitle).toList();

    expect(budgetAlertTitle, 'Ngân sách cần chú ý');
    expect(budget.length, 2); // ngưỡng 80% và 100%
    for (final payload in budget) {
      // Body phải là MỘT trong các hằng generic — không thể là chuỗi nội suy
      // từ dữ liệu (chữ ký showBudgetWarning/showBudgetExceeded không nhận
      // tham số dữ liệu nên không thể lọt số tiền/tên món vào đây).
      expect(
        [budgetWarningBody, budgetExceededBody],
        contains(payload['body']),
      );
    }
    // Hai ngưỡng có 2 body KHÁC nhau (80% "gần chạm", 100% "đã vượt").
    expect(budget.map((p) => p['body']).toSet().length, 2);
  });

  test('AC 12.4/12.6 — price alert KHÔNG nhận tên món/giá: body = hằng generic, '
      'signature không có tham số dữ liệu', () async {
    // showPriceWatch() không nhận bất kỳ tham số nào — dù caller có tên món
    // hay giá trong tay cũng không thể đưa vào payload notification.
    await NotificationService.init();
    await NotificationService.showPriceWatch();

    final shown = shownPayloads();
    expect(shown.length, 1);
    expect(shown.single['title'], 'Cập nhật giá đáng chú ý');
    expect(shown.single['body'], priceAlertBody);
    expect(shown.single['body'].contains(RegExp(r'\d')), isFalse);
  });

  test('AC 12.5 — payload deep-link: budget → /budget, price → /shopping-list, '
      'route lạ bị từ chối', () async {
    await initAndFireAll();

    final routes = shownPayloads().map((p) => p['payload'] as String?).map(
          (raw) => parseNotificationRoute(raw),
        );
    expect(routes, containsAll(['/budget', '/budget', '/shopping-list']));

    // Whitelist: payload rỗng/hỏng/route lạ → null (tap không điều hướng).
    expect(parseNotificationRoute(null), isNull);
    expect(parseNotificationRoute(''), isNull);
    expect(parseNotificationRoute('{"route":"/admin"}'), isNull);
    expect(parseNotificationRoute('not json'), isNull);
  });

  test('End-to-end pipeline: BudgetAlertService → NotificationService — payload '
      'xuống channel vẫn generic khi dữ liệu thật có số tiền lớn', () async {
    await NotificationService.init();

    final svc = BudgetAlertService(
      loadFiredKeys: () async => {},
      persistFiredKey: (_) async {},
      notify: (threshold) => threshold == BudgetAlertThreshold.warning
          ? NotificationService.showBudgetWarning()
          : NotificationService.showBudgetExceeded(),
    );

    // Dữ liệu thật "nhạy cảm" chỉ có ở caller — KHÔNG truyền được vào service.
    final fired = await svc.checkAfterSpendChange(
      spentBefore: 7999000,
      spentAfter: 10500000,
      budgetAmount: 10000000,
      budgetId: 'budget-with-sensitive-amounts',
      periodStart: '2026-09-01',
      periodEnd: '2026-09-30',
    );
    expect(fired, 1);

    final shown = shownPayloads();
    for (final payload in shown) {
      final text = '${payload['title']} ${payload['body']} ${payload['payload']}';
      expect(text.contains(RegExp(r'\d')), isFalse,
          reason: 'payload lộ số: "$text"');
      expect(text.contains('7') || text.contains('9'), isFalse);
    }
  });
}
