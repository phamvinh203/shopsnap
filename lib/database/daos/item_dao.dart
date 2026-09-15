import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../models/item_model.dart';
import '../../models/summary_model.dart';
import '../../core/utils/date_helper.dart';

const _uuid = Uuid();

class CreateItemDto {
  final String  name;
  final int     price;

  /// Nullable để UI bỏ trống → server tự auto-classify theo tên (BR-04).
  /// Insert local khi offline dùng fallback 'cat_other'.
  final String? categoryId;
  final String? imagePath;
  final String? note;
  final String? barcode;
  final String? storeName; // M-3 (AC 7.3): nơi mua — TUỲ CHỌN, null = không có
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? stickerData;

  const CreateItemDto({
    required this.name,
    required this.price,
    this.categoryId,
    this.imagePath,
    this.note,
    this.barcode,
    this.storeName,
    this.latitude,
    this.longitude,
    this.stickerData,
  });
}

/// Chuẩn hoá nơi mua trước khi lưu/gửi: trim; rỗng → null (AC 7.3/7.6 —
/// bỏ trống nghĩa là item KHÔNG có store_name, không lưu chuỗi rỗng ngầm).
String? sanitizeStoreName(String? raw) {
  final t = raw?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

class ItemDao {
  final Database db;
  ItemDao(this.db);

  Future<String> insert(CreateItemDto dto) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id  = _uuid.v4();
    final cid = dto.categoryId ?? 'cat_other'; // cột category_id NOT NULL
    final store = sanitizeStoreName(dto.storeName);

    await db.transaction((txn) async {
      await txn.insert('items', {
        'id':           id,
        'name':         dto.name,
        'price':        dto.price,
        'category_id':  cid,
        'image_path':   dto.imagePath,
        'note':         dto.note,
        'barcode':      dto.barcode,
        'latitude':     dto.latitude,
        'longitude':    dto.longitude,
        'sticker_data': dto.stickerData != null ? jsonEncode(dto.stickerData) : null,
        'store_name':   store, // M-3: cột từ migration v7 (nullable)
        'created_at':   now,
        'updated_at':   now,
        'is_synced':    0,
        'is_deleted':   0,
      });

      // Auto-record price history
      await txn.insert('price_history', {
        'id':           _uuid.v4(),
        'item_name':    dto.name.toLowerCase().trim(),
        'barcode':      dto.barcode,
        'price':        dto.price,
        'category_id':  cid,
        'purchased_at': now,
      });

      // Enqueue for cloud sync — payload mang cả store_name để server tạo
      // item đúng nơi mua khi push (AC 7.3 "lưu + sync → BE nhận nguyên văn").
      await txn.insert('sync_queue', {
        'id':          _uuid.v4(),
        'entity_type': 'item',
        'entity_id':   id,
        'operation':   'INSERT',
        'payload':     jsonEncode({
          'name': dto.name,
          'price': dto.price,
          'category_id': cid,
          if (store != null) 'store_name': store,
        }),
        'created_at':  now,
        'retry_count': 0,
      });
    });

    return id;
  }

  /// Upsert item nhận về từ server (Wave 3 — sync một chiều server → local).
  ///
  /// - `ConflictAlgorithm.replace`: id trùng (item đã sync trước đó) → đè bằng
  ///   bản mới nhất của server.
  /// - Giữ lại `image_path`/`sticker_data` local khi server không có giá trị
  ///   tương ứng (ảnh nằm ở thiết bị, server chỉ có URL).
  /// - FK(category_id → categories): category chỉ tồn tại trên server (tạo từ
  ///   thiết bị khác) → tạo row category tối thiểu từ category summary nhúng
  ///   trong response để không vỡ khoá ngoại. categoriesProvider sync đầy đủ
  ///   sau đó sẽ đè bằng bản chuẩn (cùng id).
  Future<void> upsertSynced(ItemModel item) async {
    await db.transaction((txn) async {
      final existing = await txn.query('items',
          where: 'id = ?', whereArgs: [item.id], limit: 1);

      final catExists = await txn.query('categories',
          where: 'id = ?', whereArgs: [item.categoryId], limit: 1);
      if (catExists.isEmpty) {
        await txn.insert('categories', {
          'id':         item.categoryId,
          'name':       item.categoryName.isEmpty ? 'Danh mục' : item.categoryName,
          'icon':       item.categoryIcon,
          'color':      item.categoryColor,
          'is_default': 0,
          'sort_order': 10000, // xếp cuối danh sách, dưới seed + custom
          'created_at': item.updatedAt,
        });
      }

      Map<String, dynamic> row = item.toMap()..['is_synced'] = 1;
      if (existing.isNotEmpty) {
        // Server không biết ảnh/sticker local → giữ giá trị cũ nếu bản mới rỗng
        if (row['image_path']   == null) row['image_path']   = existing.first['image_path'];
        if (row['sticker_data'] == null) row['sticker_data'] = existing.first['sticker_data'];
      }
      await txn.insert('items', row, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Cập nhật local khi offline (fallback của updateItem) — mark is_synced=0
  /// và enqueue UPDATE vào sync_queue, đồng bộ cách insert/softDelete đang làm.
  ///
  /// [storeName] M-3: khác các param khác, `''` là GIÁ TRỊ HỢP LỆ nghĩa là
  /// "user xoá trắng" → cột về NULL và payload gửi chuỗi rỗng cho server
  /// (PATCH store_name='' hợp lệ theo BE — @IsString, AC 7.6 không giữ giá trị
  /// cũ ngầm). `null` = không đổi nơi mua.
  Future<void> updateLocal(
    String id, {
    String? name,
    int? price,
    String? categoryId,
    String? note,
    String? barcode,
    String? storeName,
  }) async {
    final now  = DateTime.now().millisecondsSinceEpoch;
    final store = storeName == null ? null : sanitizeStoreName(storeName);
    final changes = <String, dynamic>{
      if (name       != null) 'name':       name,
      if (price      != null) 'price':      price,
      if (categoryId != null) 'category_id': categoryId,
      if (note       != null) 'note':       note,
      if (barcode    != null) 'barcode':    barcode,
      if (storeName  != null) 'store_name': store, // trim; rỗng → NULL
      'updated_at':  now,
      'is_synced':   0,
    };
    if (changes.length == 2) return; // chỉ có updated_at/is_synced → không có gì để đổi

    await db.insert('sync_queue', {
      'id':          _uuid.v4(),
      'entity_type': 'item',
      'entity_id':   id,
      'operation':   'UPDATE',
      'payload':     jsonEncode({
        if (name       != null) 'name':       name,
        if (price      != null) 'price':      price,
        if (categoryId != null) 'category_id': categoryId,
        if (note       != null) 'note':       note,
        if (barcode    != null) 'barcode':    barcode,
        if (storeName  != null) 'store_name': store,
      }),
      'created_at':  now,
      'retry_count': 0,
    });
    await db.update('items', changes,
        where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
  }

  /// M-3 (AC 7.4): gợi ý "Nơi mua" theo TẦN SUẤT giảm dần — tính từ giá trị
  /// NGUYÊN VĂN user đã dùng (không normalize — AC 7.13), chỉ item chưa xoá
  /// mềm đóng góp. Trùng nguyên văn mới gộp; đúng query 1 lần như spec.
  /// Offline đọc được trực tiếp từ SQLite (AC 7.14).
  Future<List<String>> getStoreSuggestions({
    int limit = AppConstants.storeSuggestionLimit,
  }) async {
    final rows = await db.rawQuery('''
      SELECT store_name, COUNT(*) AS use_count
      FROM items
      WHERE store_name IS NOT NULL AND store_name != '' AND is_deleted = 0
      GROUP BY store_name
      ORDER BY use_count DESC, store_name ASC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) => r['store_name'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Item trong khoảng ngày [start, end] (bao cả 2 đầu) — cùng SQL với
  /// findByDay, mở rộng cho summary các kỳ week/month/year (Wave 5).
  Future<List<ItemModel>> findByRange(DateTime start, DateTime end) async {
    final rows = await db.rawQuery('''
      SELECT i.*, c.name AS cat_name, c.icon AS cat_icon, c.color AS cat_color
      FROM items i
      JOIN categories c ON c.id = i.category_id
      WHERE i.created_at >= ? AND i.created_at < ?
        AND i.is_deleted = 0
      ORDER BY i.created_at ASC
    ''', [DateHelper.dayStart(start), DateHelper.dayEnd(end)]);
    return rows.map(ItemModel.fromMap).toList();
  }

  Future<List<ItemModel>> findByDay(DateTime day) => findByRange(day, day);

  /// F-#5 P1: item local gần đây (MỚI → CŨ, chỉ item chưa xoá) — dùng cho
  /// duplicate detection khi confirm hóa đơn (AC 5.3: cửa sổ 7 ngày) và học
  /// gợi ý category từ lịch sử (AC 5.2). Lấy rộng 30 ngày để còn seed learning.
  Future<List<ItemModel>> findRecent({int days = 30}) async {
    final since =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = await db.query(
      'items',
      where: 'created_at >= ? AND is_deleted = 0',
      whereArgs: [since],
      orderBy: 'created_at DESC',
    );
    return rows.map(ItemModel.fromMap).toList();
  }

  /// Tổng hợp summary cho khoảng ngày [start, end] (bao cả 2 đầu) — cùng phép
  /// tính GROUP BY category như getSummaryForDay, làm fallback offline cho
  /// summary API theo kỳ week/month/year (Wave 5).
  Future<SummaryModel> getSummaryForRange(DateTime start, DateTime end) async {
    final startMs = DateHelper.dayStart(start);
    final endMs   = DateHelper.dayEnd(end);

    final catRows = await db.rawQuery('''
      SELECT
        i.category_id,
        c.name  AS category_name,
        c.icon  AS category_icon,
        c.color AS category_color,
        COUNT(*)       AS item_count,
        SUM(i.price)   AS total_spent
      FROM items i
      JOIN categories c ON c.id = i.category_id
      WHERE i.created_at >= ? AND i.created_at < ?
        AND i.is_deleted = 0
      GROUP BY i.category_id
      ORDER BY total_spent DESC
    ''', [startMs, endMs]);

    final items = await findByRange(start, end);
    final cats  = catRows.map(CategorySummary.fromMap).toList();
    final total = cats.fold(0, (s, c) => s + c.totalSpent);

    return SummaryModel(
      date: start, totalSpent: total,
      itemCount: items.length, categories: cats, items: items,
    );
  }

  Future<SummaryModel> getSummaryForDay(DateTime day) =>
      getSummaryForRange(day, day);

  Future<({int? lastPrice, int? avgPrice})> getPriceHint(String name, String? barcode) async {
    final since = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    final normalized = name.toLowerCase().trim();

    final rows = await db.rawQuery('''
      SELECT ROUND(AVG(price), 0) AS avg_price,
             (SELECT price FROM price_history
              WHERE item_name = ? ORDER BY purchased_at DESC LIMIT 1) AS last_price
      FROM price_history
      WHERE item_name = ? AND purchased_at >= ?
    ''', [normalized, normalized, since]);

    if (rows.isEmpty) return (lastPrice: null, avgPrice: null);
    return (
      lastPrice: rows.first['last_price'] as int?,
      avgPrice:  (rows.first['avg_price'] as num?)?.toInt(),
    );
  }

  Future<int> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('sync_queue', {
      'id':          _uuid.v4(),
      'entity_type': 'item',
      'entity_id':   id,
      'operation':   'DELETE',
      'payload':     jsonEncode({'id': id}),
      'created_at':  now,
      'retry_count': 0,
    });
    return db.update('items',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?', whereArgs: [id],
    );
  }
}
