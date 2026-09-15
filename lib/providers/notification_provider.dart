import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/budget_alert.dart';
import '../services/budget_alert_service.dart';
import '../services/notification_api_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

// ── Hạ tầng ──────────────────────────────────────────────────────────────────

final notificationApiServiceProvider = Provider<NotificationApiService>((ref) {
  return NotificationApiService(ref.watch(apiClientProvider));
});

/// Storage dedup key budget alert (AC 12.3) — SharedPreferences string-set.
/// Key đã gắn budget + kỳ nên không cần dọn theo kỳ: key cũ kỳ trước nằm
/// vô hại trong set.
const budgetAlertFiredKeysPref = 'notif_budget_alert_fired_keys';

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  Future<void> persist(String key) async {
    final prefs = await _prefs();
    final keys = prefs.getStringList(budgetAlertFiredKeysPref) ?? const <String>[];
    if (!keys.contains(key)) {
      await prefs.setStringList(budgetAlertFiredKeysPref, [...keys, key]);
    }
  }

  return BudgetAlertService(
    loadFiredKeys: () async =>
        (await _prefs()).getStringList(budgetAlertFiredKeysPref)?.toSet() ??
        const <String>{},
    persistFiredKey: persist,
    // Nội dung payload GENERIC do NotificationService tự soạn (AC 12.4);
    // fallback permission banner do caller xử lý (AC 12.13).
    notify: (threshold) => threshold == BudgetAlertThreshold.warning
        ? NotificationService.showBudgetWarning()
        : NotificationService.showBudgetExceeded(),
  );
});

// ── AC 12.13 — trạng thái "không có quyền hiển thị notification" ─────────────

/// Đặt `true` khi lần gửi local notification mới nhất bị hệ điều hành chặn
/// (canDeliver == false). Home đọc để hiện banner hướng dẫn bật quyền trong
/// system settings (thay thế notification không gửi được).
final notificationPermissionDeniedProvider = StateProvider<bool>((ref) => false);

// ── AC 12.8 — badge bell: số notification CHƯA ĐỌC ──────────────────────────

/// Đếm `read = false` từ `GET /notifications`. Chưa đăng nhập → 0 (không gọi
/// API); lỗi mạng → 0 (badge chỉ là UX hỗ trợ, không được làm vỡ Home).
///
/// [ASSUMPTION] BE chưa có endpoint đếm unread riêng → đếm trên trang đầu
/// (limit 100 = max page size của backend, đúng pattern items API). Unread cũ
/// hơn 100 record gần nhất sẽ không đếm được — khi BE thêm `/notifications/unread-count`
/// sẽ thay nguồn số này.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final authenticated =
      ref.watch(authStateProvider).value?.isAuthenticated == true;
  if (!authenticated) return 0;

  try {
    final page = await ref
        .watch(notificationApiServiceProvider)
        .fetchNotifications(page: 1, limit: 100);
    return page.items.where((n) => !n.read).length;
  } catch (_) {
    return 0;
  }
});

// ── AC 12.9/12.10/12.12 — Notification Feed ──────────────────────────────────

/// Trang đầu luôn 20 dòng (mặc định UI); pull-to-refresh tải lại trang 1.
const notificationFeedPageSize = 20;

class NotificationFeedState {
  final List<AppNotification> items;
  final int page;

  /// `true` khi còn trang kế tiếp (meta.has_next của BE).
  final bool hasNext;

  /// AC 12.12 — refresh THẤT BẠI nhưng vẫn còn dữ liệu cũ: giữ cache + hiện
  /// chỉ báo "chưa cập nhật được", pull-to-refresh thử lại.
  final bool isStale;

  const NotificationFeedState({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.isStale,
  });

  NotificationFeedState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasNext,
    bool? isStale,
  }) =>
      NotificationFeedState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasNext: hasNext ?? this.hasNext,
        isStale: isStale ?? this.isStale,
      );
}

/// Notifier feed — giữ state trong bộ nhớ (không autoDispose) để offline quay
/// lại vẫn còn "cache gần nhất" (AC 12.12). Mở màn lần đầu → tự tải trang 1.
class NotificationFeedNotifier extends AsyncNotifier<NotificationFeedState> {
  @override
  Future<NotificationFeedState> build() async {
    // Chưa đăng nhập → feed rỗng (endpoint cần Bearer; badge đã ẩn sẵn).
    final authenticated =
        ref.watch(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) {
      return const NotificationFeedState(
          items: [], page: 1, hasNext: false, isStale: false);
    }

    final page = await ref
        .read(notificationApiServiceProvider)
        .fetchNotifications(page: 1, limit: notificationFeedPageSize);
    return NotificationFeedState(
      items: page.items,
      page: page.page,
      hasNext: page.hasNext,
      isStale: false,
    );
  }

  /// Pull-to-refresh / quay lại foreground (AC 12.9/12.12). KHÔNG ném lỗi lên
  /// RefreshIndicator: có cache → giữ + đánh dấu stale; không cache → AsyncError
  /// để màn hình render ErrorState với nút Thử lại.
  Future<void> refresh() async {
    try {
      final page = await ref
          .read(notificationApiServiceProvider)
          .fetchNotifications(page: 1, limit: notificationFeedPageSize);
      state = AsyncData(NotificationFeedState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        isStale: false,
      ));
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e, st) {
      final current = state.valueOrNull;
      if (current == null || current.items.isEmpty) {
        state = AsyncError(e, st);
      } else {
        state = AsyncData(current.copyWith(isStale: true));
      }
    }
  }

  /// AC 12.10 — mở/chạm 1 notification: optimistic set read NGAY (badge giảm
  /// tức thì), rồi PATCH mark-read; mọi lỗi PATCH bị nuốt (BE idempotent,
  /// lỗi mạng không được làm vỡ feed — lần refresh sau sẽ khớp lại).
  Future<void> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.items.where((n) => n.id == id).toList();
    if (target.isEmpty || target.first.read) return;

    state = AsyncData(current.copyWith(items: [
      for (final n in current.items)
        if (n.id == id) n.copyWith(read: true, readAt: DateTime.now()) else n,
    ]));
    ref.invalidate(unreadNotificationsCountProvider);

    try {
      await ref.read(notificationApiServiceProvider).markRead(id);
    } catch (_) {
      // Im lặng theo AC 12.10 — optimistic state giữ nguyên, BE idempotent.
    }
  }
}

final notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeedNotifier, NotificationFeedState>(
  NotificationFeedNotifier.new,
);
