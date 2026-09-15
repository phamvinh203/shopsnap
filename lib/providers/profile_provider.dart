import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'database_provider.dart';
import 'items_provider.dart';

/// Thống kê dữ liệu local cho section "Dữ liệu local" của /profile (AC 10.4).
class LocalDataStats {
  /// Số vật phẩm CHƯA bị xoá mềm (is_deleted = 0).
  final int items;

  /// Số sản phẩm đã cache từ tra cứu mã vạch (bảng barcode_cache).
  ///
  /// [ASSUMPTION] Spec AC 10.4 đếm "products" nhưng SQLite local không có bảng
  /// `products` — sản phẩm duy nhất app cache ở local là barcode_cache (tên +
  /// thương hiệu + danh mục từ tra cứu mã vạch), nên dùng bảng này làm
  /// "sản phẩm". Khi BE mở endpoint thống kê (spec note F-#10) sẽ thay số này.
  final int products;

  /// Số bản ghi lịch sử giá.
  final int priceHistories;

  const LocalDataStats({
    required this.items,
    required this.products,
    required this.priceHistories,
  });
}

/// Đếm dữ liệu local bằng SQL thẳng trên SQLite (spec note F-#10: "không có
/// endpoint thống kê thì FE đếm local"; AC 10.4: số khớp thực tế sau khi
/// thêm/xoá). Watch [itemsProvider] để provider tự rebuild khi user thêm/xoá
/// vật phẩm thay vì cache số đếm cũ vĩnh viễn. Widget test override provider.
final localDataStatsProvider = FutureProvider<LocalDataStats>((ref) async {
  ref.watch(itemsProvider);
  final db = await ref.watch(databaseProvider.future);
  return LocalDataStats(
    items: await _count(db, 'SELECT COUNT(*) AS c FROM items WHERE is_deleted = 0'),
    products: await _count(db, 'SELECT COUNT(*) AS c FROM barcode_cache'),
    priceHistories: await _count(db, 'SELECT COUNT(*) AS c FROM price_history'),
  );
});

Future<int> _count(Database db, String sql) async {
  final rows = await db.rawQuery(sql);
  return (rows.first['c'] as num?)?.toInt() ?? 0;
}

/// Cổng G2 (FEATURE_SPECS_V2 — bảng gate) CHƯA MỞ: sync chưa đảm bảo persist
/// bền vững end-to-end. Profile đọc cờ này để hiện nhãn "Chưa có đồng bộ nền"
/// (AC 10.3) — user không hiểu lầm dữ liệu đã được backup an toàn. Khi G2 mở,
/// đổi cờ tại MỘT chỗ duy nhất này.
final syncPersistedProvider = Provider<bool>((ref) => false);
