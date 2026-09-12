import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/services/budget_api_service.dart';

/// Wave 4 — BudgetApiService với ApiClient mock (MockClient của package:http).
/// Shape JSON lấy từ curl thật vào backend (create month budget có align ngày,
/// computed fields spent_amount/remaining_amount/spent_percentage...).
http.Response okJson(dynamic data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> budgetJson({
  String id = 'srv-b1',
  String status = 'active',
  int total = 5000000,
  int spent = 104000,
}) => {
  'id': id,
  'name': 'Thang 9 curl test',
  'period_type': 'month',
  'start_date': '2026-09-01',
  'end_date': '2026-09-30',
  'total_amount': total,
  'alert_threshold': 0.8,
  'status': status,
  'is_recurring': false,
  'spent_amount': spent,
  'remaining_amount': total - spent,
  'spent_percentage': spent / total,
  'category_budgets': [
    {
      'id': 'cb1',
      'budget_id': id,
      'category_id': 'cat_food',
      'category': {'id': 'cat_food', 'name': 'Ăn uống', 'color': '#FF6B6B', 'icon': '🍜'},
      'allocated_amount': 2000000,
      'spent_amount': 32000,
      'remaining_amount': 1968000,
      'spent_percentage': 0.016,
    }
  ],
  'created_at': '2026-09-12T20:40:06.720Z',
  'updated_at': '2026-09-12T20:40:06.720Z',
  'deleted_at': null,
};

void main() {
  setUpAll(() async {
    // TokenStorage mặc định dùng SharedPreferences → cần mock trong unit test
    SharedPreferences.setMockInitialValues({});
  });

  group('list (GET /budgets)', () {
    test('gửi đúng query params + parse items', () async {
      final urls = <Uri>[];
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        urls.add(req.url);
        return okJson({'items': [budgetJson()], 'meta': {'total': 1}});
      })));

      final items = await service.list(
        status: 'active',
        periodType: 'month',
        date: '2026-09-13',
      );

      expect(urls.single.path, endsWith('/budgets'));
      expect(urls.single.queryParameters['status'], 'active');
      expect(urls.single.queryParameters['period_type'], 'month');
      expect(urls.single.queryParameters['date'], '2026-09-13');
      expect(urls.single.queryParameters['include_deleted'], 'false');

      expect(items.single.id, 'srv-b1');
      expect(items.single.amount, 5000000);
      expect(items.single.spentAmount, 104000);
    });

    test('không truyền filter → query chỉ có include_deleted', () async {
      Uri? captured;
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        captured = req.url;
        return okJson({'items': [], 'meta': {}});
      })));

      final items = await service.list();

      expect(captured!.queryParameters.containsKey('status'), isFalse);
      expect(captured!.queryParameters.containsKey('date'), isFalse);
      expect(items, isEmpty);
    });
  });

  group('current (GET /budgets/current)', () {
    test('parse list + days_remaining/projected_overage chỉ có ở /current', () async {
      final urls = <Uri>[];
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        urls.add(req.url);
        return okJson([
          {...budgetJson(), 'days_remaining': 17, 'projected_overage': null},
        ]);
      })));

      final items = await service.current();

      expect(urls.single.path, endsWith('/budgets/current'));
      expect(items.single.daysRemaining, 17);
      expect(items.single.projectedOverage, isNull);
      expect(items.single.startDate, '2026-09-01'); // server đã align
    });
  });

  group('create (POST /budgets)', () {
    test('body snake_case + category_budgets lồng đúng shape', () async {
      final bodies = <Map<String, dynamic>>[];
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        // Server trả ngày đã align (start 2026-09-05 gửi đi → 2026-09-01)
        return okJson(budgetJson(), status: 201);
      })));

      final created = await service.create(const BudgetPayload(
        name: 'Tháng 9 2026',
        periodType: 'month',
        startDate: '2026-09-05',
        endDate: '2026-09-25',
        totalAmount: 5000000,
        alertThreshold: 0.8,
        categoryBudgets: [
          CategoryBudgetPayload(categoryId: 'cat_food', allocatedAmount: 2000000),
        ],
      ));

      expect(bodies.single['name'], 'Tháng 9 2026');
      expect(bodies.single['period_type'], 'month');
      expect(bodies.single['start_date'], '2026-09-05');
      expect(bodies.single['total_amount'], 5000000);
      expect((bodies.single['category_budgets'] as List).single,
          {'category_id': 'cat_food', 'allocated_amount': 2000000});

      expect(created.id, 'srv-b1');
      expect(created.startDate, '2026-09-01'); // ngày đã căn từ response
      expect(created.endDate, '2026-09-30');
      expect(created.categoryId, 'cat_food'); // 1 dòng → map về categoryId
    });

    test('409 BUDGET_OVERLAP → ApiException giữ nguyên code', () async {
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'BUDGET_OVERLAP',
              'message': "Khoảng ngày giao với budget 'X' (2026-09-01 → 2026-09-30) cùng period_type.",
              'timestamp': '2026-09-12T20:40:26.509Z',
            },
          }),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      })));

      expect(
        () => service.create(const BudgetPayload(
          name: 'Overlap',
          periodType: 'month',
          startDate: '2026-09-10',
          endDate: '2026-09-10',
          totalAmount: 100000,
        )),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'BUDGET_OVERLAP')
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('getById / update / delete / alerts', () {
    test('getById parse budget detail', () async {
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        expect(req.url.path, endsWith('/budgets/srv-b1'));
        return okJson(budgetJson());
      })));

      final b = await service.getById('srv-b1');
      expect(b.name, 'Thang 9 curl test');
    });

    test('update dùng PATCH, chỉ gửi field truyền vào; pause → {status}', () async {
      final methods = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        methods.add(req.method);
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return okJson(budgetJson(total: 8000000));
      })));

      final updated = await service.update('srv-b1', totalAmount: 8000000);
      expect(updated.amount, 8000000);

      await service.update('srv-b1', status: 'paused');

      expect(methods, ['PATCH', 'PATCH']);
      expect(bodies[0].keys.toSet(), {'total_amount'});
      expect(bodies[1], {'status': 'paused'});
    });

    test('delete 204 body rỗng → hoàn tất không ném', () async {
      String? method;
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        method = req.method;
        return http.Response('', 204);
      })));

      await service.delete('srv-b1');
      expect(method, 'DELETE');
    });

    test('alerts parse shape backend (triggered_at ISO, acknowledged_at null)', () async {
      final service = BudgetApiService(ApiClient(client: MockClient((req) async {
        expect(req.url.path, endsWith('/budgets/srv-b1/alerts'));
        return okJson([
          {
            'id': 'al1',
            'budget_id': 'srv-b1',
            'type': 'threshold_reached',
            'threshold_percentage': 0.8,
            'spent_amount': 4000000,
            'total_amount': 5000000,
            'category_id': null,
            'triggered_at': '2026-09-12T21:00:00.000Z',
            'acknowledged_at': null,
          }
        ]);
      })));

      final alerts = await service.alerts('srv-b1');
      expect(alerts.single.type, 'threshold_reached');
      expect(alerts.single.thresholdPercentage, 0.8);
      expect(alerts.single.spentAmount, 4000000);
      expect(alerts.single.acknowledgedAt, isNull);
    });
  });
}
