/// F-#3 Smart Budget — burn rate / safe daily / forecast (pure logic).
///
/// Định nghĩa theo spec F-#3 (period monthly, công thức dùng cho mọi period
/// có start/end hợp lệ):
/// - `burn_rate`  = spent / số ngày ĐÃ QUA của kỳ (tính ngày đầu kỳ = 1 ngày
///   đã qua — AC 3.6: ngày đầu kỳ burn rate = 0 khi chưa chi gì).
/// - `safe_daily` = (budget − spent) / số ngày CÒN LẠI — chỉ hiển thị khi
///   budget − spent > 0, KHÔNG BAO GIỜ hiện số âm (AC 3.2/3.3).
/// - `forecast`   = burn_rate × tổng số ngày của kỳ.
///
/// Ranh giới:
/// - Ngày cuối kỳ (days_remaining = 0): KHÔNG chia 0 — ẩn safe daily và
///   forecast, chỉ còn spent vs budget + trạng thái (AC 3.7).
/// - Budget sửa giữa kỳ → dùng budget MỚI cho toàn bộ công thức từ hiện tại
///   (hàm nhận budget hiện tại, không có khái niệm retroactive — AC 3.8).
/// - Ngày đầu kỳ chưa chi (burn rate = 0) → forecast = 0, không warning nào
///   (AC 3.6).
///
/// Pure function KHÔNG phụ thuộc Flutter — unit test độc lập. Ngày xử lý theo
/// giờ local (cộng đồng Việt Nam), chỉ so sánh NGÀY (strip time).
library;

/// Kết quả 3 chỉ số smart budget cho 1 kỳ ngân sách.
class BudgetInsights {
  /// Tổng số ngày của kỳ (inclusive, tối thiểu 1).
  final int totalDays;

  /// Số ngày đã qua của kỳ (ngày đầu kỳ = 1; clamp 0..totalDays).
  final int daysElapsed;

  /// Số ngày còn lại (ngày cuối kỳ = 0).
  final int daysRemaining;

  /// Burn rate thô (spent/ngày) — hiển thị làm tròn 1 chữ số thập phân.
  final double burnRate;

  /// `false` khi ngày cuối kỳ / ngoài kỳ → ẩn toàn bộ insights (AC 3.7).
  final bool showInsights;

  /// Mức chi an toàn còn lại mỗi ngày (số nguyên VND, ĐÃ làm tròn).
  /// `null` = không hiển thị: hết budget (kể cả spent == budget), ngày cuối
  /// kỳ, hoặc trước khi kỳ bắt đầu (AC 3.2/3.3/3.7).
  final int? safeDaily;

  /// Forecast chi tiêu cuối kỳ (thô) — burn_rate × tổng số ngày.
  final double forecast;

  /// `true` khi spent > budget → cảnh báo ĐỎ thay cho safe daily (AC 3.3).
  final bool isOverBudget;

  /// spent − budget (> 0 khi vượt — "trạng thái vượt bao nhiêu", AC 3.3).
  final int overAmount;

  /// `true` khi forecast > budget → cảnh báo VÀNG (AC 3.4). Luôn `false` ở
  /// ngày cuối kỳ vì forecast đã bị ẩn.
  final bool isForecastOver;

  /// forecast − budget, làm tròn nguyên VND (> 0 khi isForecastOver — AC 3.4).
  final int projectedOverage;

  /// Dòng tích cực "Đang đúng tốc độ" (AC 3.5): đủ điều kiện hiển thị khi
  /// đang trong kỳ, chưa vượt, forecast ≤ budget và đã CÓ chi tiêu (burn rate
  /// > 0 — đầu kỳ chưa chi giữ im lặng theo AC 3.6).
  final bool showPositive;

  const BudgetInsights({
    required this.totalDays,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.burnRate,
    required this.showInsights,
    required this.safeDaily,
    required this.forecast,
    required this.isOverBudget,
    required this.overAmount,
    required this.isForecastOver,
    required this.projectedOverage,
    required this.showPositive,
  });

  /// Burn rate hiển thị — 1 chữ số thập phân (AC 3.10), vd "24.5".
  String get burnRateLabel => burnRate.toStringAsFixed(1);

  /// Forecast hiển thị — làm tròn nguyên VND (AC 3.10).
  int get forecastVnd => forecast.round();
}

/// Tính 3 chỉ số smart budget.
///
/// [periodStart]/[periodEnd] là ngày ĐẦU và ngày CUỐI của kỳ (inclusive) theo
/// giờ local; [now] là mốc tính (inject được để test).
BudgetInsights computeBudgetInsights({
  required int spent,
  required int budget,
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime now,
}) {
  DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);

  final start = day(periodStart);
  final end = day(periodEnd);
  final today = day(now);

  var totalDays = end.difference(start).inDays + 1;
  if (totalDays < 1) totalDays = 1; // start > end (dữ liệu bẩn) → không crash

  final int daysElapsed;
  if (today.isBefore(start)) {
    daysElapsed = 0;
  } else if (today.isAfter(end)) {
    daysElapsed = totalDays;
  } else {
    daysElapsed = today.difference(start).inDays + 1;
  }
  final daysRemaining = (totalDays - daysElapsed).clamp(0, totalDays);

  final burnRate = daysElapsed > 0 ? spent / daysElapsed : 0.0;
  final forecast = burnRate * totalDays;

  final isOverBudget = spent > budget;
  final overAmount = isOverBudget ? spent - budget : 0;

  // AC 3.7: hết ngày của kỳ → ẩn insights, tránh chia 0.
  final showInsights = daysRemaining > 0;

  // AC 3.2/3.3: chỉ khi CÒN tiền; số âm không bao giờ lộ ra UI.
  final safeDaily = showInsights && budget - spent > 0
      ? ((budget - spent) / daysRemaining).round()
      : null;

  final isForecastOver = showInsights && forecast > budget;
  final projectedOverage = isForecastOver ? (forecast - budget).round() : 0;

  final showPositive =
      showInsights && !isOverBudget && !isForecastOver && burnRate > 0;

  return BudgetInsights(
    totalDays: totalDays,
    daysElapsed: daysElapsed,
    daysRemaining: daysRemaining,
    burnRate: burnRate,
    showInsights: showInsights,
    safeDaily: safeDaily,
    forecast: forecast,
    isOverBudget: isOverBudget,
    overAmount: overAmount,
    isForecastOver: isForecastOver,
    projectedOverage: projectedOverage,
    showPositive: showPositive,
  );
}

/// Parse ngày kỳ 'YYYY-MM-DD' (cả local DAO lẫn server dùng format này) —
/// lỗi/null trả `null` để UI ẩn insights thay vì crash.
DateTime? tryParseBudgetDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}
