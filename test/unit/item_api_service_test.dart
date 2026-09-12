import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/services/item_api_service.dart';

/// Wave 3 — ItemApiService với ApiClient mock (MockClient của package:http).
/// Chạy logic tầng data thật: envelope unwrap, query params, mapping lỗi
/// 409/404 theo shape backend đã verify bằng curl.
///
/// LƯU Ý: http.Response(String) mặc định latin1 khi không có content-type
/// json trong headers — body tiếng Việt ('Sữa', 'Không lâu'...) làm encoder
/// ném lỗi ngay trong handler mock → ApiClient biến thành NETWORK_ERROR.
/// Header 'application/json; charset=utf-8' vừa ép encode utf8 vừa để
/// `res.body` decode ngược đúng utf8.
http.Response okJson(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> itemJson({
  String id = 'srv-1',
  String name = 'Sữa',
  int price = 28000,
}) => {
  'id': id, 'name': name, 'price': price, 'quantity': 1, 'unit': null,
  'total_price': price, 'category_id': 'cat_other',
  'category': {'id': 'cat_other', 'name': 'Khác', 'color': '#DDA0DD', 'icon': '📦'},
  'image_url': null, 'image_thumbnail_url': null, 'note': null,
  'store_name': null, 'location': null,
  'purchase_date': '2026-09-12T10:00:00.000Z', 'source': 'manual',
  'barcode': null, 'created_at': '2026-09-12T10:00:00.000Z',
  'updated_at': '2026-09-12T10:00:00.000Z', 'deleted_at': null,
};

void main() {
  setUpAll(() async {
    // TokenStorage mặc định dùng SharedPreferences → cần mock trong unit test
    SharedPreferences.setMockInitialValues({});
  });

  group('fetchItems (GET /items)', () {
    test('gửi đúng query params + parse { items, meta }', () async {
      final urls = <Uri>[];
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        urls.add(req.url);
        return okJson({
          'items': [itemJson()],
          'meta': {
            'total': 1, 'page': 2, 'limit': 100,
            'total_pages': 1, 'has_next': false, 'has_prev': true,
          },
        });
      })));

      final page = await service.fetchItems(
        page: 2,
        dateFrom: DateTime(2026, 9, 12),
        dateTo: DateTime(2026, 9, 12, 23, 59, 59, 999),
        sort: 'purchase_date',
        order: 'desc',
        limit: 100,
      );

      // path gồm cả prefix /api/v1 của ApiConfig.baseUrl → dùng endsWith
      expect(urls.single.path, endsWith('/items'));
      expect(urls.single.queryParameters['page'], '2');
      expect(urls.single.queryParameters['limit'], '100');
      expect(urls.single.queryParameters['sort'], 'purchase_date');
      expect(urls.single.queryParameters['order'], 'desc');
      expect(urls.single.queryParameters['include_deleted'], 'false');
      // Ngày local → gửi ISO UTC (backend dùng nguyên instant, khỏi lệ timezone server)
      expect(urls.single.queryParameters['date_from']!.endsWith('Z'), isTrue);

      expect(page.items.single.name, 'Sữa');
      expect(page.items.single.totalPrice, 28000);
      expect(page.meta.total, 1);
      expect(page.meta.page, 2);
      expect(page.meta.limit, 100);
      expect(page.meta.hasNext, isFalse);
      expect(page.meta.hasPrev, isTrue);
    });

    test('bỏ filter null, search/category_id được truyền khi có', () async {
      Uri? captured;
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        captured = req.url;
        return okJson({'items': [], 'meta': {}});
      })));

      await service.fetchItems(categoryId: 'cat_food', search: 'sua');

      expect(captured!.queryParameters.containsKey('sort'), isFalse);
      expect(captured!.queryParameters.containsKey('date_from'), isFalse);
      expect(captured!.queryParameters['category_id'], 'cat_food');
      expect(captured!.queryParameters['search'], 'sua');
    });
  });

  group('create (POST /items)', () {
    test('body snake_case + purchase_date ISO UTC; force=true → query', () async {
      final bodies = <Map<String, dynamic>>[];
      final urls = <Uri>[];
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        urls.add(req.url);
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return okJson(itemJson());
      })));

      final item = await service.create(const ItemPayload(
        name: 'Sữa',
        price: 28000,
        note: 'nt',
      ), force: true);

      expect(urls.single.path, endsWith('/items'));
      expect(urls.single.queryParameters['force'], 'true');
      expect(bodies.single['name'], 'Sữa');
      expect(bodies.single['price'], 28000);
      expect(bodies.single['note'], 'nt');
      expect(bodies.single.containsKey('category_id'), isFalse); // auto-classify
      expect((bodies.single['purchase_date'] as String).endsWith('Z'), isTrue);

      expect(item.id, 'srv-1');
      expect(item.totalPrice, 28000);
      expect(item.isSynced, isTrue);
    });

    test('409 ITEM_DUPLICATE → ApiException giữ nguyên code + status', () async {
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'ITEM_DUPLICATE',
              'message': 'Có vẻ bạn đã thêm sản phẩm này cách đây không lâu. Thêm lại?',
              'existing_item_id': '000c1588',
              'created_at': '2026-09-12T19:59:03.491Z',
              'timestamp': '2026-09-12T19:59:03.614Z',
            },
          }),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      })));

      expect(
        () => service.create(const ItemPayload(name: 'Sữa', price: 28000)),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ITEM_DUPLICATE')
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('getById / update / delete', () {
    test('getById 404 ITEM_NOT_FOUND → ApiException', () async {
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'ITEM_NOT_FOUND',
              'message': "Item with id 'x' does not exist.",
              'timestamp': '2026-09-12T20:00:00.000Z',
            },
          }),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      })));

      expect(
        () => service.getById('x'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ITEM_NOT_FOUND')
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('update dùng PATCH, chỉ gửi field truyền vào, không gửi source', () async {
      String? method;
      Map<String, dynamic>? body;
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        method = req.method;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return okJson(itemJson(price: 30000));
      })));

      final item = await service.update('srv-1', price: 30000);

      expect(method, 'PATCH');
      expect(body!.keys.toSet(), {'price'}); // source bất biến — không có param
      expect(item.price, 30000);
      expect(item.totalPrice, 30000); // server đã recompute
    });

    test('delete 204 body rỗng → hoàn tất không ném', () async {
      String? method;
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        method = req.method;
        return http.Response('', 204);
      })));

      await service.delete('srv-1');
      expect(method, 'DELETE');
    });
  });

  group('bulkCreate (POST /items/bulk)', () {
    test('parse shape partial failure: created + failed + meta', () async {
      Map<String, dynamic>? body;
      final service = ItemApiService(ApiClient(client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return okJson({
          'created': [itemJson(id: 'b1', name: 'Bulk ok', price: 12000)],
          'failed': [{
            'index': 1,
            'input': {'name': 'Bulk bad cat', 'price': 5000, 'category_id': 'cat_khong_ton_tai'},
            'error': {'code': 'ITEM_INVALID_CATEGORY', 'message': "Category 'cat_khong_ton_tai' does not exist."},
          }],
          'meta': {'total_submitted': 2, 'total_created': 1, 'total_failed': 1},
        });
      })));

      final result = await service.bulkCreate([
        const ItemPayload(name: 'Bulk ok', price: 12000),
        const ItemPayload(name: 'Bulk bad cat', price: 5000, categoryId: 'cat_khong_ton_tai'),
      ], storeName: 'Circle K');

      expect((body!['items'] as List).length, 2);
      expect(body!['store_name'], 'Circle K');

      expect(result.created.single.id, 'b1');
      expect(result.failed.single.index, 1);
      expect(result.failed.single.code, 'ITEM_INVALID_CATEGORY');
      expect(result.failed.single.input?['price'], 5000);
      expect(result.totalSubmitted, 2);
      expect(result.totalCreated, 1);
      expect(result.totalFailed, 1);
    });

    test('ItemPayload.toJson: chỉ field non-null, location lồng đúng shape', () {
      final json = const ItemPayload(
        name: 'Trứng',
        price: 30000,
        quantity: 2,
        categoryId: 'cat_food',
        barcode: '8934673123456',
        location: ItemLocation(latitude: 10.7, longitude: 106.7, accuracyMeters: 12),
      ).toJson();

      expect(json.keys.toSet(),
          {'name', 'price', 'quantity', 'category_id', 'barcode', 'location', 'purchase_date'});
      expect(json['quantity'], 2);
      expect(json['location'], {'latitude': 10.7, 'longitude': 106.7, 'accuracy_meters': 12});
      expect((json['purchase_date'] as String).endsWith('Z'), isTrue);
    });
  });
}
