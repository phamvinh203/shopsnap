import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/item_model.dart';
import '../../models/summary_model.dart';
import '../../core/utils/date_helper.dart';

const _uuid = Uuid();

class CreateItemDto {
  final String  name;
  final int     price;
  final String  categoryId;
  final String? imagePath;
  final String? note;
  final String? barcode;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? stickerData;

  const CreateItemDto({
    required this.name,
    required this.price,
    required this.categoryId,
    this.imagePath,
    this.note,
    this.barcode,
    this.latitude,
    this.longitude,
    this.stickerData,
  });
}

class ItemDao {
  final Database db;
  ItemDao(this.db);

  Future<String> insert(CreateItemDto dto) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id  = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert('items', {
        'id':           id,
        'name':         dto.name,
        'price':        dto.price,
        'category_id':  dto.categoryId,
        'image_path':   dto.imagePath,
        'note':         dto.note,
        'barcode':      dto.barcode,
        'latitude':     dto.latitude,
        'longitude':    dto.longitude,
        'sticker_data': dto.stickerData != null ? jsonEncode(dto.stickerData) : null,
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
        'category_id':  dto.categoryId,
        'purchased_at': now,
      });

      // Enqueue for cloud sync
      await txn.insert('sync_queue', {
        'id':          _uuid.v4(),
        'entity_type': 'item',
        'entity_id':   id,
        'operation':   'INSERT',
        'payload':     jsonEncode({'name': dto.name, 'price': dto.price, 'category_id': dto.categoryId}),
        'created_at':  now,
        'retry_count': 0,
      });
    });

    return id;
  }

  Future<List<ItemModel>> findByDay(DateTime day) async {
    final rows = await db.rawQuery('''
      SELECT i.*, c.name AS cat_name, c.icon AS cat_icon, c.color AS cat_color
      FROM items i
      JOIN categories c ON c.id = i.category_id
      WHERE i.created_at >= ? AND i.created_at < ?
        AND i.is_deleted = 0
      ORDER BY i.created_at ASC
    ''', [DateHelper.dayStart(day), DateHelper.dayEnd(day)]);
    return rows.map(ItemModel.fromMap).toList();
  }

  Future<SummaryModel> getSummaryForDay(DateTime day) async {
    final start = DateHelper.dayStart(day);
    final end   = DateHelper.dayEnd(day);

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
    ''', [start, end]);

    final items = await findByDay(day);
    final cats  = catRows.map(CategorySummary.fromMap).toList();
    final total = cats.fold(0, (s, c) => s + c.totalSpent);

    return SummaryModel(
      date: day, totalSpent: total,
      itemCount: items.length, categories: cats, items: items,
    );
  }

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
