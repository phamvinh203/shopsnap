import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/database/recurring_expenses_schema.dart';
import 'package:sqflite/sqflite.dart';

/// AC 4.1 — Migration v6 bảng `recurring_expenses` (M-2, local-only).
///
/// Môi trường test này không có SQLite thật (không sqflite_common_ffi) nên
/// khoá hành vi ở 2 lớp:
/// 1. DDL: chuỗi `CREATE TABLE` đúng schema spec — đủ cột, CHECK(amount > 0),
///    CHECK(due_day BETWEEN 1 AND 28), CHECK(period IN ('monthly','yearly')),
///    mặc định is_active=1 / remind_days_before=1 / period='monthly', chừa
///    server_id + updated_at cho LWW, và IF NOT EXISTS (an toàn DB cũ/mới,
///    KHÔNG ALTER bảng có sẵn).
/// 2. `apply()` (được `_migrationV6` + onCreate gọi): execute bảng + index,
///    ghi `schema_migrations` version 6, và KHÔNG đụng bảng cũ (không chữ
///    'ALTER TABLE' trong toàn bộ SQL xuống DB).
class MockDatabase extends Mock implements Database {}

void main() {
  const table = RecurringExpensesSchema.table;
  const index = RecurringExpensesSchema.index;

  group('AC 4.1 — DDL recurring_expenses đúng schema spec', () {
    test('CREATE TABLE IF NOT EXISTS — idempotent, không ALTER bảng cũ', () {
      expect(table, contains('CREATE TABLE IF NOT EXISTS recurring_expenses'));
      expect(table.contains('ALTER TABLE'), isFalse,
          reason: 'Migration v6 KHÔNG đụng bảng có sẵn');
      expect(index.contains('ALTER TABLE'), isFalse);
    });

    test('Đủ toàn bộ cột theo spec (schema v6 chừa server_id)', () {
      for (final column in [
        'id                   TEXT    PRIMARY KEY',
        'name                 TEXT    NOT NULL',
        'match_key            TEXT    NOT NULL',
        'amount               INTEGER NOT NULL CHECK(amount > 0)',
        'due_day              INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 28)',
        'is_active            INTEGER NOT NULL DEFAULT 1',
        'remind_days_before   INTEGER NOT NULL DEFAULT 1',
        'last_reminder_cycle  TEXT',
        'server_id            TEXT', // [CONTRACT-PENDING] AC 4.15
        'created_at           INTEGER NOT NULL',
        'updated_at           INTEGER NOT NULL', // LWW khi sync mở
      ]) {
        expect(table, contains(column), reason: 'Thiếu cột: $column');
      }
    });

    test('CHECK period giới hạn monthly/yearly + default monthly', () {
      expect(table, contains("period               TEXT    NOT NULL DEFAULT 'monthly'"));
      expect(table, contains("CHECK(period IN ('monthly','yearly'))"));
    });

    test('Index partial chỉ trên entry đang bật', () {
      expect(
        index,
        'CREATE INDEX IF NOT EXISTS idx_recurring_active '
        'ON recurring_expenses(is_active) WHERE is_active = 1',
      );
    });

    test('AppConstants.dbVersion: schema v6 nguyên vẹn, version đã bump 6 → 7 (M-3)', () {
      expect(RecurringExpensesSchema.version, 6);
      expect(RecurringExpensesSchema.name, 'add_recurring_expenses');
      // M-3 bump DB lên v7 (items.store_name) — migration v6 của M-2 không đổi.
      expect(AppConstants.dbVersion, 7);
    });
  });

  group('AC 4.1 — apply(): tạo bảng + index + ghi schema_migrations v6', () {
    late MockDatabase db;

    setUpAll(() {
      registerFallbackValue(<String, Object?>{});
    });

    setUp(() {
      db = MockDatabase();
      when(() => db.execute(any())).thenAnswer((_) async {});
      when(() => db.insert(any(), any()))
          .thenAnswer((_) async => 1);
    });

    test('execute ĐÚNG DDL bảng + index, KHÔNG đụng bảng cũ', () async {
      await RecurringExpensesSchema.apply(db);

      final executed = verify(() => db.execute(captureAny()))
          .captured
          .cast<String>()
          .toList();
      expect(executed, [table, index]);
      for (final sql in executed) {
        expect(sql.contains('ALTER TABLE'), isFalse,
            reason: 'SQL đụng bảng cũ: $sql');
        // Chỉ chạm recurring_expenses + schema_migrations — items /
        // shopping_list_items phải nguyên vẹn (đếm row TRƯỚC = SAU).
        expect(
          sql.contains('items') && !sql.contains('recurring_expenses'),
          isFalse,
          reason: 'SQL chạm bảng items: $sql',
        );
      }
    });

    test('ghi ĐÚNG 1 row schema_migrations version 6', () async {
      await RecurringExpensesSchema.apply(db);

      final rows = verify(() => db.insert('schema_migrations', captureAny()))
          .captured
          .cast<Map<String, dynamic>>();
      expect(rows.length, 1);
      expect(rows.single['version'], 6);
      expect(rows.single['name'], 'add_recurring_expenses');
      expect(rows.single['applied_at'], isA<int>());
    });

    test('record() đơn lẻ (onCreate cài mới) chỉ ghi row version 6', () async {
      await RecurringExpensesSchema.record(db);

      verifyNever(() => db.execute(any()));
      final rows = verify(() => db.insert('schema_migrations', captureAny()))
          .captured
          .cast<Map<String, dynamic>>();
      expect(rows.single['version'], 6);
    });
  });
}
