import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/models/item_model.dart';

/// Wave 3 — mapping JSON backend (snake_case) ↔ ItemModel.
/// Shape JSON chuẩn từ items.service.ts `toResponse` (đã verify bằng curl).
Map<String, dynamic> fullItemJson() => {
  'id': '000c1588-8cdd-4c22-9236-04e335e99124',
  'name': 'Cà phê sữa đá',
  'price': 25000,
  'quantity': 2,
  'unit': 'ly',
  'total_price': 50000,
  'category_id': 'cat_other',
  'category': {'id': 'cat_other', 'name': 'Khác', 'color': '#DDA0DD', 'icon': '📦'},
  'image_url': 'https://cdn.shopsnap.dev/a.jpg',
  'image_thumbnail_url': 'https://cdn.shopsnap.dev/a_thumb.jpg',
  'note': 'mua sáng',
  'store_name': 'Circle K',
  'location': {'latitude': 10.7769, 'longitude': 106.7009, 'accuracy_meters': 15},
  'purchase_date': '2026-09-12T19:59:03.000Z',
  'source': 'manual',
  'barcode': null,
  'created_at': '2026-09-12T19:59:03.491Z',
  'updated_at': '2026-09-12T19:59:21.820Z',
  'deleted_at': null,
};

void main() {
  group('ItemModel.fromApiJson', () {
    test('parse JSON backend đầy đủ (category lồng, location, ISO 8601)', () {
      final item = ItemModel.fromApiJson(fullItemJson());

      expect(item.id, '000c1588-8cdd-4c22-9236-04e335e99124');
      expect(item.name, 'Cà phê sữa đá');
      expect(item.price, 25000);
      expect(item.quantity, 2);
      expect(item.unit, 'ly');
      expect(item.totalPrice, 50000); // server-computed: price × quantity

      // Category lồng → map vào 4 field phẳng mà consumer đang đọc
      expect(item.categoryId, 'cat_other');
      expect(item.categoryName, 'Khác');
      expect(item.categoryIcon, '📦');
      expect(item.categoryColor, '#DDA0DD');

      // image_url là URL server → KHÔNG vào imagePath (ItemCard dùng Image.file)
      expect(item.imagePath, isNull);
      expect(item.imageUrl, 'https://cdn.shopsnap.dev/a.jpg');
      expect(item.imageThumbnailUrl, 'https://cdn.shopsnap.dev/a_thumb.jpg');

      expect(item.storeName, 'Circle K');
      expect(item.note, 'mua sáng');
      expect(item.barcode, isNull);
      expect(item.source, 'manual');

      // location lồng → lat/lng + accuracy
      expect(item.latitude, 10.7769);
      expect(item.longitude, 106.7009);
      expect(item.locationAccuracy, 15);

      // purchase_date ISO → millisecond int (createdAt = ngày mua để group theo ngày)
      final expectedMs =
          DateTime.utc(2026, 9, 12, 19, 59, 3).millisecondsSinceEpoch;
      expect(item.purchaseDate, expectedMs);
      expect(item.createdAt, expectedMs);
      expect(item.updatedAt,
          DateTime.utc(2026, 9, 12, 19, 59, 21, 820).millisecondsSinceEpoch);

      // Sync metadata: id server chính là id row local
      expect(item.serverId, item.id);
      expect(item.isSynced, isTrue);
      expect(item.isDeleted, isFalse);
    });

    test('thiếu field tuỳ chọn → fallback an toàn', () {
      final item = ItemModel.fromApiJson({
        'id': 'x',
        'name': 'Trứng',
        'price': 3000,
        'created_at': '2026-09-12T10:00:00.000Z',
        'updated_at': '2026-09-12T10:00:00.000Z',
        'location': null,
      });
      expect(item.categoryId, ''); // không có category → rỗng (upsertSynced tự xử lý)
      expect(item.categoryIcon, '📦');
      expect(item.categoryColor, '#DDA0DD');
      expect(item.totalPrice, isNull);
      expect(item.quantity, isNull);
      expect(item.purchaseDate, isNull);
      // Không có purchase_date → createdAt rơi về created_at
      expect(item.createdAt,
          DateTime.utc(2026, 9, 12, 10).millisecondsSinceEpoch);
      expect(item.latitude, isNull);
      expect(item.locationAccuracy, isNull);
    });

    test('price từ JSON dạng double vẫn về int VND', () {
      final item = ItemModel.fromApiJson({
        'id': 'x', 'name': 'Nước', 'price': 12.0,
        'created_at': '2026-09-12T10:00:00.000Z', 'updated_at': '2026-09-12T10:00:00.000Z',
      });
      expect(item.price, 12);
    });
  });

  group('ItemModel.toMap (sqflite)', () {
    test('đúng bộ cột của bảng items (v7 có thêm store_name — M-3)', () {
      final map = ItemModel.fromApiJson(fullItemJson()).toMap();
      expect(map.keys.toSet(), {
        'id', 'name', 'price', 'category_id', 'image_path', 'note', 'barcode',
        'latitude', 'longitude', 'sticker_data', 'store_name',
        'created_at', 'updated_at',
        'server_id', 'is_synced', 'is_deleted',
      });
      expect(map['is_synced'], 1);
      expect(map['server_id'], '000c1588-8cdd-4c22-9236-04e335e99124');
      // M-3: store_name GIỮ VÀO row local từ migration v7 (AC 7.2)
      expect(map['store_name'], 'Circle K');
      // Field API-only không lọt vào row
      expect(map.containsKey('total_price'), isFalse);
      expect(map.containsKey('purchase_date'), isFalse);
      expect(map.containsKey('source'), isFalse);
      expect(map.containsKey('image_url'), isFalse);
    });

    test('fromMap(toMap) round-trip các field cốt lõi', () {
      final fromApi = ItemModel.fromApiJson(fullItemJson());
      final back = ItemModel.fromMap(fromApi.toMap());
      expect(back.id, fromApi.id);
      expect(back.name, fromApi.name);
      expect(back.price, fromApi.price);
      expect(back.categoryId, fromApi.categoryId);
      expect(back.createdAt, fromApi.createdAt);
      expect(back.isSynced, isTrue);
      // M-3 (AC 7.2): store_name round-trip qua SQLite không mất giá trị.
      expect(back.storeName, 'Circle K');
      // toMap chỉ lưu category_id — categoryName/icon/color là alias của JOIN
      // trong ItemDao.findByDay, không phải cột của bảng items → round-trip
      // thuần từMap/fromMap sẽ rỗng (fallback an toàn của fromMap).
      expect(back.categoryName, '');
    });

    test('fromMap row local thuần (is_synced=0) vẫn parse như cũ', () {
      final back = ItemModel.fromMap({
        'id': 'local-1', 'name': 'Bánh mì', 'price': 15000,
        'category_id': 'cat_food', 'cat_name': 'Ăn uống', 'cat_icon': '🍜',
        'cat_color': '#FF6B6B', 'image_path': null, 'note': null,
        'barcode': null, 'latitude': null, 'longitude': null,
        'sticker_data': null, 'store_name': null,
        'created_at': 1000, 'updated_at': 1000,
        'server_id': null, 'is_synced': 0, 'is_deleted': 0,
      });
      expect(back.isSynced, isFalse);
      expect(back.serverId, isNull);
      expect(back.totalPrice, isNull); // field API-only → null khi đọc từ DB
      expect(back.imagePath, isNull);
      expect(back.storeName, isNull); // row cũ (pre-v7) không có nơi mua
    });
  });

  group('ItemModel.copyWith', () {
    test('giữ ảnh local khi server không trả ảnh', () {
      final fromApi = ItemModel.fromApiJson(fullItemJson());
      final merged = fromApi.copyWith(imagePath: '/data/user/0/photo.jpg');
      expect(merged.imagePath, '/data/user/0/photo.jpg');
      expect(merged.id, fromApi.id);
      expect(merged.isSynced, isTrue);
    });
  });
}
