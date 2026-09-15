import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/core/utils/relative_time.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/notification_provider.dart';
import 'package:shopsnap/screens/notifications/notification_feed_screen.dart';
import 'package:shopsnap/services/notification_api_service.dart';

/// F-#12 — Notification Feed widget test (AC 12.9/12.10/12.12):
/// render dữ liệu server, empty state, error state, mark-read (lỗi im lặng),
/// offline stale banner + pull-to-refresh.

AppNotification _notif(
  String id, {
  bool read = false,
  String title = 'Ngân sách cần chú ý',
  String type = 'budget_alert',
  DateTime? createdAt,
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      body: 'Bạn đã vượt mức chi tiêu đã đặt ra. Mở ứng dụng để xem chi tiết.',
      payload: const {},
      read: read,
      readAt: read ? DateTime(2026, 9, 15, 9) : null,
      createdAt: createdAt ?? DateTime(2026, 9, 15, 8, 30),
    );

/// Fake NotificationApiService — đếm số lần fetch, ghi nhận mark-read, có chế
/// độ lỗi: failAll (lỗi ngay từ call đầu) / failAfterFirst (mất mạng khi
/// pull-to-refresh — call đầu OK).
class _FakeApi implements NotificationApiService {
  _FakeApi(this.page);

  final NotificationsPage page;
  int fetchCalls = 0;
  final readIds = <String>[];
  bool failAll = false;
  bool failAfterFirst = false;
  bool failMarkRead = false;

  @override
  Future<NotificationsPage> fetchNotifications({int page = 1, int limit = 20}) async {
    fetchCalls++;
    if (failAll || (failAfterFirst && fetchCalls > 1)) {
      throw StateError('offline');
    }
    return this.page;
  }

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    if (failMarkRead) throw StateError('network gone');
  }
}

/// Feed provider cần trạng thái "đã đăng nhập" (chưa đăng nhập → feed rỗng
/// theo design) — override auth để không chạm TokenStorage thật.
class _AuthedNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.authenticated);
}

Future<void> _pumpFeed(WidgetTester tester, _FakeApi api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationApiServiceProvider.overrideWithValue(api),
        authStateProvider.overrideWith(_AuthedNotifier.new),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const NotificationFeedScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AC 12.9 — render items mới nhất trước: title/body/thời gian + trạng thái read',
      (tester) async {
    final createdAt = DateTime(2026, 9, 15, 8, 30);
    final api = _FakeApi(NotificationsPage(
      items: [
        _notif('n_new', title: 'Cập nhật giá đáng chú ý', type: 'price_alert', createdAt: createdAt),
        _notif('n_old', read: true, createdAt: createdAt),
      ],
      page: 1,
      hasNext: false,
    ));
    await _pumpFeed(tester, api);

    expect(find.byKey(const Key('notificationTile_n_new')), findsOneWidget);
    expect(find.byKey(const Key('notificationTile_n_old')), findsOneWidget);
    // Thứ tự giữ nguyên thứ tự server (mới nhất trước).
    expect(
      tester.getTopLeft(find.byKey(const Key('notificationTile_n_new'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('notificationTile_n_old'))).dy),
    );
    // Unread dot chỉ ở dòng chưa đọc.
    expect(find.byKey(const Key('notificationTile_unreadDot')), findsOneWidget);
    // Thời gian tương đối hiển thị theo đúng helper.
    final expectedTime = formatRelativeTime(createdAt, now: DateTime.now());
    expect(find.text(expectedTime), findsNWidgets(2));
  });

  testWidgets('AC 12.10 — chạm notification → PATCH mark-read đúng id, dot unread biến mất',
      (tester) async {
    final api = _FakeApi(NotificationsPage(
      items: [_notif('n1')],
      page: 1,
      hasNext: false,
    ));
    await _pumpFeed(tester, api);

    await tester.tap(find.byKey(const Key('notificationTile_n1')));
    await tester.pumpAndSettle();

    expect(api.readIds, ['n1']);
    expect(find.byKey(const Key('notificationTile_unreadDot')), findsNothing);
  });

  testWidgets('AC 12.10 — mark-read lỗi mạng → im lặng, không crash, optimistic giữ read',
      (tester) async {
    final api = _FakeApi(NotificationsPage(
      items: [_notif('n1')],
      page: 1,
      hasNext: false,
    ))..failMarkRead = true;
    await _pumpFeed(tester, api);

    await tester.tap(find.byKey(const Key('notificationTile_n1')));
    await tester.pumpAndSettle();

    expect(api.readIds, ['n1']);
    // Đã đọc optimistically — không có dot, không ErrorState.
    expect(find.byKey(const Key('errorState')), findsNothing);
    expect(find.byKey(const Key('notificationTile_unreadDot')), findsNothing);
  });

  testWidgets('AC 12.9 — chưa có thông báo → EmptyState đúng tokens', (tester) async {
    final api = _FakeApi(const NotificationsPage(
      items: [],
      page: 1,
      hasNext: false,
    ));
    await _pumpFeed(tester, api);

    expect(find.byKey(const Key('emptyState')), findsOneWidget);
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });

  testWidgets('lỗi tải lần đầu → ErrorState + Thử lại gọi lại API', (tester) async {
    final api = _FakeApi(NotificationsPage(
      items: [_notif('n1')],
      page: 1,
      hasNext: false,
    ))..failAll = true;
    await _pumpFeed(tester, api);

    expect(find.byKey(const Key('errorState')), findsOneWidget);

    // "Thử lại" → lần gọi này thành công → danh sách render.
    api.failAll = false;
    await tester.tap(find.byKey(const Key('errorState_retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('errorState')), findsNothing);
    expect(find.byKey(const Key('notificationTile_n1')), findsOneWidget);
  });

  testWidgets('AC 12.12 — offline khi refresh: giữ cache + banner "chưa cập nhật được"',
      (tester) async {
    final api = _FakeApi(NotificationsPage(
      items: [_notif('n1')],
      page: 1,
      hasNext: false,
    ))..failAfterFirst = true;
    await _pumpFeed(tester, api);

    // Pull-to-refresh khi mất mạng.
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notificationFeed_staleBanner')), findsOneWidget);
    // Dữ liệu cache gần nhất vẫn hiển thị.
    expect(find.byKey(const Key('notificationTile_n1')), findsOneWidget);
    expect(find.byKey(const Key('errorState')), findsNothing);

    // Có mạng lại → pull-to-refresh thành công → banner biến mất.
    api.failAfterFirst = false;
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notificationFeed_staleBanner')), findsNothing);
    expect(api.fetchCalls, greaterThanOrEqualTo(3));
  });

  testWidgets('AC 12.9 — pull-to-refresh tải lại (fetch được gọi lại)', (tester) async {
    final api = _FakeApi(NotificationsPage(
      items: [_notif('n1')],
      page: 1,
      hasNext: false,
    ));
    await _pumpFeed(tester, api);
    expect(api.fetchCalls, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
    await tester.pumpAndSettle();

    expect(api.fetchCalls, greaterThanOrEqualTo(2));
  });
}
