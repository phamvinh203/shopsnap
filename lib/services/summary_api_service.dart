import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/ai_assistant_model.dart';
import '../models/summary_model.dart';

/// Kỳ hợp lệ của backend (`SUMMARY_PERIODS`).
const summaryPeriods = <String>['day', 'week', 'month', 'year', 'custom'];

/// Kiểu nhóm breakdown hợp lệ của backend (`SUMMARY_GROUP_BY`).
const summaryGroupBys = <String>['category', 'day', 'week', 'store'];

/// Insight rule-based của GET /summary/insights — title/message server đã soạn
/// sẵn tiếng Việt, UI chỉ map thêm icon theo [type] và màu theo [severity].
class SpendingInsight {
  // budget_warning | over_budget | category_spike | best_day | ...
  final String type;

  // warning | info | positive
  final String severity;
  final String title;
  final String message;
  final Map<String, dynamic> data;

  const SpendingInsight({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.data,
  });

  factory SpendingInsight.fromJson(Map<String, dynamic> j) => SpendingInsight(
    type:     j['type']     as String? ?? '',
    severity: j['severity'] as String? ?? 'info',
    title:    j['title']    as String? ?? '',
    message:  j['message']  as String? ?? '',
    data:     j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : const {},
  );
}

/// Gọi các endpoint /summary/* qua [ApiClient].
///
/// Backend domain-API dùng snake_case → mapping nằm ở `SummaryResponse.fromJson`
/// / `SummaryModel.fromApiJson`. Mọi endpoint đều cần Bearer token (JwtAuthGuard)
/// → `auth: true` để được 401-refresh-retry của ApiClient.
///
/// Lỗi hay gặp: 400 SUMMARY_INVALID_PERIOD (period/date sai),
/// 400 SUMMARY_DATE_RANGE_TOO_LARGE (custom range > 366 ngày — BR-18).
class SummaryApiService {
  final ApiClient _client;

  /// Client http riêng cho exportCsv — endpoint trả `text/csv` (body không phải
  /// JSON) nên không đi qua envelope-unwrap của ApiClient (xem [_exportCsvRaw]).
  final http.Client _http;

  SummaryApiService(this._client, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// GET /summary — tổng kết theo kỳ.
  ///
  /// - [period] một giá trị trong [summaryPeriods]; [date] 'YYYY-MM-DD' là mốc
  ///   cho day/week/month/year (server tự căn: week T2–CN, month đầu–cuối tháng).
  /// - [dateFrom]/[dateTo] bắt buộc cùng lúc khi period=custom (tối đa 366 ngày).
  /// - [groupBy] một giá trị trong [summaryGroupBys] → kèm `breakdown` theo nhóm.
  Future<SummaryResponse> summary({
    required String period,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? categoryId,
    String? groupBy,
  }) async {
    final data = await _client.get('/summary', auth: true, query: {
      'period': period,
      if (date       != null) 'date':        date,
      if (dateFrom   != null) 'date_from':   dateFrom,
      if (dateTo     != null) 'date_to':     dateTo,
      if (categoryId != null) 'category_id': categoryId,
      if (groupBy    != null) 'group_by':    groupBy,
    });
    return SummaryResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// GET /summary/insights — insight rule-based. Backend chỉ nhận
  /// period=month|week (mặc định month) → kỳ khác map về month ở caller.
  Future<List<SpendingInsight>> insights({String? date, String period = 'month'}) async {
    final data = await _client.get('/summary/insights', auth: true, query: {
      if (date != null) 'date': date,
      'period': period,
    });
    final list = ((data as Map)['insights'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((j) => SpendingInsight.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// GET /summary/ai-assistant — trợ lý AI Gemini phân tích chi tiêu, dự báo thâm hụt & mẹo tiết kiệm
  Future<AiAssistantResponse> aiAssistant({String? date}) async {
    final data = await _client.get('/summary/ai-assistant', auth: true, query: {
      if (date != null) 'date': date,
    });
    return AiAssistantResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// GET /summary/export?format=json — data: `{items: [...], categories? , budgets?}`.
  Future<Map<String, dynamic>> exportJson({
    required String dateFrom,
    required String dateTo,
    String include = 'items',
  }) async {
    final data = await _client.get('/summary/export', auth: true, query: {
      'format':    'json',
      'date_from': dateFrom,
      'date_to':   dateTo,
      'include':   include,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// GET /summary/export?format=csv — trả chuỗi CSV thô (UTF-8, mở đầu bằng BOM
  /// \uFEFF để Excel đọc đúng tiếng Việt).
  ///
  /// KHÔNG đi qua `ApiClient.get`: endpoint trả `text/csv` (body không phải
  /// JSON) nên envelope-unwrap của ApiClient sẽ biến nó thành null. Gọi http
  /// trực tiếp nhưng tái dùng token + `refreshTokens()` của ApiClient để giữ
  /// nhất quán phiên đăng nhập; 401 → refresh đúng 1 lần rồi retry đúng 1 lần
  /// (cùng chính sách với ApiClient; refresh hỏng → SESSION_EXPIRED).
  Future<String> exportCsv({
    required String dateFrom,
    required String dateTo,
    String include = 'items',
  }) async {
    final res = await _exportCsvRaw(
      dateFrom: dateFrom, dateTo: dateTo, include: include,
    );
    // Dart utf8.decode bỏ qua BOM đầu chuỗi → `res.body` mất \uFEFF dù bytes
    // đúng (EF BB BF). Nối lại để string khớp nguyên vẹn CSV của server.
    return res.body.startsWith('\uFEFF') ? res.body : '\uFEFF${res.body}';
  }

  Future<http.Response> _exportCsvRaw({
    required String dateFrom,
    required String dateTo,
    required String include,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/summary/export')
        .replace(queryParameters: {
      'format':    'csv',
      'date_from': dateFrom,
      'date_to':   dateTo,
      'include':   include,
    });

    Future<http.Response> send() async {
      final tokens = await _client.storage.readTokens();
      return _http.get(uri, headers: {
        if (tokens != null) 'Authorization': 'Bearer ${tokens.accessToken}',
      }).timeout(ApiConfig.receiveTimeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        if (await _client.refreshTokens()) {
          res = await send();
        } else {
          throw const ApiException(
            code: 'SESSION_EXPIRED',
            message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
            statusCode: 401,
          );
        }
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.network('Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    // Body lỗi của backend vẫn là JSON (SUMMARY_INVALID_PERIOD / ...) → parse được
    throw ApiException.fromBody(_tryDecode(res.body), res.statusCode);
  }

  dynamic _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
