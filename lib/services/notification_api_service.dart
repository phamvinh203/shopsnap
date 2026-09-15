import '../core/network/api_client.dart';
import '../core/utils/budget_alert.dart';

/// Một notification trong feed (F-#12 AC 12.9) — shape BE:
/// `{ id, type, title, body, payload, read, read_at, created_at }`.
class AppNotification {
  /// 'budget_alert' | 'price_alert' | ... (BE tự enqueue — BudgetAlert).
  final String type;
  final String id;

  /// Title/body do BE soạn — feed hiển thị ĐÚNG dữ liệu server (AC 12.7).
  final String title;
  final String body;
  final Map<String, dynamic> payload;

  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.read,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String? ?? '',
        type: j['type'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        payload:
            j['payload'] is Map ? Map<String, dynamic>.from(j['payload'] as Map) : const {},
        read: j['read'] == true,
        readAt: _tryParseDate(j['read_at']),
        createdAt: _tryParseDate(j['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  static DateTime? _tryParseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  /// Deep-link ngữ cảnh khi bấm dòng trong feed (AC 12.5): route từ payload
  /// của BE nếu hợp lệ, fallback map theo type. `null` → không điều hướng.
  String? get route {
    final fromPayload = payload['route'];
    if (fromPayload is String && notificationTapRoutes.contains(fromPayload)) {
      return fromPayload;
    }
    switch (type) {
      case 'budget_alert':
      case 'budget':
        return budgetAlertRoute;
      case 'price_alert':
      case 'price_watch':
        return priceAlertRoute;
      default:
        return null;
    }
  }

  AppNotification copyWith({bool? read, DateTime? readAt}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        payload: payload,
        read: read ?? this.read,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );
}

/// Một trang `GET /notifications` — meta shape backend giống /items:
/// `{ total, page, limit, total_pages, has_next, has_prev }`.
class NotificationsPage {
  final List<AppNotification> items;
  final int page;
  final bool hasNext;

  const NotificationsPage({
    required this.items,
    required this.page,
    required this.hasNext,
  });

  factory NotificationsPage.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] is Map ? Map<String, dynamic>.from(j['meta'] as Map) : const {};
    final list = (j['items'] as List?) ?? const [];
    return NotificationsPage(
      items: list
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page: (meta['page'] as num?)?.toInt() ?? 1,
      hasNext: meta['has_next'] == true,
    );
  }
}

/// Gọi GET /notifications + PATCH /notifications/:id/read qua [ApiClient]
/// (auth: true → 401-refresh-retry tự động; BE user-scoped theo JWT — AC 12.11).
class NotificationApiService {
  final ApiClient _client;

  NotificationApiService(this._client);

  /// Mới nhất trước, phân trang server-side (AC 12.9).
  Future<NotificationsPage> fetchNotifications({int page = 1, int limit = 20}) async {
    final data = await _client.get('/notifications', auth: true, query: {
      'page': '$page',
      'limit': '$limit',
    });
    return NotificationsPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// PATCH /notifications/:id/read — BE idempotent (AC 12.10). Lỗi DO CALLER
  /// nuốt (im lặng): mark-read thất bại không được làm vỡ UI feed.
  Future<void> markRead(String id) =>
      _client.patch('/notifications/$id/read', auth: true);
}
