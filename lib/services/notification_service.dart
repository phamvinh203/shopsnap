import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<void> showBudgetWarning({required int spent, required int total}) async {
    final pct = (spent / total * 100).round();
    await _plugin.show(
      1,
      'Sắp đạt ngân sách 📊',
      'Bạn đã dùng $pct% ngân sách hôm nay',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alert', 'Cảnh báo ngân sách',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showBudgetExceeded({required int spent, required int total}) async {
    await _plugin.show(
      2,
      'Vượt ngân sách! ⚠️',
      'Bạn đã chi vượt mức đặt ra hôm nay',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_danger', 'Vượt ngân sách',
          importance: Importance.max, priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
