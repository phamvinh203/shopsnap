import '../network/api_config.dart';

abstract class AppConstants {
  static const dbName    = 'shopsnap.db';
  static const dbVersion = 4;

  // Budget alert thresholds
  static const budgetWarnRatio   = 0.80;
  static const budgetDangerRatio = 1.00;

  // Sync
  static const syncBatchSize        = 50;
  static const syncIntervalMinutes  = 5;

  // Price comparison
  static const priceHistoryDays   = 90;
  static const priceGoodDealRatio = 0.90; // ≤ 90% avg = deal

  // Image
  static const imageMaxWidth  = 1080;
  static const imageMaxHeight = 1080;
  static const imageQuality   = 85;

  // Backend — chuyển sang core/network/api_config.dart (hỗ trợ --dart-define
  // SHOPSNAP_API_URL, tự chọn 10.0.2.2 trên Android emulator)
  static String get backendBaseUrl => ApiConfig.baseUrl;

  // App Version & Update
  static const appVersion = '1.0.5';
  static const githubRepo = 'phamvinh203/shopsnap';
}
