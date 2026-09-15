import 'package:sqflite/sqflite.dart';

/// M-3 — Migration v7: thêm cột `store_name` cho bảng `items` (F-#7 Merchant,
/// local-first). Tách class public để unit test được DDL + hành vi ghi
/// `schema_migrations` bằng mocktail mà không cần SQLite thật (cùng tinh thần
/// `RecurringExpensesSchema` của M-2).
///
/// Khác v5/v6 (CREATE TABLE mới), v7 là ADDITIVE theo đúng precedent
/// `_migrationV3` từng ALTER TABLE items thêm cột sync:
/// - `ALTER TABLE items ADD COLUMN store_name TEXT` — an toàn trên SQLite:
///   không đụng cột/bảng khác, dữ liệu user cũ nguyên vẹn, row cũ nhận NULL.
/// - Idempotent: kiểm tra `PRAGMA table_info(items)` trước khi ALTER để chạy
///   lại không lỗi (ví dụ DB từng ALTER xong nhưng crash trước khi ghi row).
/// - Fail-safe (AC 7.1): ALTER/PRAGMA lỗi → log + skip, VẪN ghi row version 7
///   để `openDatabase` không vỡ ở lần mở sau.
class ItemsStoreNameSchema {
  ItemsStoreNameSchema._();

  /// Version migration trong `schema_migrations` (AppConstants.dbVersion khớp).
  static const int version = 7;

  /// Tên migration (nội dung mô tả, không phải khóa).
  static const String name = 'add_store_name_to_items';

  /// Tên bảng + cột đích — dùng cho PRAGMA check và test.
  static const String table = 'items';
  static const String column = 'store_name';

  /// DDL ALTER — null được (item có thể không có nơi mua), không default.
  static const String alter =
      'ALTER TABLE items ADD COLUMN store_name TEXT';

  /// Cột được khai báo sẵn trong DDL CREATE TABLE items (cài mới) —
  /// `database_helper._sqlItems` giữ chuỗi này đồng bộ.
  static const String columnInCreateTable = 'store_name      TEXT,';

  /// Ghi row version 7 vào `schema_migrations` (AC 7.1: cả upgrade lẫn
  /// cài mới qua onCreate đều phải có row này).
  static Future<void> record(Database db) async {
    await db.insert('schema_migrations', {
      'version': version,
      'name': name,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Áp dụng migration lên DB đang mở (onUpgrade): ALTER ADD COLUMN (idempotent
  /// qua PRAGMA table_info) + ghi row `schema_migrations`. Mọi lỗi DDL được
  /// nuốt (log + skip) — không bao giờ làm crash `openDatabase` (AC 7.1).
  static Future<void> apply(Database db) async {
    try {
      final hasColumn = await _columnExists(db);
      if (!hasColumn) {
        await db.execute(alter);
      }
    } catch (e) {
      // Fail-safe: DB hỏng/cột tồn tại với shape lạ → bỏ qua, app vẫn mở được.
      // ignore: avoid_print
      print('ItemsStoreNameSchema.apply error (skip): $e');
    }
    await record(db);
  }

  /// `PRAGMA table_info(items)` → cột đã tồn tại chưa.
  static Future<bool> _columnExists(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in rows) {
      if ((row['name'] as String?) == column) return true;
    }
    return false;
  }
}
