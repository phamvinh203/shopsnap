import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/database/daos/barcode_cache_dao.dart';
import 'package:shopsnap/services/barcode_service.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}
class MockBarcodeCacheDao extends Mock implements BarcodeCacheDao {}

void main() {
  setUpAll(() {
    registerFallbackValue(const BarcodeResult(
      barcode: '',
      productName: '',
      categoryId: '',
      source: BarcodeSource.notFound,
    ));
  });

  late MockDatabase mockDb;
  late BarcodeCacheDao cacheDao;

  setUp(() {
    mockDb = MockDatabase();
    cacheDao = BarcodeCacheDao(mockDb);
  });

  group('BarcodeCacheDao Tests', () {
    test('findByBarcode trả về kết quả từ bảng barcode_cache nếu có (Tier 1)', () async {
      when(() => mockDb.query(
        'barcode_cache',
        where: 'barcode = ?',
        whereArgs: ['8934567890123'],
        limit: 1,
      )).thenAnswer((_) async => [
        {
          'barcode': '8934567890123',
          'product_name': 'Mì Hảo Hảo Tôm Chua Cay',
          'brand': 'Acecook',
          'category_id': 'cat_food',
          'image_url': 'https://example.com/haohao.jpg',
          'cached_at': 1726000000000,
        }
      ]);

      final result = await cacheDao.findByBarcode('8934567890123');

      expect(result, isNotNull);
      expect(result!.productName, 'Mì Hảo Hảo Tôm Chua Cay');
      expect(result.brand, 'Acecook');
      expect(result.categoryId, 'cat_food');
      expect(result.source, BarcodeSource.localHistory);
      verify(() => mockDb.query(
        'barcode_cache',
        where: 'barcode = ?',
        whereArgs: ['8934567890123'],
        limit: 1,
      )).called(1);
      verifyNever(() => mockDb.query('price_history', where: any(named: 'where'), whereArgs: any(named: 'whereArgs')));
    });

    test('findByBarcode fallback sang price_history nếu chưa có trong barcode_cache và tự lưu vào cache', () async {
      when(() => mockDb.query(
        'barcode_cache',
        where: 'barcode = ?',
        whereArgs: ['8930001112223'],
        limit: 1,
      )).thenAnswer((_) async => []);

      when(() => mockDb.query(
        'price_history',
        where: 'barcode = ?',
        whereArgs: ['8930001112223'],
        orderBy: 'purchased_at DESC',
        limit: 1,
      )).thenAnswer((_) async => [
        {
          'barcode': '8930001112223',
          'item_name': 'Sữa đặc Ông Thọ',
          'category_id': 'cat_food',
          'purchased_at': 1725900000000,
        }
      ]);

      when(() => mockDb.insert(
        'barcode_cache',
        any(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      )).thenAnswer((_) async => 1);

      final result = await cacheDao.findByBarcode('8930001112223');

      expect(result, isNotNull);
      expect(result!.productName, 'Sữa đặc Ông Thọ');
      expect(result.source, BarcodeSource.localHistory);

      verify(() => mockDb.insert(
        'barcode_cache',
        any(that: predicate<Map<String, dynamic>>((map) =>
          map['barcode'] == '8930001112223' &&
          map['product_name'] == 'Sữa đặc Ông Thọ' &&
          map['category_id'] == 'cat_food')),
        conflictAlgorithm: ConflictAlgorithm.replace,
      )).called(1);
    });

    test('findByBarcode trả về null nếu không tìm thấy trong cả 2 bảng', () async {
      when(() => mockDb.query(
        'barcode_cache',
        where: 'barcode = ?',
        whereArgs: ['0000000000000'],
        limit: 1,
      )).thenAnswer((_) async => []);

      when(() => mockDb.query(
        'price_history',
        where: 'barcode = ?',
        whereArgs: ['0000000000000'],
        orderBy: 'purchased_at DESC',
        limit: 1,
      )).thenAnswer((_) async => []);

      final result = await cacheDao.findByBarcode('0000000000000');
      expect(result, isNull);
    });

    test('insertOrUpdate gọi db.insert với ConflictAlgorithm.replace', () async {
      when(() => mockDb.insert(
        'barcode_cache',
        any(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      )).thenAnswer((_) async => 1);

      const barcodeResult = BarcodeResult(
        barcode: '8934567890123',
        productName: 'Nước khoáng Lavie 500ml',
        brand: 'Lavie',
        categoryId: 'cat_beverage',
        imageUrl: 'https://example.com/lavie.png',
        source: BarcodeSource.openFoodFacts,
      );

      await cacheDao.insertOrUpdate(barcodeResult);

      verify(() => mockDb.insert(
        'barcode_cache',
        any(that: predicate<Map<String, dynamic>>((map) =>
          map['barcode'] == '8934567890123' &&
          map['product_name'] == 'Nước khoáng Lavie 500ml' &&
          map['brand'] == 'Lavie' &&
          map['category_id'] == 'cat_beverage' &&
          map['image_url'] == 'https://example.com/lavie.png' &&
          map.containsKey('cached_at'))),
        conflictAlgorithm: ConflictAlgorithm.replace,
      )).called(1);
    });

    test('clearAll gọi db.delete trên bảng barcode_cache', () async {
      when(() => mockDb.delete('barcode_cache')).thenAnswer((_) async => 5);

      final count = await cacheDao.clearAll();
      expect(count, 5);
      verify(() => mockDb.delete('barcode_cache')).called(1);
    });
  });

  group('BarcodeService 3-Tier Lookup Tests', () {
    late MockBarcodeCacheDao mockCacheDao;

    setUp(() {
      mockCacheDao = MockBarcodeCacheDao();
    });

    test('Barcode rỗng hoặc chỉ có khoảng trắng → return null ngay', () async {
      final r1 = await BarcodeService.lookup('');
      final r2 = await BarcodeService.lookup('   ');
      expect(r1, isNull);
      expect(r2, isNull);
    });

    test('Tier 1: Trả về kết quả ngay lập tức khi cache hit, không gọi HTTP', () async {
      const cached = BarcodeResult(
        barcode: '8935024130016',
        productName: 'Bút bi Bến Nghé',
        brand: 'Bến Nghé',
        categoryId: 'cat_stationery',
        source: BarcodeSource.localHistory,
      );

      when(() => mockCacheDao.findByBarcode('8935024130016'))
          .thenAnswer((_) async => cached);

      final result = await BarcodeService.lookup('8935024130016', cacheDao: mockCacheDao);

      expect(result, isNotNull);
      expect(result!.productName, 'Bút bi Bến Nghé');
      expect(result.source, BarcodeSource.localHistory);
      verify(() => mockCacheDao.findByBarcode('8935024130016')).called(1);
      verifyNever(() => mockCacheDao.insertOrUpdate(any()));
    });
  });
}
