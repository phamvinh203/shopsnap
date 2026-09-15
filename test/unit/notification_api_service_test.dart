import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/core/network/token_storage.dart';
import 'package:shopsnap/models/user_model.dart';
import 'package:shopsnap/services/notification_api_service.dart';

/// F-#12 — NotificationApiService với ApiClient mock (MockClient):
/// parse `GET /notifications` (`items` + `meta` shape backend), PATCH
/// mark-read, và AC 12.11 (user-scoped theo JWT — 2 tài khoản 2 token).
http.Response okJson(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> notificationJson({
  required String id,
  String type = 'budget_alert',
  String title = 'Ngân sách cần chú ý',
  String body = 'Bạn đã dùng gần hết ngân sách.',
  bool read = false,
  String? readAt,
  String createdAt = '2026-09-15T02:00:00.000Z',
  Map<String, dynamic>? payload,
}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'payload': payload ?? const {},
      'read': read,
      'read_at': readAt,
      'created_at': createdAt,
    };

Map<String, dynamic> pageJson(List<Map<String, dynamic>> items,
        {int page = 1, bool hasNext = false, int total = 0}) =>
    {
      'items': items,
      'meta': {
        'total': total == 0 ? items.length : total,
        'page': page,
        'limit': 20,
        'total_pages': 1,
        'has_next': hasNext,
        'has_prev': page > 1,
      },
    };

/// TokenStorage giả lập — mỗi "tài khoản" một cặp token riêng (AC 12.11).
class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage(this._tokens);
  final AuthTokens? _tokens;

  @override
  Future<AuthTokens?> readTokens() async => _tokens;
  @override
  Future<void> saveTokens(AuthTokens tokens) async {}
  @override
  Future<UserModel?> readUser() async => null;
  @override
  Future<void> saveUser(UserModel user) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('fetchNotifications (GET /notifications)', () {
    test('gửi đúng path + query phân trang, parse items + meta.has_next', () async {
      final urls = <Uri>[];
      final service = NotificationApiService(ApiClient(
        client: MockClient((req) async {
          urls.add(req.url);
          return okJson(pageJson([
            notificationJson(id: 'n1'),
            notificationJson(
              id: 'n2',
              type: 'price_alert',
              title: 'Cập nhật giá đáng chú ý',
              body: 'Một món bạn đang theo dõi vừa có mức giá tốt.',
              payload: {'route': '/shopping-list'},
            ),
          ], page: 2, total: 42, hasNext: true),
          );
        }),
      ));

      final page = await service.fetchNotifications(page: 2, limit: 20);

      expect(urls.single.path, endsWith('/notifications'));
      expect(urls.single.queryParameters['page'], '2');
      expect(urls.single.queryParameters['limit'], '20');

      expect(page.items.length, 2);
      expect(page.page, 2);
      expect(page.hasNext, isTrue);

      final first = page.items.first;
      expect(first.id, 'n1');
      expect(first.type, 'budget_alert');
      expect(first.read, isFalse);
      expect(first.createdAt, DateTime.parse('2026-09-15T02:00:00.000Z'));

      // Payload map của price alert giữ nguyên để feed deep-link được (AC 12.5).
      expect(page.items.last.payload, {'route': '/shopping-list'});
    });

    test('meta thiếu / body lỗi shape → không crash (defensive)', () async {
      final service = NotificationApiService(ApiClient(
        client: MockClient((req) async => okJson(const {
              'items': null,
              'meta': null,
            })),
      ));

      final page = await service.fetchNotifications();
      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
    });
  });

  group('markRead (PATCH /notifications/:id/read — AC 12.10)', () {
    test('gửi đúng method PATCH + path, body 200 không cần parse', () async {
      final methods = <String>[];
      final paths = <String>[];
      final service = NotificationApiService(ApiClient(
        client: MockClient((req) async {
          methods.add(req.method);
          paths.add(req.url.path);
          return okJson(const {'id': 'n1', 'read': true});
        }),
      ));

      await service.markRead('n1');

      expect(methods, ['PATCH']);
      expect(paths.single, endsWith('/notifications/n1/read'));
    });

    test('BE trả 404 (id không thuộc user) → ném ApiException cho caller nuốt', () async {
      final service = NotificationApiService(ApiClient(
        client: MockClient((req) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'NOTIFICATION_NOT_FOUND',
                  'message': 'not found',
                  'timestamp': '2026-09-15T00:00:00.000Z',
                }
              }),
              404,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      ));

      await expectLater(service.markRead('missing'), throwsException);
    });
  });

  group('AC 12.11 — user-scoped theo JWT (2 tài khoản)', () {
    test('token A và token B gọi cùng endpoint → Authorization khác nhau, '
        'mỗi feed chỉ nhận dữ liệu của user tương ứng', () async {
      // Mock server "user-scoped": dữ liệu trả về phụ thuộc Bearer token.
      Future<http.Response> handler(http.Request req) async {
        final auth = req.headers['authorization'] ?? '';
        final items = auth.contains('token-A')
            ? [notificationJson(id: 'a1', title: 'Của A')]
            : auth.contains('token-B')
                ? [notificationJson(id: 'b1', title: 'Của B')]
                : <Map<String, dynamic>>[];
        return okJson(pageJson(items));
      }

      final clientA = ApiClient(
        client: MockClient(handler),
        storage: _FakeTokenStorage(const AuthTokens(
          accessToken: 'token-A', refreshToken: 'refresh-A')),
      );
      final clientB = ApiClient(
        client: MockClient(handler),
        storage: _FakeTokenStorage(const AuthTokens(
          accessToken: 'token-B', refreshToken: 'refresh-B')),
      );

      final feedA = await NotificationApiService(clientA).fetchNotifications();
      final feedB = await NotificationApiService(clientB).fetchNotifications();

      // Feed của A KHÔNG chứa notification của B và ngược lại (AC 12.11).
      expect(feedA.items.map((n) => n.id), ['a1']);
      expect(feedB.items.map((n) => n.id), ['b1']);
      expect(feedA.items.map((n) => n.id), isNot(contains('b1')));
      expect(feedB.items.map((n) => n.id), isNot(contains('a1')));
    });
  });
}
