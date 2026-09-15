import '../network/api_config.dart';

abstract class AppConstants {
  static const dbName    = 'shopsnap.db';
  static const dbVersion = 7;

  // M-3 Merchant (AC 7.4): tối đa gợi ý "Nơi mua" theo tần suất — [ASSUMPTION]
  // spec ghi "tối đa 10 gợi ý"; đặt MỘT nơi duy nhất.
  static const storeSuggestionLimit = 10;

  // Budget alert thresholds
  static const budgetWarnRatio   = 0.80;
  static const budgetDangerRatio = 1.00;

  // Sync
  static const syncBatchSize        = 50;
  static const syncIntervalMinutes  = 5;

  // Price comparison
  static const priceHistoryDays   = 90;
  static const priceGoodDealRatio = 0.90; // ≤ 90% avg = deal

  // F-#6 Price Watch (AC 6.14): ngưỡng giảm giá bật alert — configurable,
  // đặt MỘT nơi duy nhất; F-#12 (Smart Notification) dùng chung giá trị này.
  static const double priceWatchDropPercent = 10.0;

  // F-#5 P1 Receipt Intelligence — tham số khung duplicate detection
  // (spec: 7 ngày / 10% — configurable, đặt MỘT nơi duy nhất) + BULK_MAX
  // của POST /items/bulk (chặn ở client TRƯỚC khi gọi API — AC 5.8).
  static const receiptDuplicateWindowDays = 7;
  static const double receiptDuplicatePriceTolerance = 0.10; // |Δgiá| / giá cũ
  static const receiptBulkMax = 50;

  // M-1 F-#5 Phase 2 Auto-match — ngưỡng tin cậy auto-match (AC 5.20): MỘT
  // constant duy nhất. Điểm từng nhánh (barcode = 1.0, tên = 0.85) khai báo
  // trong `receipt_auto_match.dart`; chỉ auto-tick khi điểm nhánh >= ngưỡng.
  static const double receiptAutoMatchConfidence = 0.80;

  // M-2 Recurring Expenses — ngưỡng phát hiện gợi ý (AC 4.8): MỖI giá trị đặt
  // MỘT nơi duy nhất, pure function `recurring_suggest.dart` đọc từ đây.
  // [ASSUMPTION] "3 tháng gần nhất" = 90 ngày (spec ghi [ASSUMPTION] số này).
  static const recurringScanDays          = 90; // cửa sổ quét lịch sử mua
  static const recurringMinOccurrences    = 3;  // ≥ 3 lần mua mới gợi ý
  static const recurringMinMedianGapDays  = 25; // median gap trong [25, 35] ngày
  static const recurringMaxMedianGapDays  = 35; // (~1 lần/tháng)
  static const recurringMaxGapDays        = 45; // không gap nào > 45 ngày (chống nhiễu)

  // M-2 (AC 4.3): giới hạn field khi thêm/sửa khoản định kỳ. due_day chặn
  // 1..28 để không lệch tháng (tháng 2 không có ngày 30/31 — [ASSUMPTION]).
  static const recurringDueDayMin             = 1;
  static const recurringDueDayMax             = 28;
  static const recurringRemindDaysBeforeMin   = 0;
  static const recurringRemindDaysBeforeMax   = 3;
  static const recurringRemindDaysBeforeDefault = 1;

  // M-2 (AC 4.11): giờ nhắc trước hạn — [ASSUMPTION] 09:00 giờ local,
  // constant MỘT nơi duy nhất.
  static const recurringReminderHour   = 9;
  static const recurringReminderMinute = 0;

  // Image
  static const imageMaxWidth  = 1080;
  static const imageMaxHeight = 1080;
  static const imageQuality   = 85;

  // Backend — chuyển sang core/network/api_config.dart (hỗ trợ --dart-define
  // SHOPSNAP_API_URL, tự chọn 10.0.2.2 trên Android emulator)
  static String get backendBaseUrl => ApiConfig.baseUrl;

  // App Version & Update
  static const appVersion = '1.1.0';
  static const githubRepo = 'phamvinh203/shopsnap';
}
