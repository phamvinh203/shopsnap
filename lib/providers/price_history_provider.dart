import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/deal_badge.dart';
import '../database/daos/price_history_dao.dart';
import '../models/price_history_model.dart';
import '../services/price_history_api_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final priceHistoryApiServiceProvider = Provider<PriceHistoryApiService>((ref) {
  return PriceHistoryApiService(ref.watch(apiClientProvider));
});

/// Danh sách các mặt hàng mua nhiều nhất để gợi ý theo dõi giá
final frequentTrackedItemsProvider = FutureProvider<List<FrequentTrackedItem>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final dao = PriceHistoryDao(db);

  // 1. Lấy từ SQLite local trước
  final localItems = await dao.getFrequentItems(limit: 10);

  // 2. Nếu đã đăng nhập, thử lấy thêm từ server để đồng bộ
  final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
  if (authenticated) {
    try {
      final serverItems = await ref.watch(priceHistoryApiServiceProvider).getFrequentTrackedItems(limit: 10);
      if (serverItems.isNotEmpty) {
        return serverItems;
      }
    } catch (_) {}
  }

  return localItems;
});

class PriceHistoryQuery {
  final String? name;
  final String? barcode;

  const PriceHistoryQuery({this.name, this.barcode});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceHistoryQuery &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          barcode == other.barcode;

  @override
  int get hashCode => Object.hash(name, barcode);
}

/// Provider tra cứu lịch sử giá theo query (Offline-First)
final priceHistorySummaryProvider =
    FutureProvider.family<PriceHistorySummary?, PriceHistoryQuery>((ref, query) async {
  if ((query.name == null || query.name!.trim().isEmpty) &&
      (query.barcode == null || query.barcode!.trim().isEmpty)) {
    return null;
  }

  final db = await ref.watch(databaseProvider.future);
  final dao = PriceHistoryDao(db);

  // 1. Tra cứu SQLite local
  final localSummary = await dao.getPriceHistory(
    name: query.name,
    barcode: query.barcode,
  );

  // 2. Nếu đã đăng nhập, thử lấy từ server
  final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
  if (authenticated) {
    try {
      final serverSummary = await ref.watch(priceHistoryApiServiceProvider).getPriceHistory(
        name: query.name,
        barcode: query.barcode,
      );
      if (serverSummary != null && serverSummary.points.isNotEmpty) {
        return serverSummary;
      }
    } catch (_) {}
  }

  return localSummary;
});

/// State Provider lưu query tìm kiếm hiện tại trên màn hình PriceHistoryScreen
final selectedPriceQueryProvider = StateProvider<PriceHistoryQuery?>((ref) => null);

/// F-#1 Deal Badge: đánh giá giá hiện tại cho query (tính từ summary đã có).
///
/// - Dữ liệu user-scoped (AC 1.10): nguồn là `priceHistorySummaryProvider`
///   (server per-user + SQLite của thiết bị).
/// - Threshold đọc từ `deal_threshold_percent` BE trả trong response; thiếu /
///   invalid → default 5% (AC 1.11).
/// - Trả `null` khi KHÔNG có price history → UI không render card (AC 1.6).
final dealBadgeProvider =
    Provider.family<DealBadgeResult?, PriceHistoryQuery>((ref, query) {
  final summary = ref.watch(priceHistorySummaryProvider(query)).valueOrNull;
  if (summary == null || summary.points.isEmpty) return null;

  return computeDealBadge(
    current: summary.latestPrice,
    avg: summary.avgPrice,
    min: summary.minPrice,
    previous: summary.previousPrice,
    recordCount: summary.totalRecords > 0
        ? summary.totalRecords
        : summary.points.length,
    thresholdPercent:
        resolveDealThreshold(summary.dealThresholdPercent),
  );
});
