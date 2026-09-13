import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/database/daos/price_history_dao.dart';
import 'package:shopsnap/models/price_history_model.dart';
import 'package:shopsnap/services/price_history_api_service.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}

http.Response okJson(dynamic data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PriceHistoryModel Deserialization Tests', () {
    test('PriceHistorySummary.fromJson parse đầy đủ chỉ số và points', () {
      final json = {
        'item_name': 'mì hảo hảo',
        'barcode': '8934567890123',
        'latest_price': 4500,
        'previous_price': 4000,
        'min_price': 3800,
        'max_price': 4500,
        'avg_price': 4100,
        'price_change_percent': 12.5,
        'trend': 'up',
        'total_records': 2,
        'points': [
          {
            'id': 'p-1',
            'price': 4000,
            'purchased_at': '2026-08-10T10:00:00.000Z',
            'store_name': 'WinMart',
          },
          {
            'id': 'p-2',
            'price': 4500,
            'purchased_at': '2026-09-10T10:00:00.000Z',
            'store_name': 'Co.opmart',
          },
        ],
      };

      final summary = PriceHistorySummary.fromJson(json);

      expect(summary.itemName, 'mì hảo hảo');
      expect(summary.barcode, '8934567890123');
      expect(summary.latestPrice, 4500);
      expect(summary.previousPrice, 4000);
      expect(summary.minPrice, 3800);
      expect(summary.maxPrice, 4500);
      expect(summary.avgPrice, 4100);
      expect(summary.priceChangePercent, 12.5);
      expect(summary.trend, PriceTrend.up);
      expect(summary.points.length, 2);
      expect(summary.points[0].storeName, 'WinMart');
    });

    test('FrequentTrackedItem.fromJson parse chính xác', () {
      final json = {
        'item_name': 'Sữa tươi Vinamilk',
        'barcode': '8934673123456',
        'purchase_count': 6,
        'latest_price': 28000,
        'last_purchased_at': '2026-09-12T14:30:00.000Z',
      };

      final item = FrequentTrackedItem.fromJson(json);

      expect(item.itemName, 'Sữa tươi Vinamilk');
      expect(item.purchaseCount, 6);
      expect(item.latestPrice, 28000);
    });
  });

  group('PriceHistoryDao Offline-First Tests', () {
    late MockDatabase mockDb;
    late PriceHistoryDao dao;

    setUp(() {
      mockDb = MockDatabase();
      dao = PriceHistoryDao(mockDb);
    });

    test('getPriceHistory trả về null khi query rỗng', () async {
      final res = await dao.getPriceHistory();
      expect(res, isNull);
    });

    test('getPriceHistory tính toán đúng các mốc giá và xu hướng tăng giá (trend: up)', () async {
      when(() => mockDb.query(
        'price_history',
        where: 'barcode = ?',
        whereArgs: ['8934567890123'],
        orderBy: 'purchased_at DESC',
        limit: 30,
      )).thenAnswer((_) async => [
        {
          'id': 'ph-2',
          'item_name': 'mì hảo hảo',
          'barcode': '8934567890123',
          'price': 4500, // lần mua mới nhất
          'purchased_at': 1726000000000,
        },
        {
          'id': 'ph-1',
          'item_name': 'mì hảo hảo',
          'barcode': '8934567890123',
          'price': 4000, // lần mua trước đó
          'purchased_at': 1725000000000,
        },
      ]);

      final summary = await dao.getPriceHistory(barcode: '8934567890123');

      expect(summary, isNotNull);
      expect(summary!.latestPrice, 4500);
      expect(summary.previousPrice, 4000);
      expect(summary.minPrice, 4000);
      expect(summary.maxPrice, 4500);
      expect(summary.avgPrice, 4250);
      expect(summary.priceChangePercent, 12.5);
      expect(summary.trend, PriceTrend.up);
      expect(summary.points.length, 2);
      expect(summary.points.first.price, 4000); // xếp theo thời gian tăng dần
      expect(summary.points.last.price, 4500);
    });

    test('getPriceHistory phát hiện xu hướng giảm giá (trend: down)', () async {
      when(() => mockDb.query(
        'price_history',
        where: 'item_name LIKE ?',
        whereArgs: ['%trứng gà%'],
        orderBy: 'purchased_at DESC',
        limit: 30,
      )).thenAnswer((_) async => [
        {
          'id': 'ph-2',
          'item_name': 'trứng gà ba huân',
          'price': 28000, // lần mới nhất giảm
          'purchased_at': 1726000000000,
        },
        {
          'id': 'ph-1',
          'item_name': 'trứng gà ba huân',
          'price': 32000, // lần trước đắt hơn
          'purchased_at': 1725000000000,
        },
      ]);

      final summary = await dao.getPriceHistory(name: 'trứng gà');

      expect(summary, isNotNull);
      expect(summary!.latestPrice, 28000);
      expect(summary.previousPrice, 32000);
      expect(summary.priceChangePercent, -12.5);
      expect(summary.trend, PriceTrend.down);
    });
  });

  group('PriceHistoryApiService Cloud Tests', () {
    test('getPriceHistory gọi GET /items/price-history và parse thành công', () async {
      final mockClient = MockClient((req) async {
        expect(req.url.path, endsWith('/items/price-history'));
        expect(req.url.queryParameters['name'], 'vinamilk');
        return okJson({
          'item_name': 'sữa vinamilk',
          'latest_price': 28000,
          'min_price': 28000,
          'max_price': 28000,
          'avg_price': 28000,
          'trend': 'stable',
          'points': [],
        });
      });

      final service = PriceHistoryApiService(ApiClient(client: mockClient));
      final res = await service.getPriceHistory(name: 'vinamilk');

      expect(res, isNotNull);
      expect(res!.itemName, 'sữa vinamilk');
      expect(res.latestPrice, 28000);
      expect(res.trend, PriceTrend.stable);
    });

    test('getFrequentTrackedItems gọi GET /items/price-history/frequent', () async {
      final mockClient = MockClient((req) async {
        expect(req.url.path, endsWith('/items/price-history/frequent'));
        return okJson([
          {
            'item_name': 'bánh mì',
            'purchase_count': 8,
            'latest_price': 15000,
            'last_purchased_at': '2026-09-12T08:00:00.000Z',
          }
        ]);
      });

      final service = PriceHistoryApiService(ApiClient(client: mockClient));
      final items = await service.getFrequentTrackedItems();

      expect(items.length, 1);
      expect(items.first.itemName, 'bánh mì');
      expect(items.first.purchaseCount, 8);
    });
  });
}
