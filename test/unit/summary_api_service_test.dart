import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/models/summary_model.dart';
import 'package:shopsnap/providers/summary_provider.dart';
import 'package:shopsnap/services/summary_api_service.dart';

/// Wave 5 — SummaryApiService + mapper `SummaryModel.fromApiJson` với ApiClient
/// mock (MockClient của package:http). Payload khớp shape đã verify bằng curl:
/// breakdown category có object `category` lồng, budget/comparison có field null.
///
/// LƯU Ý: http.Response(String) mặc định latin1 khi không khai báo charset —
/// body tiếng Việt ('Cà phê', 'Ăn uống'...) làm encoder ném lỗi ngay trong
/// handler mock → luôn gửi kèm header '...; charset=utf-8'.
http.Response okJson(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response errorJson(String code, String message, {int status = 400}) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': message, 'timestamp': '2026-09-13T00:00:00.000Z'},
      }),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Shape GET /summary?period=month&group_by=category (curl 2026-09-13).
Map<String, dynamic> summaryDataJson({bool withBudget = false}) => {
  'period': {
    'type': 'month', 'start_date': '2026-09-01', 'end_date': '2026-09-30',
    'label': 'Tháng 9, 2026',
  },
  'totals': {
    'total_spent': 104000, 'total_items': 3, 'total_transactions': 2,
    'average_per_day': 3467, 'average_per_transaction': 52000,
  },
  'budget': withBudget
      ? {
          'budget_id': 'b67224b1', 'name': 'Wave4 tiny', 'total_amount': 1000,
          'remaining_amount': 1000, 'spent_percentage': 0, 'status': 'active',
          'alert_threshold': 0.8, 'days_remaining': 48, 'projected_overage': null,
        }
      : null,
  'comparison': {
    'previous_period_spent': 104000, 'change_amount': -104000,
    'change_percentage': -100, 'trend': 'down',
  },
  'breakdown': [
    {
      'category_id': 'cat_other',
      'category': {'id': 'cat_other', 'name': 'Khác', 'color': '#DDA0DD', 'icon': '📦'},
      'total_spent': 72000, 'item_count': 2, 'percentage_of_total': 69.23,
      'budget_allocated': null, 'budget_remaining': null, 'budget_percentage': null,
    },
    {
      'category_id': 'cat_food',
      'category': {'id': 'cat_food', 'name': 'Ăn uống', 'color': '#FF6B6B', 'icon': '🍜'},
      'total_spent': 32000, 'item_count': 1, 'percentage_of_total': 30.77,
      'budget_allocated': 40000, 'budget_remaining': 8000, 'budget_percentage': 80.0,
    },
  ],
};

const csvBody = '\uFEFFid,name,price,quantity,unit,total_price,category_name,store_name,purchase_date,note,source\r\n'
    '000c1588,Cà phê sữa đậm test,30000,2,,60000,Khác,,2026-09-12T19:59:03.000Z,da sua gia,manual';

void main() {
  setUpAll(() async {
    // TokenStorage mặc định dùng SharedPreferences → cần mock trong unit test
    SharedPreferences.setMockInitialValues({});
  });

  group('summary (GET /summary)', () {
    test('gửi đúng query params + parse payload (budget + comparison + breakdown)', () async {
      final urls = <Uri>[];
      final service = SummaryApiService(ApiClient(client: MockClient((req) async {
        urls.add(req.url);
        return okJson(summaryDataJson(withBudget: true));
      })));

      final res = await service.summary(
        period: 'month', date: '2026-09-13', groupBy: 'category',
      );

      expect(urls.single.path, endsWith('/summary'));
      expect(urls.single.queryParameters['period'], 'month');
      expect(urls.single.queryParameters['date'], '2026-09-13');
      expect(urls.single.queryParameters['group_by'], 'category');

      // period
      expect(res.period.type, 'month');
      expect(res.period.startDate, '2026-09-01');
      expect(res.period.endDate, '2026-09-30');
      expect(res.period.label, 'Tháng 9, 2026');
      // totals
      expect(res.totals.totalSpent, 104000);
      expect(res.totals.totalItems, 3);
      expect(res.totals.totalTransactions, 2);
      expect(res.totals.averagePerDay, 3467);
      expect(res.totals.averagePerTransaction, 52000);
      // budget (projected_overage null trên server)
      expect(res.budget, isNotNull);
      expect(res.budget!.budgetId, 'b67224b1');
      expect(res.budget!.totalAmount, 1000);
      expect(res.budget!.spentPercentage, 0);
      expect(res.budget!.daysRemaining, 48);
      expect(res.budget!.projectedOverage, isNull);
      // comparison
      expect(res.comparison.previousPeriodSpent, 104000);
      expect(res.comparison.changePercentage, -100);
      expect(res.comparison.trend, 'down');
      // breakdown category — object `category` lồng
      expect(res.breakdown.length, 2);
      expect(res.breakdown.first.categoryId, 'cat_other');
      expect(res.breakdown.first.categoryName, 'Khác');
      expect(res.breakdown.first.categoryColor, '#DDA0DD');
      expect(res.breakdown.first.totalSpent, 72000);
      expect(res.breakdown.first.percentageOfTotal, 69.23);
      expect(res.breakdown[1].budgetAllocated, 40000);
      expect(res.breakdown[1].budgetRemaining, 8000);
    });

    test('bỏ param null (không date/group_by khi không truyền)', () async {
      Uri? captured;
      final service = SummaryApiService(ApiClient(client: MockClient((req) async {
        captured = req.url;
        return okJson(summaryDataJson()..remove('breakdown'));
      })));

      final res = await service.summary(period: 'day');

      expect(captured!.queryParameters.containsKey('date'), isFalse);
      expect(captured!.queryParameters.containsKey('date_from'), isFalse);
      expect(captured!.queryParameters.containsKey('group_by'), isFalse);
      expect(res.breakdown, isEmpty);
    });

    test('400 SUMMARY_DATE_RANGE_TOO_LARGE → ApiException giữ nguyên code', () async {
      final service = SummaryApiService(ApiClient(client: MockClient((req) async {
        return errorJson('SUMMARY_DATE_RANGE_TOO_LARGE', 'Tối đa 366 ngày.');
      })));

      expect(
        () => service.summary(
          period: 'custom', dateFrom: '2025-01-01', dateTo: '2026-09-13',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'SUMMARY_DATE_RANGE_TOO_LARGE')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('insights (GET /summary/insights)', () {
    test('parse danh sách insight + param period/date', () async {
      Uri? captured;
      final service = SummaryApiService(ApiClient(client: MockClient((req) async {
        captured = req.url;
        return okJson({
          'insights': [
            {
              'type': 'best_day', 'severity': 'positive',
              'title': 'Ngày tiết kiệm nhất',
              'message': 'Bạn chi tiêu ít nhất vào Saturday (trung bình 3000đ/ngày).',
              'data': {'day_of_week': 'Saturday', 'average_spend': 3000},
            },
            {
              'type': 'budget_warning', 'severity': 'warning',
              'title': 'Ngân sách sắp hết',
              'message': "Bạn đã dùng 80% ngân sách 'Ngân sách tháng 09/2026'.",
              'data': {'budget_id': 'b1', 'spent_percentage': 0.8},
            },
          ],
        });
      })));

      final insights = await service.insights(date: '2026-09-13', period: 'week');

      expect(captured!.path, endsWith('/summary/insights'));
      expect(captured!.queryParameters['period'], 'week');
      expect(captured!.queryParameters['date'], '2026-09-13');

      expect(insights.length, 2);
      expect(insights.first.type, 'best_day');
      expect(insights.first.severity, 'positive');
      expect(insights.first.title, 'Ngày tiết kiệm nhất');
      expect(insights.first.data['average_spend'], 3000);
      expect(insights.last.severity, 'warning');
    });

    test('insights rỗng → list rỗng, không ném', () async {
      final service = SummaryApiService(ApiClient(client: MockClient((req) async {
        return okJson({'insights': []});
      })));

      expect(await service.insights(), isEmpty);
    });
  });

  group('exportCsv (GET /summary/export?format=csv)', () {
    test('trả body CSV thô (giữ BOM + tiếng Việt), không unwrap envelope', () async {
      Uri? captured;
      final service = SummaryApiService(
        ApiClient(client: MockClient((req) async => fail('không dùng ApiClient'))),
        // exportCsv đi qua client http riêng (body text/csv không parse được JSON)
        httpClient: MockClient((req) async {
          captured = req.url;
          return http.Response(csvBody, 200,
              headers: {'content-type': 'text/csv; charset=utf-8'});
        }),
      );

      final csv = await service.exportCsv(dateFrom: '2026-09-01', dateTo: '2026-09-30');

      expect(captured!.path, endsWith('/summary/export'));
      expect(captured!.queryParameters['format'], 'csv');
      expect(captured!.queryParameters['date_from'], '2026-09-01');
      expect(captured!.queryParameters['date_to'], '2026-09-30');
      expect(captured!.queryParameters['include'], 'items');

      expect(csv.startsWith('\uFEFF'), isTrue); // UTF-8 BOM cho Excel
      expect(csv, contains('Cà phê sữa đậm test'));
      expect(csv, isNot(contains('success')));
    });

    test('401 → refresh đúng 1 lần rồi retry, token mới được persist', () async {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'expired-a', 'auth_refresh_token': 'old-r',
      });

      var exportCalls = 0;
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return okJson({'accessToken': 'new-a', 'refreshToken': 'new-r'});
        }
        exportCalls++;
        if (exportCalls == 1) {
          return http.Response(
              jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}), 401,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        // Retry phải mang token mới sau refresh
        expect(req.headers['Authorization'], 'Bearer new-a');
        return http.Response(csvBody, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final client  = ApiClient(client: mock);
      final service = SummaryApiService(client, httpClient: mock);

      final csv = await service.exportCsv(dateFrom: '2026-09-01', dateTo: '2026-09-30');

      expect(exportCalls, 2);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect((await client.storage.readTokens())!.accessToken, 'new-a');
    });

    test('400 SUMMARY_DATE_RANGE_TOO_LARGE → ApiException giữ nguyên code', () async {
      final service = SummaryApiService(
        ApiClient(client: MockClient((req) async => fail('không dùng ApiClient'))),
        httpClient: MockClient((req) async {
          return errorJson('SUMMARY_DATE_RANGE_TOO_LARGE', 'Tối đa 366 ngày.');
        }),
      );

      expect(
        () => service.exportCsv(dateFrom: '2025-01-01', dateTo: '2026-09-13'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'SUMMARY_DATE_RANGE_TOO_LARGE')),
      );
    });
  });

  group('exportJson (GET /summary/export?format=json)', () {
    test('parse data.items từ envelope', () async {
      Uri? captured;
      final service = SummaryApiService(ApiClient(client: MockClient((req) async {
        captured = req.url;
        return okJson({
          'items': [
            {
              'id': 'i1', 'name': 'Cà phê sữa đậm test', 'price': 30000,
              'quantity': 2, 'unit': null, 'total_price': 60000,
              'category_id': 'cat_other', 'category_name': 'Khác',
              'store_name': null, 'purchase_date': '2026-09-12T19:59:03.000Z',
              'note': 'da sua gia', 'source': 'manual',
            },
          ],
        });
      })));

      final data = await service.exportJson(
        dateFrom: '2026-09-01', dateTo: '2026-09-30', include: 'items,categories,budgets',
      );

      expect(captured!.queryParameters['format'], 'json');
      expect(captured!.queryParameters['include'], 'items,categories,budgets');
      final items = (data['items'] as List).cast<Map>();
      expect(items.single['name'], 'Cà phê sữa đậm test');
      expect(items.single['total_price'], 60000);
    });
  });

  group('SummaryModel.fromApiJson (mapper sang shape UI đang đọc)', () {
    test('totals + breakdown category → CategorySummary (icon/color cho pie chart)', () {
      final model = SummaryModel.fromApiJson(
        summaryDataJson(),
        date: DateTime(2026, 9, 13),
        items: const [],
      );

      expect(model.date, DateTime(2026, 9, 13));
      expect(model.totalSpent, 104000); // totals.total_spent
      expect(model.itemCount, 3);       // totals.total_items
      expect(model.categories.length, 2);
      expect(model.categories.first.categoryId, 'cat_other');
      expect(model.categories.first.categoryName, 'Khác');
      expect(model.categories.first.categoryIcon, '📦');
      expect(model.categories.first.categoryColor, '#DDA0DD');
      expect(model.categories.first.totalSpent, 72000);
      expect(model.categories.first.itemCount, 2);
    });

    test('constructor local + empty không đổi (fallback offline còn nguyên)', () {
      final empty = SummaryModel.empty(DateTime(2026, 9, 13));
      expect(empty.totalSpent, 0);
      expect(empty.itemCount, 0);
      expect(empty.categories, isEmpty);
      expect(empty.items, isEmpty);
    });

    test('SummaryResponse parse biến thể breakdown day (group_by=day)', () {
      final res = SummaryResponse.fromJson({
        'period': {'type': 'month', 'start_date': '2026-09-01', 'end_date': '2026-09-30', 'label': 'Tháng 9, 2026'},
        'totals': {'total_spent': 104000, 'total_items': 3, 'total_transactions': 2, 'average_per_day': 3467, 'average_per_transaction': 52000},
        'budget': null,
        'comparison': {'previous_period_spent': 0, 'change_amount': 104000, 'change_percentage': null, 'trend': 'up'},
        'breakdown': [
          {'date': '2026-09-12', 'total_spent': 12000, 'item_count': 1},
          {'date': '2026-09-13', 'total_spent': 92000, 'item_count': 2},
        ],
      });

      expect(res.budget, isNull);
      expect(res.comparison.changePercentage, isNull); // kỳ trước 0đ → server trả null
      expect(res.comparison.trend, 'up');
      expect(res.breakdown.length, 2);
      expect(res.breakdown.first.date, '2026-09-12');
      expect(res.breakdown.first.totalSpent, 12000);
      // toSummaryModel lọc bỏ entry không có category (biến thể day)
      expect(res.toSummaryModel(date: DateTime(2026, 9, 13)).categories, isEmpty);
      expect(res.toSummaryModel(date: DateTime(2026, 9, 13)).totalSpent, 104000);
    });
  });

  group('SummaryParams / shiftDateByPeriod (key + căn kỳ như server)', () {
    test('localRange: week T2–CN, month đầu–cuối, year cả năm — khớp curl server', () {
      // 2026-09-13 là CN → server trả tuần 2026-09-07 → 2026-09-13
      final week = SummaryParams(date: DateTime(2026, 9, 13), period: 'week').localRange;
      expect(week.$1, DateTime(2026, 9, 7));
      expect(week.$2, DateTime(2026, 9, 13));

      final month = SummaryParams(date: DateTime(2026, 9, 13), period: 'month').localRange;
      expect(month.$1, DateTime(2026, 9, 1));
      expect(month.$2, DateTime(2026, 9, 30));

      final year = SummaryParams(date: DateTime(2026, 9, 13), period: 'year').localRange;
      expect(year.$1, DateTime(2026, 1, 1));
      expect(year.$2, DateTime(2026, 12, 31));

      final day = SummaryParams(date: DateTime(2026, 9, 13), period: 'day').localRange;
      expect(day.$1, DateTime(2026, 9, 13));
      expect(day.$2, DateTime(2026, 9, 13));
    });

    test('shiftDateByPeriod kẹp ngày cuối tháng/năm nhuận', () {
      expect(shiftDateByPeriod(DateTime(2026, 3, 31), 'month', 1), DateTime(2026, 4, 30));
      expect(shiftDateByPeriod(DateTime(2024, 2, 29), 'year', -1), DateTime(2023, 2, 28));
      expect(shiftDateByPeriod(DateTime(2026, 9, 13), 'week', 1), DateTime(2026, 9, 20));
      expect(shiftDateByPeriod(DateTime(2026, 9, 13), 'day', -1), DateTime(2026, 9, 12));
    });

    test('==/hashCode theo kỳ + ngày (bỏ qua giờ), fmt chuẩn YYYY-MM-DD', () {
      final a = SummaryParams(date: DateTime(2026, 9, 13, 10, 30), period: 'day');
      final b = SummaryParams(date: DateTime(2026, 9, 13), period: 'day');
      final c = SummaryParams(date: DateTime(2026, 9, 13), period: 'month');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.apiDate, '2026-09-13');
      expect(SummaryParams.fmt(DateTime(2026, 9, 3)), '2026-09-03');
    });
  });
}
