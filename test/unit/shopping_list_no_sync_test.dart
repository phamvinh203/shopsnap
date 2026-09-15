import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/database/daos/shopping_list_dao.dart';
import 'package:shopsnap/database/daos/sync_queue_dao.dart';
import 'package:shopsnap/database/daos/item_dao.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/sync_models.dart';
import 'package:shopsnap/services/sync_api_service.dart';
import 'package:shopsnap/services/sync_engine.dart';
import 'package:sqflite/sqflite.dart';

/// AC 6.17 — Shopping list là LOCAL-ONLY:
/// "Given sync engine chạy full sync, Then KHÔNG có change nào với
/// table = 'shopping_list' được gửi lên server".
///
/// Khoá invariant ở 3 tầng:
/// 1. DAO: mọi thao tác CRUD ghi CHỈ vào `shopping_list_items`, không bao giờ
///    enqueue `sync_queue` (không phát sinh request sync).
/// 2. Engine: full sync với queue gồm các entity app THẬT enqueue
///    (item/category/budget/price_history) → request body không chứa
///    'shopping_list' → không 400 validation từ POST /sync/push.
/// 3. Pull: change `table = 'shopping_list'` từ server (giả định) bị bỏ qua.
class MockDatabase extends Mock implements Database {}
class MockSyncQueueDao extends Mock implements SyncQueueDao {}
class MockItemDao extends Mock implements ItemDao {}

http.Response okJson(dynamic data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() {
    // ApiClient đọc token qua TokenStorage (SharedPreferences) — cần mock env.
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<Object?>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(ConflictAlgorithm.replace);
    registerFallbackValue(const SyncPushDto(changes: []));
    registerFallbackValue(const ItemModel(
      id: 'fallback',
      name: 'fallback',
      price: 0,
      categoryId: 'cat_other',
      categoryName: 'Khác',
      categoryIcon: '📦',
      categoryColor: '#DDA0DD',
      createdAt: 0,
      updatedAt: 0,
    ));
  });

  group('AC 6.17 — ShoppingListItemDao không bao giờ enqueue sync', () {
    late MockDatabase db;
    late ShoppingListItemDao dao;

    setUp(() {
      db = MockDatabase();
      dao = ShoppingListItemDao(db);

      when(() => db.insert(any(), any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .thenAnswer((_) async => 1);
      when(() => db.query(any(),
          distinct: any(named: 'distinct'),
          columns: any(named: 'columns'),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          groupBy: any(named: 'groupBy'),
          having: any(named: 'having'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'))).thenAnswer((_) async => []);
      when(() => db.execute(any(), any())).thenAnswer((_) async {});
      when(() => db.update(any(), any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')))
          .thenAnswer((_) async => 1);
      when(() => db.delete(any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => 1);
      when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
            {'c': 0}
          ]);
    });

    void verifyNeverEnqueuedSync() {
      verifyNever(() => db.insert('sync_queue', any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
      // Không thao tác DAO nào ghi ra bảng ngoài shopping_list_items.
      verifyNever(() => db.insert('items', any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
      verifyNever(() => db.insert('price_history', any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
    }

    test('insert / tick / watch / sửa / xoá / markAlert — chỉ ghi bảng list', () async {
      final created = await dao.insert(const CreateShoppingListItemDto(name: 'Sữa tươi'));
      expect(created, isNotNull);
      expect(created!.name, 'Sữa tươi');
      verify(() => db.insert('shopping_list_items', any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm'))).called(1);
      verifyNeverEnqueuedSync();

      await dao.toggleChecked(created.id);
      await dao.toggleWatched(created.id);
      await dao.update(created.id, quantity: 2, expectedPrice: 30000);
      await dao.delete(created.id);
      await dao.markAlertFired(created.id, 28000);
      await dao.clearUnseenAlerts();
      await dao.getAll();
      await dao.getWatched();
      await dao.findById(created.id);
      await dao.countUnseenAlerts();

      verifyNeverEnqueuedSync();
    });

    test('insert tên rỗng → không tạo dòng (AC 6.3) và càng không enqueue', () async {
      final created = await dao.insert(const CreateShoppingListItemDto(name: '   '));
      expect(created, isNull);
      verifyNever(() => db.insert(any(), any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
    });
  });

  group('AC 6.17 — full sync không gửi change nào có table = shopping_list', () {
    // MockClient phân tuyến theo path: push trả applied, pull trả changes.
    // SyncApiService là object THẬT (không mocktail) → assert được HTTP body.
    SyncApiService buildApi({
      required void Function(http.BaseRequest, String? body) onRequest,
      required Map<String, dynamic> Function(Uri url) pullResponse,
    }) {
      return SyncApiService(ApiClient(
        client: MockClient((req) async {
          onRequest(req, req.body);
          if (req.url.path.endsWith('/sync/pull')) {
            return okJson(pullResponse(req.url));
          }
          return okJson({
            // 4 = số record pending đẩy lên (khớp queue của test).
            'applied': 4,
            'conflicts': [],
            'serverTimestamp': 1726000001000,
          });
        }),
      ));
    }

    test('push chỉ chứa entity trong whitelist của BE (không 400 validation)', () async {
      final bodies = <String>[];
      final apiService = buildApi(
        onRequest: (_, body) => bodies.add(body ?? ''),
        pullResponse: (_) => {
          'changes': [],
          'serverTimestamp': 1726000002000,
          'hasMore': false,
        },
      );

      final db = MockDatabase();
      final queueDao = MockSyncQueueDao();
      final itemDao = MockItemDao();

      // Queue chỉ gồm entity app THẬT enqueue (ItemDao/BudgetDao/CategoryDao).
      // ShoppingListDao (group trên) chứng minh list KHÔNG enqueue gì cả.
      const whitelistTables = ['items', 'categories', 'budgets', 'price_history'];
      var i = 0;
      final pending = whitelistTables
          .map((t) => SyncQueueRecord(
                id: 'q-${i++}',
                entityType: switch (t) {
                  'items' => 'item',
                  'categories' => 'category',
                  'budgets' => 'budget',
                  _ => 'price_history',
                },
                entityId: 'e$i',
                operation: 'INSERT',
                payload: jsonEncode({'name': 'x$i', 'price': 1000}),
                createdAt: 1000 + i,
              ))
          .toList();

      when(() => queueDao.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => pending);
      when(() => queueDao.getLastSyncedAt()).thenAnswer((_) async => null);
      when(() => queueDao.markSynced(any(), any())).thenAnswer((_) async {});
      when(() => queueDao.cleanOldSynced()).thenAnswer((_) async => 0);
      when(() => db.update('items', any(),
          where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => 1);
      when(() => queueDao.setLastSyncedAt(any())).thenAnswer((_) async {});

      final engine = SyncEngine(
        db: db,
        syncQueueDao: queueDao,
        itemDao: itemDao,
        apiService: apiService,
      );

      final result = await engine.sync();
      expect(result.isSuccess, isTrue);
      expect(result.pushedCount, 4);

      // Request body full sync KHÔNG chứa shopping_list → không thể dính 400
      // validation `@IsIn([...])` của SyncItemDto.
      final pushBodies =
          bodies.where((b) => b.contains('"clientId"')).toList();
      expect(pushBodies, isNotEmpty);
      for (final body in pushBodies) {
        expect(body.contains('shopping_list'), isFalse,
            reason: 'Request sync không được chứa shopping_list (AC 6.17)');
      }

      // Toàn bộ table gửi lên đều thuộc whitelist của BE SyncItemDto.
      final pushedTables =
          pending.map((r) => r.toSyncItemDto().table).toSet();
      expect(pushedTables.difference(whitelistTables.toSet()), isEmpty);
    });

    test('pull change table = shopping_list từ server → bị bỏ qua, không ghi local',
        () async {
      final apiService = buildApi(
        onRequest: (_, __) {},
        pullResponse: (_) => {
          'changes': [
            {
              'clientId': 'sl-1',
              'table': 'shopping_list',
              'operation': 'INSERT',
              'payload': jsonEncode({'id': 'sl-1', 'name': 'Sữa'}),
              'updatedAt': 1726000000000,
            },
            {
              'clientId': 'it-1',
              'table': 'items',
              'operation': 'INSERT',
              'payload': jsonEncode({
                'id': 'it-1',
                'name': 'Táo',
                'price': 12000,
                'category_id': 'cat_food',
                'created_at': 1726000000000,
                'updated_at': 1726000000000,
              }),
              'updatedAt': 1726000000000,
            },
          ],
          'serverTimestamp': 1726000003000,
          'hasMore': false,
        },
      );

      final db = MockDatabase();
      final queueDao = MockSyncQueueDao();
      final itemDao = MockItemDao();

      when(() => queueDao.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => []);
      when(() => queueDao.getLastSyncedAt()).thenAnswer((_) async => 1000);
      when(() => queueDao.cleanOldSynced()).thenAnswer((_) async => 0);
      when(() => queueDao.setLastSyncedAt(any())).thenAnswer((_) async {});
      when(() => itemDao.upsertSynced(any())).thenAnswer((_) async {});

      final engine = SyncEngine(
        db: db,
        syncQueueDao: queueDao,
        itemDao: itemDao,
        apiService: apiService,
      );

      final result = await engine.sync();

      // Chỉ item hợp lệ được pull (pulled = 1); shopping_list bị bỏ qua.
      expect(result.isSuccess, isTrue);
      expect(result.pulledCount, 1);
      verify(() => itemDao.upsertSynced(any())).called(1);
      verifyNever(() => db.insert('shopping_list_items', any(),
          nullColumnHack: any(named: 'nullColumnHack'),
          conflictAlgorithm: any(named: 'conflictAlgorithm')));
    });
  });
}
