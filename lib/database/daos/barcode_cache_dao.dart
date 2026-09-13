import 'package:sqflite/sqflite.dart';
import '../../services/barcode_service.dart';

class BarcodeCacheDao {
  final Database db;

  BarcodeCacheDao(this.db);

  /// Tra cứu mã vạch trong SQLite local (Tier 1: barcode_cache & price_history)
  Future<BarcodeResult?> findByBarcode(String barcode) async {
    final cleanCode = barcode.trim();

    // 1. Kiểm tra bảng barcode_cache
    final cacheRows = await db.query(
      'barcode_cache',
      where: 'barcode = ?',
      whereArgs: [cleanCode],
      limit: 1,
    );

    if (cacheRows.isNotEmpty) {
      final row = cacheRows.first;
      return BarcodeResult(
        barcode: cleanCode,
        productName: row['product_name'] as String,
        brand: row['brand'] as String?,
        categoryId: row['category_id'] as String,
        imageUrl: row['image_url'] as String?,
        source: BarcodeSource.localHistory,
      );
    }

    // 2. Fallback kiểm tra bảng price_history (các sản phẩm người dùng từng mua có mã vạch này)
    final historyRows = await db.query(
      'price_history',
      where: 'barcode = ?',
      whereArgs: [cleanCode],
      orderBy: 'purchased_at DESC',
      limit: 1,
    );

    if (historyRows.isNotEmpty) {
      final row = historyRows.first;
      final name = row['item_name'] as String;
      final categoryId = row['category_id'] as String;

      // Lưu lại vào barcode_cache để lần sau tra cứu nhanh hơn
      await insertOrUpdate(BarcodeResult(
        barcode: cleanCode,
        productName: name,
        categoryId: categoryId,
        source: BarcodeSource.localHistory,
      ));

      return BarcodeResult(
        barcode: cleanCode,
        productName: name,
        categoryId: categoryId,
        source: BarcodeSource.localHistory,
      );
    }

    return null;
  }

  /// Lưu hoặc cập nhật kết quả tra cứu vào barcode_cache
  Future<void> insertOrUpdate(BarcodeResult result) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'barcode_cache',
      {
        'barcode': result.barcode.trim(),
        'product_name': result.productName.trim(),
        'brand': result.brand?.trim(),
        'category_id': result.categoryId,
        'image_url': result.imageUrl,
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Xoá toàn bộ cache mã vạch (dành cho kiểm thử hoặc reset dữ liệu)
  Future<int> clearAll() => db.delete('barcode_cache');
}
