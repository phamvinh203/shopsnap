import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/export_service.dart';
import 'auth_provider.dart';

/// ExportService dùng chung — F-#11. Lấy ApiClient (token + refresh) từ
/// [apiClientProvider]; dependency platform (path_provider/share_plus) giữ
/// mặc định, test override provider này bằng fake.
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.watch(apiClientProvider));
});

/// File export gần nhất TRONG PHIÊN (AC 11.3 — share lại không cần export
/// lần nữa). Không persist: phiên mới → xuất lại để chắc chắn file còn tồn tại.
final lastExportProvider = StateProvider<ExportOutcome?>((ref) => null);
