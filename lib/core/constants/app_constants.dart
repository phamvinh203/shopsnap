abstract class AppConstants {
  static const dbName    = 'shopsnap.db';
  static const dbVersion = 3;

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

  // Backend
  static const backendBaseUrl = 'http://10.0.2.2:3000/api/v1'; // Android emulator → localhost
  // static const backendBaseUrl = 'http://localhost:3000/api/v1'; // iOS simulator
  // static const backendBaseUrl = 'https://api.shopsnap.vn/api/v1'; // Production
}
