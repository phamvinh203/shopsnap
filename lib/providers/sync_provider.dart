import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/item_dao.dart';
import '../database/daos/sync_queue_dao.dart';
import '../services/sync_api_service.dart';
import '../services/sync_engine.dart';
import 'all_budgets_provider.dart';
import 'auth_provider.dart';
import 'categories_provider.dart';
import 'database_provider.dart';
import 'items_provider.dart';

/// Dịch vụ Sync API
final syncApiServiceProvider = Provider<SyncApiService>((ref) {
  return SyncApiService(ref.watch(apiClientProvider));
});

/// DAO quản lý hàng đợi Sync Local
final syncQueueDaoProvider = FutureProvider<SyncQueueDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SyncQueueDao(db);
});

/// Instance của SyncEngine điều phối
final syncEngineProvider = FutureProvider<SyncEngine>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final queueDao = SyncQueueDao(db);
  final itemDao = ItemDao(db);
  final api = ref.watch(syncApiServiceProvider);

  final engine = SyncEngine(
    db: db,
    syncQueueDao: queueDao,
    itemDao: itemDao,
    apiService: api,
  );

  // Khởi động lắng nghe kết nối mạng
  engine.startListening();
  ref.onDispose(() => engine.dispose());

  return engine;
});

/// Trạng thái đồng bộ để UI hiển thị (Sync Status Pill, Refresh Indicator)
class SyncUIState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final SyncResult? lastResult;
  final String? errorMessage;

  const SyncUIState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.lastResult,
    this.errorMessage,
  });

  bool get isSyncing => status == SyncStatus.syncing;

  SyncUIState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    int? pendingCount,
    SyncResult? lastResult,
    String? errorMessage,
  }) =>
      SyncUIState(
        status: status ?? this.status,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pendingCount: pendingCount ?? this.pendingCount,
        lastResult: lastResult ?? this.lastResult,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class SyncNotifier extends StateNotifier<SyncUIState> {
  final Ref ref;

  SyncNotifier(this.ref) : super(const SyncUIState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final queueDao = await ref.read(syncQueueDaoProvider.future);
      final count = await queueDao.getPendingCount();
      final lastMs = await queueDao.getLastSyncedAt();

      state = state.copyWith(
        pendingCount: count,
        lastSyncedAt: lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null,
      );

      final engine = await ref.read(syncEngineProvider.future);
      engine.onStatusChanged = (status, result) {
        _onEngineStatusChanged(status, result);
      };
    } catch (_) {}
  }

  void _onEngineStatusChanged(SyncStatus status, SyncResult? result) async {
    int pending = state.pendingCount;
    DateTime? lastSynced = state.lastSyncedAt;

    try {
      final queueDao = await ref.read(syncQueueDaoProvider.future);
      pending = await queueDao.getPendingCount();
      final lastMs = await queueDao.getLastSyncedAt();
      if (lastMs != null) {
        lastSynced = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
    } catch (_) {}

    state = state.copyWith(
      status: status,
      lastResult: result,
      pendingCount: pending,
      lastSyncedAt: lastSynced,
      errorMessage: result?.errorMessage,
    );

    // Khi đồng bộ thành công, làm tươi lại danh sách items và budgets trên UI
    if (status == SyncStatus.success) {
      ref.invalidate(itemsProvider);
      ref.invalidate(allBudgetsProvider);
      ref.invalidate(categoriesProvider);
    }
  }

  /// Kích hoạt đồng bộ thủ công từ UI
  Future<SyncResult?> triggerSync() async {
    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Vui lòng đăng nhập để đồng bộ dữ liệu đám mây',
      );
      return null;
    }

    try {
      final engine = await ref.read(syncEngineProvider.future);
      final result = await engine.sync();
      return result;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Cập nhật lại số lượng items chưa sync
  Future<void> refreshPendingCount() async {
    try {
      final queueDao = await ref.read(syncQueueDaoProvider.future);
      final count = await queueDao.getPendingCount();
      state = state.copyWith(pendingCount: count);
    } catch (_) {}
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncUIState>((ref) {
  return SyncNotifier(ref);
});
