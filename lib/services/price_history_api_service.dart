import '../core/network/api_client.dart';
import '../models/price_history_model.dart';

class PriceHistoryApiService {
  final ApiClient _client;

  PriceHistoryApiService(this._client);

  /// Tra cứu lịch sử giá từ server (GET /items/price-history)
  Future<PriceHistorySummary?> getPriceHistory({
    String? name,
    String? barcode,
    int limit = 30,
  }) async {
    try {
      final data = await _client.get(
        '/items/price-history',
        auth: true,
        query: {
          if (name != null && name.isNotEmpty) 'name': name,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
          'limit': limit.toString(),
        },
      );

      if (data == null) return null;
      return PriceHistorySummary.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách sản phẩm hay mua từ server (GET /items/price-history/frequent)
  Future<List<FrequentTrackedItem>> getFrequentTrackedItems({int limit = 10}) async {
    try {
      final data = await _client.get(
        '/items/price-history/frequent',
        auth: true,
        query: {'limit': limit.toString()},
      );

      if (data == null || data is! List) return [];
      return data
          .map((item) => FrequentTrackedItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
