import '../core/network/api_client.dart';
import '../models/sync_models.dart';

/// Dịch vụ giao tiếp với các API đồng bộ của Backend:
/// - POST /sync/push: Đẩy các thay đổi offline lên cloud
/// - GET  /sync/pull: Kéo các bản ghi mới từ cloud về
/// - GET  /sync/status: Kiểm tra trạng thái sync của user
class SyncApiService {
  final ApiClient client;

  SyncApiService(this.client);

  /// Đẩy các thay đổi local lên server
  Future<SyncPushResponse> push(SyncPushDto dto) async {
    final res = await client.post(
      '/sync/push',
      body: dto.toMap(),
      auth: true,
    );
    return SyncPushResponse.fromMap(res as Map<String, dynamic>);
  }

  /// Kéo các thay đổi từ server về từ mốc [since] (ms)
  Future<SyncPullResponse> pull({int? since}) async {
    final query = <String, String>{
      if (since != null) 'since': since.toString(),
    };
    final res = await client.get(
      '/sync/pull',
      query: query.isNotEmpty ? query : null,
      auth: true,
    );
    return SyncPullResponse.fromMap(res as Map<String, dynamic>);
  }

  /// Lấy trạng thái đồng bộ của user trên server
  Future<SyncStatusResponse> status() async {
    final res = await client.get(
      '/sync/status',
      auth: true,
    );
    return SyncStatusResponse.fromMap(res as Map<String, dynamic>);
  }
}
