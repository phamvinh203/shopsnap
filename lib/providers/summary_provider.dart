import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/item_dao.dart';
import '../models/ai_assistant_model.dart';
import '../models/item_model.dart';
import '../models/summary_model.dart';
import '../core/utils/date_helper.dart';
import '../core/utils/merchant_insights.dart';
import '../services/summary_api_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Tham số của một lần xem summary: mốc ngày + kỳ — family key của các provider
/// bên dưới. [date] là mốc (server tự căn theo kỳ: week T2–CN, month đầu–cuối
/// tháng, year cả năm), không phải ngày đầu của kỳ.
class SummaryParams {
  final DateTime date;

  /// 'day' | 'week' | 'month' | 'year' (màn hình không có UI cho 'custom').
  final String period;

  const SummaryParams({required this.date, required this.period});

  /// 'YYYY-MM-DD' gửi lên API.
  static String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get apiDate => fmt(date);

  /// Khoảng ngày [start, end] (bao cả 2 đầu) tương ứng kỳ — dùng cho tổng hợp
  /// local offline và export CSV. Căn giống server: tuần T2–CN, tháng đầu–cuối.
  (DateTime, DateTime) get localRange {
    switch (period) {
      case 'week':
        final monday = DateTime(date.year, date.month, date.day)
            .subtract(Duration(days: date.weekday - 1));
        return (monday, monday.add(const Duration(days: 6)));
      case 'month':
        return (DateTime(date.year, date.month, 1),
                DateTime(date.year, date.month + 1, 0));
      case 'year':
        return (DateTime(date.year, 1, 1), DateTime(date.year, 12, 31));
      default: // day
        final d = DateTime(date.year, date.month, date.day);
        return (d, d);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SummaryParams &&
      other.period == period &&
      DateHelper.isSameDay(other.date, date);

  @override
  int get hashCode => Object.hash(period, date.year, date.month, date.day);
}

/// Service gọi /summary/* (Wave 5) — tái sử dụng ApiClient chung.
final summaryApiServiceProvider = Provider<SummaryApiService>((ref) {
  return SummaryApiService(ref.watch(apiClientProvider));
});

/// Response server thô cho kỳ đang chọn — null khi chưa đăng nhập hoặc API lỗi
/// (mất mạng / 401 expired). summaryProvider dùng làm nguồn số chính,
/// summary_screen đọc thêm để hiển thị comparison/trend.
final serverSummaryProvider =
    FutureProvider.family<SummaryResponse?, SummaryParams>((ref, params) async {
  final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
  if (!authenticated) return null;

  try {
    return await ref.watch(summaryApiServiceProvider).summary(
      period:  params.period,
      date:    params.apiDate,
      groupBy: 'category', // pie chart của màn hình là theo danh mục
    );
  } catch (_) {
    return null; // offline → caller fallback local, không vỡ UI
  }
});

/// Summary cho kỳ đang chọn — offline-first (Wave 5):
///
/// 1. Luôn tính từ sqflite trước (nhanh, dùng được cả khi offline) — cùng phép
///    tính GROUP BY category như cũ, mở rộng cho các kỳ week/month/year.
/// 2. Đã đăng nhập → GET /summary (server tính theo purchase_date, trả budget/
///    comparison/breakdown) → map về [SummaryModel] để UI đọc như trước. API
///    không trả items nên kỳ `day` giữ items local (đã sync từ Wave 3), kỳ dài
///    hơn trả rỗng (màn hình ẩn mục danh sách vật phẩm).
/// 3. serverSummaryProvider trả null (offline / chưa đăng nhập) → giữ số local.
///
/// Rebuild khi auth đổi trạng thái hoặc [SummaryParams] đổi. Family key đổi từ
/// DateTime sang SummaryParams (consumer duy nhất là summary_screen, cập nhật
/// cùng wave) để truyền kỳ vào API.
final summaryProvider =
    FutureProvider.family<SummaryModel, SummaryParams>((ref, params) async {
  final db  = await ref.watch(databaseProvider.future);
  final dao = ItemDao(db);

  final range = params.localRange;
  final local = await dao.getSummaryForRange(range.$1, range.$2);

  final server = await ref.watch(serverSummaryProvider(params).future);
  if (server == null) return local;

  return server.toSummaryModel(
    date: params.date,
    // Kỳ day → items của ngày (đã merge server/local qua itemsProvider);
    // kỳ dài hơn → rỗng, màn hình ẩn mục danh sách vật phẩm.
    items: params.period == 'day' ? local.items : const <ItemModel>[],
  );
});

/// Insights rule-based cho kỳ đang chọn — backend chỉ nhận period=month|week
/// nên day/year xem như month. Offline / chưa đăng nhập → rỗng (section ẩn).
final summaryInsightsProvider =
    FutureProvider.family<List<SpendingInsight>, SummaryParams>((ref, params) async {
  final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
  if (!authenticated) return const [];

  try {
    return await ref.watch(summaryApiServiceProvider).insights(
      date:   params.apiDate,
      period: params.period == 'week' ? 'week' : 'month',
    );
  } catch (_) {
    return const [];
  }
});

/// M-3 (AC 7.8/7.11/7.14): phân tích chi tiêu theo nơi mua cho kỳ đang chọn —
/// 100% TÍNH TỪ SQLITE LOCAL (không gọi API — AC 7.15 group-by server là
/// [CONTRACT-PENDING]): đọc items của kỳ qua `findByRange` rồi để pure function
/// `buildMerchantSummary` group-by nguyên văn store_name (AC 7.13) + so sánh
/// giá cùng món. Lượt mua không có nơi mua tự bị pure function bỏ qua.
final merchantSummaryProvider =
    FutureProvider.family<MerchantSummary, SummaryParams>((ref, params) async {
  final db  = await ref.watch(databaseProvider.future);
  final dao = ItemDao(db);

  final range = params.localRange;
  final items = await dao.findByRange(range.$1, range.$2);
  final purchases = [
    for (final i in items)
      MerchantPurchase(name: i.name, storeName: i.storeName, price: i.price),
  ];
  return buildMerchantSummary(purchases);
});

/// F-#2 (AC 2.1): tổng chi KỲ LIỀN TRƯỚC cùng độ dài — nguồn offline cho MoM
/// khi server không trả comparison (mất mạng / chưa đăng nhập). Căn kỳ giống
/// [SummaryParams.localRange]: lùi 1 ngày từ đầu kỳ → lấy kỳ dài bằng ngược lên.
final previousPeriodTotalProvider =
    FutureProvider.family<int, SummaryParams>((ref, params) async {
  final db  = await ref.watch(databaseProvider.future);
  final dao = ItemDao(db);

  final range    = params.localRange;
  final length   = range.$2.difference(range.$1).inDays + 1;
  final prevEnd  = range.$1.subtract(const Duration(days: 1));
  final prevStart = prevEnd.subtract(Duration(days: length - 1));

  final prev = await dao.getSummaryForRange(prevStart, prevEnd);
  return prev.totalSpent;
});

/// F-#2 (AC 2.5): timeout gọi AI — mặc định 5s, đổi được qua dart-define
/// `SHOPSNAP_AI_TIMEOUT_MS`. Quá hạn → ném TimeoutException → caller rơi vào
/// heuristic fallback, dashboard không treo.
const aiAssistantTimeout = Duration(
  milliseconds: int.fromEnvironment(
    'SHOPSNAP_AI_TIMEOUT_MS',
    defaultValue: 5000,
  ),
);

/// Trợ lý AI Gemini phân tích chi tiêu, dự báo thâm hụt cuối tháng & mẹo tiết kiệm.
/// Chỉ gửi mốc ngày lên server (aggregates do BE tự tổng hợp — AC 2.4, không
/// có raw transaction).
///
/// F-#2 (AC 2.5): lỗi gọi AI (network / 5xx / thiếu key) hoặc quá
/// [aiAssistantTimeout] → AsyncError để UI render heuristic fallback — vì vậy
/// KHÔNG nuốt exception ở đây. Chưa đăng nhập → null (không có AI section).
final aiAssistantProvider =
    FutureProvider.family<AiAssistantResponse?, String?>((ref, dateStr) async {
  final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
  if (!authenticated) return null;

  return ref
      .watch(summaryApiServiceProvider)
      .aiAssistant(date: dateStr)
      .timeout(aiAssistantTimeout);
});

/// Dịch mốc ngày theo kỳ cho nút prev/next của summary_screen — server tự căn
/// lại về đầu kỳ nên chỉ cần bước đúng độ dài kỳ (tháng/năm có kẹp ngày cuối).
DateTime shiftDateByPeriod(DateTime date, String period, int direction) {
  switch (period) {
    case 'week':
      return date.add(Duration(days: 7 * direction));
    case 'month':
      final anchor = DateTime(date.year, date.month + direction, 1);
      final lastDay = DateTime(anchor.year, anchor.month + 1, 0).day;
      return DateTime(anchor.year, anchor.month, math.min(date.day, lastDay));
    case 'year':
      final anchor = DateTime(date.year + direction, date.month, 1);
      final lastDay = DateTime(anchor.year, anchor.month + 1, 0).day;
      return DateTime(anchor.year, anchor.month, math.min(date.day, lastDay));
    default: // day
      return date.add(Duration(days: direction));
  }
}
