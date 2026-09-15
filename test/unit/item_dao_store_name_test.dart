import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shopsnap/database/daos/item_dao.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:sqflite/sqflite.dart';

/// M-3 — Plumbing `store_name` qua ItemDao (AC 7.2, 7.3, 7.6, 7.4).
///
/// Không có SQLite thật → khoá hành vi bằng mocktail:
/// - insert: row `items` mang `store_name` (trim; rỗng → NULL) + payload
///   sync_queue mang `store_name` để push lên BE đúng nguyên văn (AC 7.3).
/// - updateLocal: xoá trắng (`''`) → cột về NULL (AC 7.6 không giữ giá trị cũ).
/// - getStoreSuggestions: đúng SQL GROUP BY tần suất (AC 7.4) — item xoá mềm
///   loại bởi `is_deleted = 0`.
/// - upsertSynced: `store_name` từ server ghi vào row local (AC 7.2 backfill).
class MockDatabase extends Mock implements Database {}

/// sqflite `transaction()` truyền cho action một `Transaction` (implements
/// Database) → mock phải implements Transaction để vào được action.
class MockTransaction extends Mock implements Transaction {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  late MockDatabase db;
  late MockTransaction txn;
  late ItemDao dao;

  setUp(() {
    db = MockDatabase();
    txn = MockTransaction();
    dao = ItemDao(db);

    // db.transaction → chạy action trên mock txn (không SQLite thật).
    // Dart infer closure async không return thành Future<Null> → cần stub cả
    // T=Null lẫn T=void cho khớp mọi call-site của DAO.
    when(() => db.transaction<Null>(any(),
        exclusive: any(named: 'exclusive'))).thenAnswer((inv) async {
      final action = inv.positionalArguments[0]
          as Future<dynamic> Function(Transaction);
      return await action(txn);
    });
    when(() => db.transaction<void>(any(),
        exclusive: any(named: 'exclusive'))).thenAnswer((inv) async {
      final action = inv.positionalArguments[0]
          as Future<dynamic> Function(Transaction);
      return await action(txn);
    });
    when(() => txn.insert(any(), any(),
        nullColumnHack: any(named: 'nullColumnHack'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')))
        .thenAnswer((_) async => 1);
    when(() => txn.query(any(),
        distinct: any(named: 'distinct'),
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        groupBy: any(named: 'groupBy'),
        having: any(named: 'having'),
        orderBy: any(named: 'orderBy'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'))).thenAnswer((_) async => []);
    when(() => txn.update(any(), any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')))
        .thenAnswer((_) async => 1);
    when(() => db.update(any(), any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')))
        .thenAnswer((_) async => 1);
    when(() => db.insert(any(), any(),
        nullColumnHack: any(named: 'nullColumnHack'),
        conflictAlgorithm: any(named: 'conflictAlgorithm')))
        .thenAnswer((_) async => 1);
    when(() => db.rawQuery(any(), any()))
        .thenAnswer((_) async => <Map<String, Object?>>[]);
  });

  Map<String, dynamic> capturedRow(String table) => verify(() =>
          txn.insert(table, captureAny(),
              nullColumnHack: any(named: 'nullColumnHack'),
              conflictAlgorithm: any(named: 'conflictAlgorithm')))
      .captured
      .cast<Map<String, dynamic>>()
      .single;

  String? payloadStoreName() {
    final payload =
        capturedRow('sync_queue')['payload'] as String;
    return (jsonDecode(payload) as Map<String, dynamic>)['store_name']
        as String?;
  }

  group('insert — AC 7.3 persist + payload sync', () {
    test('Có nơi mua → row items mang store_name, payload sync có store_name',
        () async {
      await dao.insert(const CreateItemDto(
        name: 'Sữa',
        price: 20000,
        storeName: 'CoopMart',
      ));

      expect(capturedRow('items')['store_name'], 'CoopMart');
      expect(payloadStoreName(), 'CoopMart');
      // price_history vẫn ghi như cũ (flow cũ không vỡ).
      expect(capturedRow('price_history')['item_name'], 'sữa');
    });

    test('Trim khoảng trắng 2 đầu trước khi lưu (AC 7.5)', () async {
      await dao.insert(const CreateItemDto(
        name: 'Sữa',
        price: 20000,
        storeName: '  CoopMart  ',
      ));

      expect(capturedRow('items')['store_name'], 'CoopMart');
      expect(payloadStoreName(), 'CoopMart');
    });

    test('Bỏ trống (chỉ khoảng trắng) → store_name NULL + payload không có key '
        '(AC 7.3 backward-compat)', () async {
      await dao.insert(const CreateItemDto(
          name: 'Sữa', price: 20000, storeName: '   '));
      expect(capturedRow('items')['store_name'], isNull);
      expect(payloadStoreName(), isNull);
    });

    test('Không truyền storeName → store_name NULL (flow cũ không vỡ)',
        () async {
      await dao.insert(const CreateItemDto(name: 'Trứng', price: 5000));
      expect(capturedRow('items')['store_name'], isNull);
      expect(payloadStoreName(), isNull);
    });
  });

  group('updateLocal — AC 7.6 xoá trắng về NULL', () {
    test("storeName: '' → cột về NULL + payload gửi null cho server", () async {
      await dao.updateLocal('id1', storeName: '');

      final changes = verify(() => db.update('items', captureAny(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .captured
          .cast<Map<String, dynamic>>()
          .single;
      expect(changes['store_name'], isNull);

      final payload = jsonDecode(
          verify(() => db.insert('sync_queue', captureAny(),
                  nullColumnHack: any(named: 'nullColumnHack'),
                  conflictAlgorithm: any(named: 'conflictAlgorithm')))
              .captured
              .cast<Map<String, dynamic>>()
              .single['payload'] as String) as Map<String, dynamic>;
      expect(payload['store_name'], isNull);
    });

    test('storeName giá trị mới → trim vào cột + payload', () async {
      await dao.updateLocal('id1', storeName: ' Bách Hóa Xanh ');

      final changes = verify(() => db.update('items', captureAny(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .captured
          .cast<Map<String, dynamic>>()
          .single;
      expect(changes['store_name'], 'Bách Hóa Xanh');
    });

    test('storeName: null (không đổi) → không đụng cột store_name', () async {
      await dao.updateLocal('id1', note: 'ghi chú');

      final changes = verify(() => db.update('items', captureAny(),
              where: any(named: 'where'),
              whereArgs: any(named: 'whereArgs'),
              conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .captured
          .cast<Map<String, dynamic>>()
          .single;
      expect(changes.containsKey('store_name'), isFalse);
    });
  });

  group('getStoreSuggestions — AC 7.4 tần suất giảm dần', () {
    test('Đúng query: GROUP BY nguyên văn, loại rỗng + xoá mềm, LIMIT 10',
        () async {
      when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
            {'store_name': 'CoopMart', 'use_count': 5},
            {'store_name': 'coop mart', 'use_count': 2},
            {'store_name': 'Bách Hóa Xanh', 'use_count': 1},
          ]);

      final result = await dao.getStoreSuggestions();

      expect(result, ['CoopMart', 'coop mart', 'Bách Hóa Xanh']);

      final sql =
          verify(() => db.rawQuery(captureAny(), captureAny())).captured;
      final query = sql[0] as String;
      expect(query, contains('store_name IS NOT NULL'));
      expect(query, contains("store_name != ''"));
      expect(query, contains('is_deleted = 0'),
          reason: 'item xoá mềm không đóng góp tần suất');
      expect(query, contains('GROUP BY store_name'));
      expect(query, contains('ORDER BY'));
      expect(sql[1] as List, [10]); // [ASSUMPTION] tối đa 10 gợi ý
    });

    test('row store_name null (không nên xảy ra) bị lọc khỏi kết quả',
        () async {
      when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
            {'store_name': null, 'use_count': 3},
            {'store_name': 'CoopMart', 'use_count': 1},
          ]);

      expect(await dao.getStoreSuggestions(), ['CoopMart']);
    });
  });

  group('upsertSynced — AC 7.2 backfill từ server', () {
    ItemModel serverItem({String? storeName}) => ItemModel(
          id: 'srv-1',
          name: 'Sữa',
          price: 20000,
          categoryId: 'cat_food',
          categoryName: 'Ăn uống',
          categoryIcon: '🍜',
          categoryColor: '#FF6B6B',
          createdAt: 1000,
          updatedAt: 2000,
          serverId: 'srv-1',
          isSynced: true,
          storeName: storeName,
        );

    test('Item server có store_name → ghi vào row local (is_synced = 1)',
        () async {
      await dao.upsertSynced(serverItem(storeName: 'Circle K'));

      final row = capturedRow('items');
      expect(row['store_name'], 'Circle K');
      expect(row['is_synced'], 1);
    });

    test('Item server không có store_name → row local nhận NULL (server wins)',
        () async {
      await dao.upsertSynced(serverItem());

      expect(capturedRow('items')['store_name'], isNull);
    });
  });

  group('sanitizeStoreName', () {
    test('trim + rỗng → null', () {
      expect(sanitizeStoreName('  CoopMart '), 'CoopMart');
      expect(sanitizeStoreName('   '), isNull);
      expect(sanitizeStoreName(''), isNull);
      expect(sanitizeStoreName(null), isNull);
    });
  });
}
