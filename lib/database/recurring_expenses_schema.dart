import 'package:sqflite/sqflite.dart';

/// M-2 — Schema bảng `recurring_expenses` (migration v6, LOCAL-ONLY).
///
/// Tách thành class public để unit test được DDL + hành vi ghi
/// `schema_migrations` (AC 4.1) mà không cần mở SQLite thật — cùng tinh thần
/// fail-safe với `_migrationV5` của F-#6:
/// - `CREATE TABLE IF NOT EXISTS` → an toàn cả DB tạo mới lẫn DB cũ, KHÔNG
///   ALTER/đụng bất kỳ bảng có sẵn nào (items, shopping_list_items… nguyên vẹn).
/// - `server_id` + `updated_at` chừa sẵn cho LWW khi sync mở khoá —
///   [CONTRACT-PENDING] AC 4.15, đợt này KHÔNG entry nào được enqueue sync.
/// - `last_reminder_cycle` ('yyyy-MM') — dedup nhắc theo chu kỳ (AC 4.12).
class RecurringExpensesSchema {
  RecurringExpensesSchema._();

  /// Version migration trong `schema_migrations` (AppConstants.dbVersion khớp).
  static const int version = 6;

  /// Tên migration (nội dung mô tả, không phải khóa).
  static const String name = 'add_recurring_expenses';

  /// DDL bảng — giữ chuỗi và file schema_migrations ĐỒNG BỘ qua [record].
  static const String table = '''
    CREATE TABLE IF NOT EXISTS recurring_expenses (
      id                   TEXT    PRIMARY KEY,
      name                 TEXT    NOT NULL,
      match_key            TEXT    NOT NULL,
      amount               INTEGER NOT NULL CHECK(amount > 0),
      period               TEXT    NOT NULL DEFAULT 'monthly'
                                   CHECK(period IN ('monthly','yearly')),
      due_day              INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 28),
      is_active            INTEGER NOT NULL DEFAULT 1,
      remind_days_before   INTEGER NOT NULL DEFAULT 1,
      last_reminder_cycle  TEXT,
      server_id            TEXT,
      created_at           INTEGER NOT NULL,
      updated_at           INTEGER NOT NULL
    )''';

  /// Index partial — chỉ entry đang bật được quét thường xuyên (re-arm).
  static const String index =
      'CREATE INDEX IF NOT EXISTS idx_recurring_active '
      'ON recurring_expenses(is_active) WHERE is_active = 1';

  /// Ghi row version 6 vào `schema_migrations` (AC 4.1: cả upgrade lẫn
  /// cài mới qua onCreate đều phải có row này).
  static Future<void> record(Database db) async {
    await db.insert('schema_migrations', {
      'version': version,
      'name': name,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Áp dụng migration lên DB đang mở (onUpgrade): tạo bảng + index + ghi row.
  static Future<void> apply(Database db) async {
    await db.execute(table);
    await db.execute(index);
    await record(db);
  }
}
