import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/budget_alert.dart';
import '../core/utils/recurring_schedule.dart';

/// F-#12 Smart Notification — local notification cho budget alert + price alert.
///
/// BẢO ĐẶT AC 12.4 (security — CỨNG): title/body chỉ lấy từ các hằng generic
/// trong `budget_alert.dart` (một nơi duy nhất, không chứa số tiền / % / tên
/// món). API của class này CỐ Ý KHÔNG nhận tham số dữ liệu nhạy cảm — không
/// thể vô tình render số tiền hay tên món lên lockscreen. Chi tiết chỉ hiển
/// thị trong app sau khi user bấm (AC 12.5 — payload deep-link).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Được ShopSnapApp gắn sau khi tạo GoRouter — bấm notification sẽ push tới
  /// đúng ngữ cảnh (AC 12.5). Route đã lọc whitelist trong
  /// [parseNotificationRoute] nên payload lạ không điều hướng bậy; [itemId]
  /// (AC 12.5 — price alert) để màn đích scroll-to + highlight đúng món.
  static void Function(String route, {String? itemId})? onNotificationTap;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleTap,
    );
    // AC 12.13 (Android 13+): chủ động xin quyền POST_NOTIFICATIONS khi app
    // khởi động — thiếu quyền thì app không crash, UI hiện banner hướng dẫn
    // (xem notificationPermissionDeniedProvider trên Home).
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Plugin chưa sẵn sàng (test/máy không hỗ trợ) → bỏ qua.
    }
  }

  /// Bấm notification (khi app foreground/background) → deep-link tới ngữ cảnh.
  static void _handleTap(NotificationResponse response) {
    final route = parseNotificationRoute(response.payload);
    if (route == null) return;
    onNotificationTap?.call(
      route,
      itemId: parseNotificationItemId(response.payload),
    );
  }

  /// Có được phép hiển thị notification không — best-effort, CHỈ trả `false`
  /// khi hệ điều hành xác nhận rõ ràng đã TẮT (AC 12.13). Môi trường test /
  /// lỗi plugin → `true` (fail-open: plugin `show` tự no-op, không crash).
  static Future<bool> get canDeliver async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      if (enabled == false) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  /// AC 12.1 — ngưỡng 80%: title "Ngân sách cần chú ý", body generic.
  static Future<void> showBudgetWarning() async {
    await _show(
      id: 1,
      title: budgetAlertTitle,
      body: budgetWarningBody,
      payload: budgetAlertPayload,
      channel: const AndroidNotificationDetails(
        'budget_alert', 'Cảnh báo ngân sách',
        importance: Importance.high, priority: Priority.high,
      ),
    );
  }

  /// AC 12.2 — ngưỡng 100%: nội dung vượt ngân sách generic (AC 12.4 — không
  /// số tiền, không %); safe_daily và chi tiết chỉ có trong app khi mở.
  static Future<void> showBudgetExceeded() async {
    await _show(
      id: 2,
      title: budgetAlertTitle,
      body: budgetExceededBody,
      payload: budgetAlertPayload,
      channel: const AndroidNotificationDetails(
        'budget_danger', 'Vượt ngân sách',
        importance: Importance.max, priority: Priority.max,
      ),
    );
  }

  /// F-#12 AC 12.6 — price alert generic "Cập nhật giá đáng chú ý". Dedup lần
  /// giảm giá nằm ở PriceWatchService (AC 6.15). Signature không nhận tên món
  /// / giá — AC 12.4 khóa ở tầng API, không phụ thuộc caller nhớ quy tắc.
  ///
  /// [itemId] chỉ đi vào payload deep-link (ID kỹ thuật, AC 12.5) để mở đúng
  /// món trong Shopping List — KHÔNG bao giờ vào title/body hiển thị.
  static Future<void> showPriceWatch({String? itemId}) async {
    await _show(
      id: 3,
      title: priceAlertTitle,
      body: priceAlertBody,
      payload: priceAlertPayloadFor(itemId),
      channel: const AndroidNotificationDetails(
        'price_watch', 'Theo dõi giá',
        importance: Importance.high, priority: Priority.high,
      ),
    );
  }

  /// M-2 (AC 4.11) — đặt lịch nhắc trước hạn cho MỘT khoản định kỳ:
  /// ĐÚNG 1 zonedSchedule (one-shot, `matchDateTimeComponents` null) tại mốc
  /// đã tính sẵn bằng pure function `computeNextReminder` (09:00 local của
  /// chu kỳ kế tiếp). Re-arm = cancel id cũ rồi gọi lại method này → tại mọi
  /// thời điểm mỗi entry tối đa 1 pending, không nhân bản (AC 4.12).
  ///
  /// BẢO ĐẶT AC 4.13 (AC 12.4 áp dụng nguyên văn): signature CỐ Ý KHÔNG nhận
  /// tên khoản / số tiền — title/body là HẰNG generic trong
  /// `recurring_schedule.dart`, không thể lộ dữ liệu lên lockscreen.
  ///
  /// Alarm INEXACT (`inexactAllowWhileIdle`): spec không bắt buộc exact →
  /// tránh đòi quyền SCHEDULE_EXACT_ALARM trên Android 12+; chênh vài phút
  /// không ảnh hưởng mục đích "nhắc trước hạn". Thời điểm được truyền là
  /// DateTime local của thiết bị → convert qua `tz.UTC` giữ NGUYÊN instant
  /// tuyệt đối (không phụ thuộc database timezone name của máy).
  static Future<void> scheduleRecurringReminder({
    required int notificationId,
    required DateTime when,
  }) async {
    await _plugin.zonedSchedule(
      notificationId,
      recurringReminderTitle,
      recurringReminderBody,
      tz.TZDateTime.from(when, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_reminder', 'Nhắc khoản định kỳ',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: recurringAlertPayload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Hủy pending schedule của một entry (sửa/tắt/xóa rồi re-arm — AC 4.5).
  /// Id phải là giá trị [recurringNotificationId] đã dùng khi schedule.
  static Future<void> cancelNotification(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String payload,
    required AndroidNotificationDetails channel,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: channel, iOS: const DarwinNotificationDetails()),
      payload: payload,
    );
  }
}
