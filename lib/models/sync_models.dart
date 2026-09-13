import 'dart:convert';

/// Đơn vị thay đổi dữ liệu một bảng từ client hoặc server
class SyncItemDto {
  final String clientId;
  final String table; // 'items' | 'categories' | 'budgets' | 'price_history'
  final String operation; // 'INSERT' | 'UPDATE' | 'DELETE'
  final String payload; // serialized JSON string
  final int updatedAt; // timestamp ms

  const SyncItemDto({
    required this.clientId,
    required this.table,
    required this.operation,
    required this.payload,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'table': table,
    'operation': operation,
    'payload': payload,
    'updatedAt': updatedAt,
  };

  factory SyncItemDto.fromMap(Map<String, dynamic> map) => SyncItemDto(
    clientId: map['clientId'] as String? ?? '',
    table: map['table'] as String? ?? '',
    operation: map['operation'] as String? ?? 'INSERT',
    payload: map['payload'] as String? ?? '{}',
    updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
  );

  /// Helper lấy payload dưới dạng Map đã giải mã
  Map<String, dynamic> get parsedPayload {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }
}

/// DTO gửi lên POST /sync/push
class SyncPushDto {
  final List<SyncItemDto> changes;
  final int? lastSyncAt;

  const SyncPushDto({
    required this.changes,
    this.lastSyncAt,
  });

  Map<String, dynamic> toMap() => {
    'changes': changes.map((c) => c.toMap()).toList(),
    if (lastSyncAt != null) 'lastSyncAt': lastSyncAt,
  };
}

/// Xung đột dữ liệu trả về từ server
class SyncConflict {
  final String clientId;
  final String resolution; // 'client_wins' | 'server_wins'
  final Map<String, dynamic>? serverData;

  const SyncConflict({
    required this.clientId,
    required this.resolution,
    this.serverData,
  });

  factory SyncConflict.fromMap(Map<String, dynamic> map) => SyncConflict(
    clientId: map['clientId'] as String? ?? '',
    resolution: map['resolution'] as String? ?? 'server_wins',
    serverData: map['serverData'] as Map<String, dynamic>?,
  );
}

/// Phản hồi từ POST /sync/push
class SyncPushResponse {
  final int applied;
  final List<SyncConflict> conflicts;
  final int serverTimestamp;

  const SyncPushResponse({
    required this.applied,
    required this.conflicts,
    required this.serverTimestamp,
  });

  factory SyncPushResponse.fromMap(Map<String, dynamic> map) {
    final conflictsList = (map['conflicts'] as List<dynamic>?)
            ?.map((c) => SyncConflict.fromMap(c as Map<String, dynamic>))
            .toList() ??
        [];

    return SyncPushResponse(
      applied: (map['applied'] as num?)?.toInt() ?? 0,
      conflicts: conflictsList,
      serverTimestamp: (map['serverTimestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Phản hồi từ GET /sync/pull
class SyncPullResponse {
  final List<SyncItemDto> changes;
  final int serverTimestamp;
  final bool hasMore;

  const SyncPullResponse({
    required this.changes,
    required this.serverTimestamp,
    required this.hasMore,
  });

  factory SyncPullResponse.fromMap(Map<String, dynamic> map) {
    final rawChanges = (map['changes'] as List<dynamic>?)
            ?.map((c) => SyncItemDto.fromMap(c as Map<String, dynamic>))
            .toList() ??
        [];

    return SyncPullResponse(
      changes: rawChanges,
      serverTimestamp: (map['serverTimestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      hasMore: map['hasMore'] as bool? ?? false,
    );
  }
}

/// Phản hồi từ GET /sync/status
class SyncStatusResponse {
  final int recordCount;
  final int? lastUpdated;

  const SyncStatusResponse({
    required this.recordCount,
    this.lastUpdated,
  });

  factory SyncStatusResponse.fromMap(Map<String, dynamic> map) => SyncStatusResponse(
    recordCount: (map['recordCount'] as num?)?.toInt() ?? 0,
    lastUpdated: (map['lastUpdated'] as num?)?.toInt(),
  );
}
