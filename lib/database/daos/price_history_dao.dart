import 'package:sqflite/sqflite.dart';
import '../../models/price_history_model.dart';

class PriceHistoryDao {
  final Database db;

  PriceHistoryDao(this.db);

  /// Tra cứu lịch sử giá theo tên hoặc barcode từ bảng price_history (Offline-First)
  Future<PriceHistorySummary?> getPriceHistory({
    String? name,
    String? barcode,
    int limit = 30,
  }) async {
    final cleanName = name?.trim().toLowerCase();
    final cleanBarcode = barcode?.trim();

    if ((cleanName == null || cleanName.isEmpty) &&
        (cleanBarcode == null || cleanBarcode.isEmpty)) {
      return null;
    }

    String where;
    List<dynamic> whereArgs;

    if (cleanBarcode != null && cleanBarcode.isNotEmpty) {
      where = 'barcode = ?';
      whereArgs = [cleanBarcode];
    } else {
      where = 'item_name LIKE ?';
      whereArgs = ['%$cleanName%'];
    }

    final rows = await db.query(
      'price_history',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'purchased_at DESC',
      limit: limit,
    );

    if (rows.isEmpty) return null;

    final latestRow = rows.first;
    final previousRow = rows.length > 1 ? rows[1] : null;

    final prices = rows.map((r) => (r['price'] as num).toInt()).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final sumPrice = prices.reduce((a, b) => a + b);
    final avgPrice = (sumPrice / prices.length).round();

    final latestPrice = (latestRow['price'] as num).toInt();
    final previousPrice = previousRow != null ? (previousRow['price'] as num).toInt() : null;

    double? priceChangePercent;
    PriceTrend trend = PriceTrend.stable;

    if (previousPrice != null && previousPrice > 0) {
      final diff = latestPrice - previousPrice;
      priceChangePercent = double.parse(((diff / previousPrice) * 100).toStringAsFixed(2));
      if (priceChangePercent > 0.5) {
        trend = PriceTrend.up;
      } else if (priceChangePercent < -0.5) {
        trend = PriceTrend.down;
      } else {
        trend = PriceTrend.stable;
      }
    }

    // Points xếp theo thời gian tăng dần từ quá khứ đến hiện tại để vẽ biểu đồ
    final points = rows.reversed.map((r) => PriceHistoryPoint(
      id: r['id'] as String,
      price: (r['price'] as num).toInt(),
      purchasedAt: DateTime.fromMillisecondsSinceEpoch(r['purchased_at'] as int),
    )).toList();

    return PriceHistorySummary(
      itemName: latestRow['item_name'] as String,
      barcode: latestRow['barcode'] as String?,
      latestPrice: latestPrice,
      previousPrice: previousPrice,
      minPrice: minPrice,
      maxPrice: maxPrice,
      avgPrice: avgPrice,
      priceChangePercent: priceChangePercent,
      trend: trend,
      totalRecords: rows.length,
      points: points,
    );
  }

  /// Lấy danh sách các mặt hàng xuất hiện nhiều lần nhất trong lịch sử mua sắm
  Future<List<FrequentTrackedItem>> getFrequentItems({int limit = 10}) async {
    final rows = await db.rawQuery('''
      SELECT
        item_name,
        barcode,
        COUNT(*) as purchase_count,
        MAX(purchased_at) as last_purchased_at
      FROM price_history
      GROUP BY item_name
      ORDER BY purchase_count DESC, last_purchased_at DESC
      LIMIT ?
    ''', [limit]);

    if (rows.isEmpty) return [];

    final results = <FrequentTrackedItem>[];

    for (final r in rows) {
      final name = r['item_name'] as String;
      final barcode = r['barcode'] as String?;
      final count = (r['purchase_count'] as num).toInt();
      final lastPurchasedAt = (r['last_purchased_at'] as num).toInt();

      // Lấy giá mới nhất của sản phẩm này
      final latestRows = await db.query(
        'price_history',
        columns: ['price'],
        where: 'item_name = ?',
        whereArgs: [name],
        orderBy: 'purchased_at DESC',
        limit: 1,
      );

      final latestPrice = latestRows.isNotEmpty
          ? (latestRows.first['price'] as num).toInt()
          : 0;

      results.add(FrequentTrackedItem(
        itemName: name,
        barcode: barcode,
        purchaseCount: count,
        latestPrice: latestPrice,
        lastPurchasedAt: DateTime.fromMillisecondsSinceEpoch(lastPurchasedAt),
      ));
    }

    return results;
  }
}
