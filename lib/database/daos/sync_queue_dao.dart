import 'package:sqflite/sqflite.dart';
import '../../models/sync_models.dart';

class SyncQueueRecord {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payload;
  final int createdAt;
  final int? syncedAt;
  final int retryCount;
  final String? errorMessage;

  const SyncQueueRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  factory SyncQueueRecord.fromMap(Map<String, dynamic> map) => SyncQueueRecord(
    id: map['id'] as String,
    entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String,
    operation: map['operation'] as String,
    payload: map['payload'] as String,
    createdAt: (map['created_at'] as num).toInt(),
    syncedAt: (map['synced_at'] as num?)?.toInt(),
    retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
    errorMessage: map['error_message'] as String?,
  );

  SyncItemDto toSyncItemDto() {
    // Map entity_type (item, budget, category) sang tên bảng backend
    final table = switch (entityType) {
      'item' => 'items',
      'budget' => 'budgets',
      'category' => 'categories',
      'price_history' => 'price_history',
      _ => '${entityType}s',
    };

    return SyncItemDto(
      clientId: entityId,
      table: table,
      operation: operation,
      payload: payload,
      updatedAt: createdAt,
    );
  }
}

class SyncQueueDao {
  final Database db;

  static const String keyLastSyncedAt = 'last_synced_at';
  static const int maxRetryCount = 3;

  SyncQueueDao(this.db);

  /// Lấy các bản ghi chưa sync, chưa vượt quá số lần retry
  Future<List<SyncQueueRecord>> getPending({int limit = 50}) async {
    final rows = await db.query(
      'sync_queue',
      where: 'synced_at IS NULL AND retry_count < ?',
      whereArgs: [maxRetryCount],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SyncQueueRecord.fromMap).toList();
  }

  /// Đếm số lượng thay đổi chưa đồng bộ
  Future<int> getPendingCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE synced_at IS NULL AND retry_count < ?',
      [maxRetryCount],
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Đánh dấu các bản ghi đã sync thành công
  Future<void> markSynced(List<String> queueIds, int syncedAt) async {
    if (queueIds.isEmpty) return;
    final placeholders = List.filled(queueIds.length, '?').join(',');
    await db.update(
      'sync_queue',
      {'synced_at': syncedAt, 'error_message': null},
      where: 'id IN ($placeholders)',
      whereArgs: queueIds,
    );
  }

  /// Tăng số lần thử thất bại và lưu thông báo lỗi
  Future<void> incrementRetry(String id, String error) async {
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET retry_count = retry_count + 1, error_message = ? 
      WHERE id = ?
    ''', [error, id]);
  }

  /// Dọn dẹp các bản ghi cũ đã sync để tránh phình database local
  Future<int> cleanOldSynced({Duration olderThan = const Duration(days: 7)}) async {
    final threshold = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
    return db.delete(
      'sync_queue',
      where: 'synced_at IS NOT NULL AND synced_at < ?',
      whereArgs: [threshold],
    );
  }

  /// Đọc giá trị từ bảng sync_metadata
  Future<String?> getMetadata(String key) async {
    final rows = await db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Lưu hoặc cập nhật giá trị vào sync_metadata
  Future<void> setMetadata(String key, String value) async {
    await db.insert(
      'sync_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy timestamp lần sync cuối cùng
  Future<int?> getLastSyncedAt() async {
    final str = await getMetadata(keyLastSyncedAt);
    if (str == null) return null;
    return int.tryParse(str);
  }

  /// Cập nhật timestamp lần sync cuối cùng
  Future<void> setLastSyncedAt(int timestamp) async {
    await setMetadata(keyLastSyncedAt, timestamp.toString());
  }
}
