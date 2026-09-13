import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/daos/item_dao.dart';
import '../database/daos/sync_queue_dao.dart';
import '../models/item_model.dart';
import '../models/sync_models.dart';
import 'sync_api_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncResult {
  final bool isSuccess;
  final int pushedCount;
  final int pulledCount;
  final int conflictsCount;
  final String? errorMessage;

  const SyncResult({
    required this.isSuccess,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.conflictsCount = 0,
    this.errorMessage,
  });
}

/// Bộ não điều phối toàn bộ luồng Auto-Sync 2 chiều (Push & Pull)
class SyncEngine {
  final Database db;
  final SyncQueueDao syncQueueDao;
  final ItemDao itemDao;
  final SyncApiService apiService;
  final Connectivity _connectivity;

  bool _isSyncing = false;
  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Callback thông báo khi trạng thái thay đổi
  void Function(SyncStatus status, SyncResult? result)? onStatusChanged;

  SyncEngine({
    required this.db,
    required this.syncQueueDao,
    required this.itemDao,
    required this.apiService,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  bool get isSyncing => _isSyncing;

  /// Khởi tạo lắng nghe kết nối mạng và kích hoạt auto-sync
  void startListening({Duration periodicInterval = const Duration(minutes: 5)}) {
    // 1. Lắng nghe thay đổi kết nối mạng
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && !_isSyncing) {
        sync();
      }
    });

    // 2. Chạy timer định kỳ nếu app đang mở
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(periodicInterval, (_) {
      if (!_isSyncing) {
        sync();
      }
    });
  }

  /// Huỷ lắng nghe các subscriptions
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
  }

  /// Kích hoạt chu trình đồng bộ hoàn chỉnh (Push rồi Pull)
  Future<SyncResult> sync() async {
    if (_isSyncing) {
      return const SyncResult(
        isSuccess: false,
        errorMessage: 'Một tiến trình đồng bộ đang chạy',
      );
    }

    _isSyncing = true;
    onStatusChanged?.call(SyncStatus.syncing, null);

    try {
      // 1. Giai đoạn PUSH: Đẩy các thay đổi local lên server
      final pushStats = await _executePush();

      // 2. Giai đoạn PULL: Kéo các thay đổi mới từ server về SQLite
      final pullStats = await _executePull();

      // 3. Dọn dẹp queue cũ đã sync quá 7 ngày
      await syncQueueDao.cleanOldSynced();

      final result = SyncResult(
        isSuccess: true,
        pushedCount: pushStats.pushed,
        pulledCount: pullStats.pulled,
        conflictsCount: pushStats.conflicts,
      );

      _isSyncing = false;
      onStatusChanged?.call(SyncStatus.success, result);
      return result;
    } catch (e) {
      _isSyncing = false;
      final result = SyncResult(
        isSuccess: false,
        errorMessage: e.toString(),
      );
      onStatusChanged?.call(SyncStatus.error, result);
      return result;
    }
  }

  /// Thực hiện Push batch lên backend
  Future<({int pushed, int conflicts})> _executePush() async {
    final pendingRecords = await syncQueueDao.getPending(limit: 50);
    if (pendingRecords.isEmpty) {
      return (pushed: 0, conflicts: 0);
    }

    final changes = pendingRecords.map((r) => r.toSyncItemDto()).toList();
    final lastSyncedAt = await syncQueueDao.getLastSyncedAt();

    try {
      final response = await apiService.push(SyncPushDto(
        changes: changes,
        lastSyncAt: lastSyncedAt,
      ));

      final queueIds = pendingRecords.map((r) => r.id).toList();
      await syncQueueDao.markSynced(queueIds, response.serverTimestamp);

      // Cập nhật is_synced = 1 cho các item local tương ứng
      final itemIds = pendingRecords
          .where((r) => r.entityType == 'item')
          .map((r) => r.entityId)
          .toList();

      if (itemIds.isNotEmpty) {
        final placeholders = List.filled(itemIds.length, '?').join(',');
        await db.update(
          'items',
          {'is_synced': 1},
          where: 'id IN ($placeholders)',
          whereArgs: itemIds,
        );
      }

      // Xử lý xung đột nếu server trả về server_wins
      for (final conflict in response.conflicts) {
        if (conflict.resolution == 'server_wins' && conflict.serverData != null) {
          await _applyServerWins(conflict.clientId, conflict.serverData!);
        }
      }

      return (pushed: response.applied, conflicts: response.conflicts.length);
    } catch (e) {
      // Ghi nhận lỗi cho các record để tăng retry
      for (final r in pendingRecords) {
        await syncQueueDao.incrementRetry(r.id, e.toString());
      }
      rethrow;
    }
  }

  /// Thực hiện Pull các thay đổi từ server về
  Future<({int pulled})> _executePull() async {
    final lastSyncedAt = await syncQueueDao.getLastSyncedAt();
    final response = await apiService.pull(since: lastSyncedAt);

    int pulledCount = 0;
    for (final change in response.changes) {
      if (change.table == 'items') {
        if (change.operation == 'INSERT' || change.operation == 'UPDATE') {
          final payloadMap = change.parsedPayload;
          if (payloadMap.isNotEmpty) {
            ItemModel item;
            if (payloadMap.containsKey('purchase_date') || payloadMap.containsKey('category')) {
              item = ItemModel.fromApiJson(payloadMap);
            } else {
              item = ItemModel.fromMap(payloadMap);
            }
            await itemDao.upsertSynced(item);
            pulledCount++;
          }
        } else if (change.operation == 'DELETE') {
          await db.update(
            'items',
            {
              'is_deleted': 1,
              'is_synced': 1,
              'updated_at': change.updatedAt,
            },
            where: 'id = ?',
            whereArgs: [change.clientId],
          );
          pulledCount++;
        }
      }
    }

    // Cập nhật timestamp lần sync mới nhất
    await syncQueueDao.setLastSyncedAt(response.serverTimestamp);

    return (pulled: pulledCount);
  }

  /// Áp dụng phiên bản của server khi xảy ra xung đột mà server wins
  Future<void> _applyServerWins(String clientId, Map<String, dynamic> serverData) async {
    try {
      ItemModel item;
      if (serverData.containsKey('purchase_date') || serverData.containsKey('category')) {
        item = ItemModel.fromApiJson(serverData);
      } else {
        item = ItemModel.fromMap(serverData);
      }
      await itemDao.upsertSynced(item);
    } catch (_) {
      // Fallback nếu serverData chỉ có raw update fields
      await db.update(
        'items',
        {
          ...serverData,
          'is_synced': 1,
        },
        where: 'id = ?',
        whereArgs: [clientId],
      );
    }
  }
}
