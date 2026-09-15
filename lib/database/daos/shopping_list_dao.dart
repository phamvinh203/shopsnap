import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../models/shopping_list_item_model.dart';

const _uuid = Uuid();

/// DTO tạo dòng mới từ quick-add / edit sheet. [name] ĐÃ trim ở tầng gọi;
/// DAO vẫn tự trim + chặn rỗng để list không bao giờ chứa dòng rỗng (AC 6.3).
class CreateShoppingListItemDto {
  final String name;
  final String? barcode;

  const CreateShoppingListItemDto({required this.name, this.barcode});
}

/// DAO bảng `shopping_list_items` (F-#6).
///
/// ⚠️ LOCAL-ONLY theo thiết kế (AC 6.17): KHÔNG method nào ghi vào
/// `sync_queue` — shopping_list không được gửi lên server (whitelist DTO của
/// BE chưa chứa entity này, push sẽ 400). Test
/// `test/unit/shopping_list_no_sync_test.dart` khoá invariant này.
class ShoppingListItemDao {
  final Database db;

  ShoppingListItemDao(this.db);

  /// 1 list duy nhất per user (AC 6.7) — không có khái niệm listId.
  ///
  /// Thứ tự hiển thị: món chưa mua lên trước, mới thêm lên trước;
  /// món đã mua rơi xuống đáy (giữ thứ tự mua gần nhất).
  Future<List<ShoppingListItem>> getAll() async {
    final rows = await db.query(
      'shopping_list_items',
      orderBy: 'checked ASC, created_at DESC',
    );
    return rows.map(ShoppingListItem.fromMap).toList();
  }

  Future<List<ShoppingListItem>> getWatched() async {
    final rows = await db.query(
      'shopping_list_items',
      where: 'watched = 1',
      orderBy: 'created_at DESC',
    );
    return rows.map(ShoppingListItem.fromMap).toList();
  }

  Future<ShoppingListItem?> findById(String id) async {
    final rows = await db.query(
      'shopping_list_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ShoppingListItem.fromMap(rows.first);
  }

  /// Thêm món. Tên trim; rỗng (hoặc toàn space) → trả `null`, KHÔNG tạo dòng
  /// (AC 6.3 — list không bao giờ chứa dòng rỗng).
  Future<ShoppingListItem?> insert(CreateShoppingListItemDto dto) async {
    final name = dto.name.trim();
    if (name.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final item = ShoppingListItem(
      id: _uuid.v4(),
      name: name,
      barcode: dto.barcode?.trim().isEmpty == true ? null : dto.barcode?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('shopping_list_items', item.toMap());
    return item;
  }

  /// Tick/bỏ tick mua xong — AC 6.4. Trả về trạng thái `checked` mới.
  Future<bool> toggleChecked(String id) async {
    return _toggleBool(id, 'checked');
  }

  /// Bật/tắt Price Watch — AC 6.12. Trả về trạng thái `watched` mới.
  Future<bool> toggleWatched(String id) async {
    return _toggleBool(id, 'watched');
  }

  Future<bool> _toggleBool(String id, String column) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute(
      'UPDATE shopping_list_items SET $column = 1 - $column, updated_at = ? '
      'WHERE id = ?',
      [now, id],
    );
    final item = await findById(id);
    return item == null ? false : (column == 'checked' ? item.checked : item.watched);
  }

  /// Sửa số lượng / giá dự kiến / danh mục — tất cả tuỳ chọn, bỏ trống được
  /// (AC 6.6). Truyền `clear*` = true để xoá giá trị hiện có.
  Future<void> update(
    String id, {
    int? quantity,
    int? expectedPrice,
    String? categoryId,
    bool clearQuantity = false,
    bool clearExpectedPrice = false,
    bool clearCategoryId = false,
  }) async {
    final changes = <String, dynamic>{
      if (clearQuantity) 'quantity': null else if (quantity != null) 'quantity': quantity,
      if (clearExpectedPrice) 'expected_price': null
      else if (expectedPrice != null) 'expected_price': expectedPrice,
      if (clearCategoryId) 'category_id': null
      else if (categoryId != null) 'category_id': categoryId,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (changes.length == 1) return; // chỉ có updated_at → không có gì đổi
    await db.update(
      'shopping_list_items',
      changes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Xoá dòng — xoá cứng, KHÔNG dialog xác nhận, KHÔNG soft delete (AC 6.5).
  Future<int> delete(String id) => db.delete(
        'shopping_list_items',
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Ghi nhận đã alert ở mức giá [price] cho lần giảm này (AC 6.15) + bật cờ
  /// badge chưa xem (AC 6.13).
  Future<void> markAlertFired(String id, int price) async {
    await db.update(
      'shopping_list_items',
      {
        'last_alert_price': price,
        'has_unseen_alert': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// User mở Shopping List → badge được coi là đã xem.
  Future<int> clearUnseenAlerts() => db.update(
        'shopping_list_items',
        {'has_unseen_alert': 0},
        where: 'has_unseen_alert = 1',
      );

  /// Số món có alert chưa xem — nguồn cho badge trên entry (AC 6.13).
  Future<int> countUnseenAlerts() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM shopping_list_items WHERE has_unseen_alert = 1',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }
}
