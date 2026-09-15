/// F-#12 (AC 12.7) — toggle "Budget alerts" / "Price alerts" trong /profile.
///
/// BE CHƯA có endpoint preference (spec Notes: chỉ có model
/// `NotificationPreference`, chưa có route) → toggle CHỈ LƯU LOCAL qua
/// SharedPreferences. Tắt → KHÔNG local notification loại đó được bắn nữa;
/// feed `GET /notifications` (server-side) vẫn hiện record do BE tạo.
/// Điều kiện mở khóa sync lên BE: BE thêm `PATCH /notifications/preferences`.
///
/// Pattern giống `theme_provider.dart`: AsyncNotifier đọc prefs đúng 1 lần lúc
/// build, setter cập nhật state NGAY rồi persist bất đồng bộ.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  /// Local notification khi chạm ngưỡng 80%/100% budget (AC 12.1/12.2).
  final bool budgetAlerts;

  /// Local notification khi món watched đạt mức giá tốt (AC 12.6).
  final bool priceAlerts;

  const NotificationPreferences({
    required this.budgetAlerts,
    required this.priceAlerts,
  });

  static const allEnabled = NotificationPreferences(
    budgetAlerts: true,
    priceAlerts: true,
  );
}

final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);

class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferences> {
  /// Key cố định — giữ lựa chọn của user giữa các phiên bản.
  static const prefKeyBudgetAlerts = 'pref_notify_budget_alerts';
  static const prefKeyPriceAlerts = 'pref_notify_price_alerts';

  @override
  Future<NotificationPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Mặc định BẬT cả hai (spec không định nghĩa mặc định → [ASSUMPTION] bật
    // để alert mới được nhìn thấy; user chủ động tắt trong /profile).
    return NotificationPreferences(
      budgetAlerts: prefs.getBool(prefKeyBudgetAlerts) ?? true,
      priceAlerts: prefs.getBool(prefKeyPriceAlerts) ?? true,
    );
  }

  Future<void> setBudgetAlerts(bool enabled) async {
    state = AsyncData(NotificationPreferences(
      budgetAlerts: enabled,
      priceAlerts: state.valueOrNull?.priceAlerts ?? true,
    ));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyBudgetAlerts, enabled);
  }

  Future<void> setPriceAlerts(bool enabled) async {
    state = AsyncData(NotificationPreferences(
      budgetAlerts: state.valueOrNull?.budgetAlerts ?? true,
      priceAlerts: enabled,
    ));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyPriceAlerts, enabled);
  }
}

/// Đọc preferences ĐÃ LOAD xong (await .future) — dùng tại các điểm gate
/// notification để tránh race: `valueOrNull` lúc provider đang AsyncLoading
/// trả null và gate fail-open, alert vẫn bắn dù user đã lưu "tắt".
/// Lỗi đọc prefs (storage hỏng) → null → caller xử lý fail-open (BẬT).
Future<NotificationPreferences?> loadNotificationPreferences(Ref ref) async {
  try {
    return await ref.read(notificationPreferencesProvider.future);
  } catch (_) {
    return null;
  }
}
