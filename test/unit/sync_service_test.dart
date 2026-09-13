import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/network/api_client.dart';
import 'package:shopsnap/database/daos/item_dao.dart';
import 'package:shopsnap/database/daos/sync_queue_dao.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/sync_models.dart';
import 'package:shopsnap/services/sync_api_service.dart';
import 'package:shopsnap/services/sync_engine.dart';
import 'package:sqflite/sqflite.dart';

class MockSyncQueueDao extends Mock implements SyncQueueDao {}
class MockItemDao extends Mock implements ItemDao {}
class MockSyncApiService extends Mock implements SyncApiService {}
class MockDatabase extends Mock implements Database {}

http.Response okJson(dynamic data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() async {
    registerFallbackValue(SyncPushDto(changes: []));
    registerFallbackValue(ItemModel(
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
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncModels Test', () {
    test('SyncItemDto toMap & fromMap & parsedPayload', () {
      final dto = SyncItemDto(
        clientId: 'item-1',
        table: 'items',
        operation: 'INSERT',
        payload: jsonEncode({'name': 'Bánh mì', 'price': 15000}),
        updatedAt: 1726000000000,
      );

      final map = dto.toMap();
      expect(map['clientId'], 'item-1');
      expect(map['table'], 'items');
      expect(map['operation'], 'INSERT');

      final reconstructed = SyncItemDto.fromMap(map);
      expect(reconstructed.clientId, 'item-1');
      expect(reconstructed.parsedPayload['name'], 'Bánh mì');
      expect(reconstructed.parsedPayload['price'], 15000);
    });

    test('SyncPushResponse & SyncConflict parse', () {
      final json = {
        'applied': 2,
        'conflicts': [
          {
            'clientId': 'item-c1',
            'resolution': 'server_wins',
            'serverData': {'name': 'Bánh mì bì', 'price': 20000},
          }
        ],
        'serverTimestamp': 1726000001000,
      };

      final res = SyncPushResponse.fromMap(json);
      expect(res.applied, 2);
      expect(res.conflicts.length, 1);
      expect(res.conflicts.first.clientId, 'item-c1');
      expect(res.conflicts.first.resolution, 'server_wins');
      expect(res.conflicts.first.serverData?['name'], 'Bánh mì bì');
      expect(res.serverTimestamp, 1726000001000);
    });

    test('SyncPullResponse parse', () {
      final json = {
        'changes': [
          {
            'clientId': 'item-p1',
            'table': 'items',
            'operation': 'UPDATE',
            'payload': jsonEncode({'id': 'item-p1', 'name': 'Sữa chua'}),
            'updatedAt': 1726000002000,
          }
        ],
        'serverTimestamp': 1726000003000,
        'hasMore': false,
      };

      final res = SyncPullResponse.fromMap(json);
      expect(res.changes.length, 1);
      expect(res.changes.first.clientId, 'item-p1');
      expect(res.serverTimestamp, 1726000003000);
      expect(res.hasMore, false);
    });

    test('SyncQueueRecord toSyncItemDto mapping table names', () {
      final r1 = SyncQueueRecord(
        id: 'q1',
        entityType: 'item',
        entityId: 'id1',
        operation: 'INSERT',
        payload: '{}',
        createdAt: 1000,
      );
      expect(r1.toSyncItemDto().table, 'items');

      final r2 = SyncQueueRecord(
        id: 'q2',
        entityType: 'budget',
        entityId: 'id2',
        operation: 'UPDATE',
        payload: '{}',
        createdAt: 1000,
      );
      expect(r2.toSyncItemDto().table, 'budgets');

      final r3 = SyncQueueRecord(
        id: 'q3',
        entityType: 'category',
        entityId: 'id3',
        operation: 'DELETE',
        payload: '{}',
        createdAt: 1000,
      );
      expect(r3.toSyncItemDto().table, 'categories');
    });
  });

  group('SyncApiService Test', () {
    test('push (POST /sync/push) gửi đúng headers và body', () async {
      final urls = <Uri>[];
      final bodies = <String>[];

      final service = SyncApiService(ApiClient(
        client: MockClient((req) async {
          urls.add(req.url);
          bodies.add(req.body);
          return okJson({
            'applied': 1,
            'conflicts': [],
            'serverTimestamp': 1726000005000,
          });
        }),
      ));

      final dto = SyncPushDto(
        changes: [
          SyncItemDto(
            clientId: 'it-1',
            table: 'items',
            operation: 'INSERT',
            payload: '{"name":"test"}',
            updatedAt: 1726000004000,
          ),
        ],
        lastSyncAt: 1726000000000,
      );

      final res = await service.push(dto);

      expect(urls.first.path, '/api/v1/sync/push');
      expect(bodies.first, contains('"clientId":"it-1"'));
      expect(res.applied, 1);
      expect(res.serverTimestamp, 1726000005000);
    });

    test('pull (GET /sync/pull) gắn param since và parse changes', () async {
      final urls = <Uri>[];

      final service = SyncApiService(ApiClient(
        client: MockClient((req) async {
          urls.add(req.url);
          return okJson({
            'changes': [
              {
                'clientId': 'it-server',
                'table': 'items',
                'operation': 'INSERT',
                'payload': '{"id":"it-server","name":"Server item"}',
                'updatedAt': 1726000006000,
              }
            ],
            'serverTimestamp': 1726000007000,
            'hasMore': false,
          });
        }),
      ));

      final res = await service.pull(since: 1726000000000);

      expect(urls.first.path, '/api/v1/sync/pull');
      expect(urls.first.queryParameters['since'], '1726000000000');
      expect(res.changes.length, 1);
      expect(res.changes.first.clientId, 'it-server');
    });

    test('status (GET /sync/status) trả về recordCount', () async {
      final service = SyncApiService(ApiClient(
        client: MockClient((req) async {
          return okJson({
            'recordCount': 42,
            'lastUpdated': 1726000008000,
          });
        }),
      ));

      final res = await service.status();
      expect(res.recordCount, 42);
      expect(res.lastUpdated, 1726000008000);
    });
  });

  group('SyncEngine Orchestration Test', () {
    late MockDatabase mockDb;
    late MockSyncQueueDao mockQueueDao;
    late MockItemDao mockItemDao;
    late MockSyncApiService mockApiService;
    late SyncEngine engine;

    setUp(() {
      mockDb = MockDatabase();
      mockQueueDao = MockSyncQueueDao();
      mockItemDao = MockItemDao();
      mockApiService = MockSyncApiService();

      engine = SyncEngine(
        db: mockDb,
        syncQueueDao: mockQueueDao,
        itemDao: mockItemDao,
        apiService: mockApiService,
      );
    });

    test('sync() khi queue rỗng: không gọi push, chỉ pull và cleanOldSynced', () async {
      when(() => mockQueueDao.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => []);
      when(() => mockQueueDao.getLastSyncedAt())
          .thenAnswer((_) async => 1000);
      when(() => mockApiService.pull(since: 1000))
          .thenAnswer((_) async => SyncPullResponse(
                changes: [],
                serverTimestamp: 2000,
                hasMore: false,
              ));
      when(() => mockQueueDao.setLastSyncedAt(2000))
          .thenAnswer((_) async {});
      when(() => mockQueueDao.cleanOldSynced())
          .thenAnswer((_) async => 0);

      final result = await engine.sync();

      expect(result.isSuccess, isTrue);
      expect(result.pushedCount, 0);
      expect(result.pulledCount, 0);

      verifyNever(() => mockApiService.push(any()));
      verify(() => mockApiService.pull(since: 1000)).called(1);
      verify(() => mockQueueDao.setLastSyncedAt(2000)).called(1);
      verify(() => mockQueueDao.cleanOldSynced()).called(1);
    });

    test('sync() khi có pending items: push thành công rồi pull thay đổi', () async {
      final pendingItem = SyncQueueRecord(
        id: 'q-1',
        entityType: 'item',
        entityId: 'item-local-1',
        operation: 'INSERT',
        payload: jsonEncode({'name': 'Táo', 'price': 10000}),
        createdAt: 1500,
      );

      when(() => mockQueueDao.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [pendingItem]);
      when(() => mockQueueDao.getLastSyncedAt())
          .thenAnswer((_) async => null);

      when(() => mockApiService.push(any()))
          .thenAnswer((_) async => SyncPushResponse(
                applied: 1,
                conflicts: [],
                serverTimestamp: 2500,
              ));

      when(() => mockQueueDao.markSynced(['q-1'], 2500))
          .thenAnswer((_) async {});
      when(() => mockDb.update('items', any(), where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => 1);

      final serverChange = SyncItemDto(
        clientId: 'item-server-2',
        table: 'items',
        operation: 'INSERT',
        payload: jsonEncode({
          'id': 'item-server-2',
          'name': 'Cam',
          'price': 20000,
          'category_id': 'cat_food',
          'created_at': 2000,
          'updated_at': 2000,
        }),
        updatedAt: 2000,
      );

      when(() => mockApiService.pull(since: null))
          .thenAnswer((_) async => SyncPullResponse(
                changes: [serverChange],
                serverTimestamp: 3000,
                hasMore: false,
              ));

      when(() => mockItemDao.upsertSynced(any()))
          .thenAnswer((_) async {});
      when(() => mockQueueDao.setLastSyncedAt(3000))
          .thenAnswer((_) async {});
      when(() => mockQueueDao.cleanOldSynced())
          .thenAnswer((_) async => 0);

      final result = await engine.sync();

      expect(result.isSuccess, isTrue);
      expect(result.pushedCount, 1);
      expect(result.pulledCount, 1);

      verify(() => mockApiService.push(any())).called(1);
      verify(() => mockQueueDao.markSynced(['q-1'], 2500)).called(1);
      verify(() => mockItemDao.upsertSynced(any())).called(1);
      verify(() => mockQueueDao.setLastSyncedAt(3000)).called(1);
    });

    test('sync() khi server trả conflict server_wins: áp dụng serverData đè local', () async {
      final pendingItem = SyncQueueRecord(
        id: 'q-conflict',
        entityType: 'item',
        entityId: 'item-conflict-1',
        operation: 'UPDATE',
        payload: jsonEncode({'name': 'Táo cũ', 'price': 10000}),
        createdAt: 1000,
      );

      when(() => mockQueueDao.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [pendingItem]);
      when(() => mockQueueDao.getLastSyncedAt())
          .thenAnswer((_) async => null);

      when(() => mockApiService.push(any()))
          .thenAnswer((_) async => SyncPushResponse(
                applied: 0,
                conflicts: [
                  SyncConflict(
                    clientId: 'item-conflict-1',
                    resolution: 'server_wins',
                    serverData: {
                      'id': 'item-conflict-1',
                      'name': 'Táo mới từ server',
                      'price': 15000,
                      'category_id': 'cat_food',
                      'created_at': 1000,
                      'updated_at': 2000,
                    },
                  ),
                ],
                serverTimestamp: 2000,
              ));

      when(() => mockQueueDao.markSynced(['q-conflict'], 2000))
          .thenAnswer((_) async {});
      when(() => mockDb.update('items', any(), where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => 1);
      when(() => mockItemDao.upsertSynced(any()))
          .thenAnswer((_) async {});

      when(() => mockApiService.pull(since: null))
          .thenAnswer((_) async => SyncPullResponse(
                changes: [],
                serverTimestamp: 2000,
                hasMore: false,
              ));
      when(() => mockQueueDao.setLastSyncedAt(2000))
          .thenAnswer((_) async {});
      when(() => mockQueueDao.cleanOldSynced())
          .thenAnswer((_) async => 0);

      final result = await engine.sync();

      expect(result.isSuccess, isTrue);
      expect(result.conflictsCount, 1);
      verify(() => mockItemDao.upsertSynced(any())).called(1);
    });

    test('sync() khi API ném Exception: ghi nhận lỗi, tăng retry và trả isSuccess false', () async {
      final pendingItem = SyncQueueRecord(
        id: 'q-err',
        entityType: 'item',
        entityId: 'it-err',
        operation: 'INSERT',
        payload: '{}',
        createdAt: 1000,
      );

      when(() => mockQueueDao.getPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [pendingItem]);
      when(() => mockQueueDao.getLastSyncedAt())
          .thenAnswer((_) async => null);

      when(() => mockApiService.push(any()))
          .thenThrow(Exception('Network timeout'));

      when(() => mockQueueDao.incrementRetry('q-err', any()))
          .thenAnswer((_) async {});

      final result = await engine.sync();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Network timeout'));
      verify(() => mockQueueDao.incrementRetry('q-err', any())).called(1);
    });
  });
}
