import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/core/constants/app_constants.dart';
import 'package:shopsnap/database/items_store_name_schema.dart';
import 'package:sqflite/sqflite.dart';

/// AC 7.1 — Migration v7 thêm cột `store_name` cho bảng `items` (M-3).
///
/// Không có SQLite thật trong môi trường test (không sqflite_common_ffi) nên
/// khoá hành vi bằng mocktail theo đúng pattern M-2
/// (`recurring_expense_migration_test.dart`):
/// 1. DDL: ALTER TABLE ADD COLUMN — additive đúng precedent `_migrationV3`,
///    KHÔNG đụng cột/bảng khác; row cũ nhận NULL (nullable, không default).
/// 2. `apply()`: idempotent (PRAGMA table_info chặn ALTER khi cột đã có) +
///    fail-safe (PRAGMA/ALTER lỗi → log + skip, VẪN ghi schema_migrations v7 —
///    openDatabase không bao giờ crash vì migration này).
class MockDatabase extends Mock implements Database {}

void main() {
  const alter = ItemsStoreNameSchema.alter;

  group('AC 7.1 — DDL ALTER additive đúng schema', () {
    test('ALTER TABLE items ADD COLUMN store_name TEXT', () {
      expect(alter, 'ALTER TABLE items ADD COLUMN store_name TEXT');
      // Chỉ đụng bảng items + chỉ thêm 1 cột — không CREATE/DROP/RENAME.
      expect(alter.contains('CREATE TABLE'), isFalse);
      expect(alter.contains('DROP'), isFalse);
      expect(alter.contains('RENAME'), isFalse);
      expect(alter.contains('NOT NULL'), isFalse,
          reason: 'row cũ phải nhận NULL → cột phải nullable');
    });

    test('Cột khai báo sẵn trong CREATE TABLE cho cài mới (đồng bộ chuỗi)', () {
      expect(ItemsStoreNameSchema.columnInCreateTable,
          contains('store_name      TEXT'));
    });

    test('AppConstants.dbVersion đã bump 6 → 7, khớp schema version', () {
      expect(AppConstants.dbVersion, 7);
      expect(ItemsStoreNameSchema.version, 7);
      expect(ItemsStoreNameSchema.name, 'add_store_name_to_items');
      expect(ItemsStoreNameSchema.table, 'items');
      expect(ItemsStoreNameSchema.column, 'store_name');
    });
  });

  group('AC 7.1 — apply(): ALTER + ghi schema_migrations v7', () {
    late MockDatabase db;

    setUpAll(() {
      registerFallbackValue(<String, Object?>{});
    });

    setUp(() {
      db = MockDatabase();
      // Mặc định: bảng items KHÔNG có cột store_name (DB cũ version ≤ 6).
      when(() => db.rawQuery(any(), any()))
          .thenAnswer((_) async => <Map<String, Object?>>[]);
      when(() => db.execute(any(), any())).thenAnswer((_) async {});
      when(() => db.insert(any(), any())).thenAnswer((_) async => 1);
    });

    List<String> executedSql() => verify(() => db.execute(captureAny()))
        .captured
        .cast<String>()
        .toList();

    List<Map<String, dynamic>> migrationRows() =>
        verify(() => db.insert('schema_migrations', captureAny()))
            .captured
            .cast<Map<String, dynamic>>()
            .toList();

    test('DB cũ (v≤6): execute ĐÚNG lệnh ALTER + ghi row version 7', () async {
      await ItemsStoreNameSchema.apply(db);

      expect(executedSql(), [alter]);
      final rows = migrationRows();
      expect(rows.length, 1);
      expect(rows.single['version'], 7);
      expect(rows.single['name'], 'add_store_name_to_items');
      expect(rows.single['applied_at'], isA<int>());
    });

    test('Idempotent: cột ĐÃ tồn tại → KHÔNG ALTER, vẫn ghi row v7', () async {
      when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
            {'cid': 0, 'name': 'id'},
            {'cid': 1, 'name': 'name'},
            {'cid': 2, 'name': 'store_name'}, // đã có (crash giữa chừng v7)
          ]);

      await ItemsStoreNameSchema.apply(db);

      // Không có lệnh execute nào (ALTER lần nữa sẽ văng duplicate column).
      verifyNever(() => db.execute(any(), any()));
      expect(migrationRows().single['version'], 7);
    });

    test('Fail-safe: PRAGMA lỗi → KHÔNG crash, vẫn ghi row v7 (log + skip)',
        () async {
      when(() => db.rawQuery(any(), any()))
          .thenThrow(StateError('db corrupted'));

      await ItemsStoreNameSchema.apply(db); // không ném

      expect(migrationRows().single['version'], 7);
    });

    test('Fail-safe: ALTER lỗi (DB lạ) → KHÔNG crash, vẫn ghi row v7',
        () async {
      when(() => db.execute(any(), any()))
          .thenThrow(StateError('duplicate column name'));

      await ItemsStoreNameSchema.apply(db); // không ném

      expect(migrationRows().single['version'], 7);
    });

    test('record() đơn lẻ (onCreate cài mới) chỉ ghi row version 7', () async {
      await ItemsStoreNameSchema.record(db);

      verifyNever(() => db.execute(any(), any()));
      expect(migrationRows().single['version'], 7);
    });
  });
}
