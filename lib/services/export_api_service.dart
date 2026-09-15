import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/api_exception.dart';

/// Format xuất dữ liệu của GET /summary/export (F-#11).
enum ExportFormat { csv, json }

extension ExportFormatX on ExportFormat {
  /// Giá trị query param `format` phía backend.
  String get wire => this == ExportFormat.csv ? 'csv' : 'json';

  /// Phần mở rộng của file lưu trên máy.
  String get fileExtension => wire;
}

/// Kết quả thô của GET /summary/export — bytes NGUYÊN VẸN của response.
///
/// - CSV: giữ nguyên UTF-8 BOM (EF BB BF) do backend chèn đầu file → Excel mở
///   đúng tiếng Việt (AC 11.5). Không decode/encode lại để tránh mất BOM.
/// - JSON: giữ nguyên body `{ success, data }` của BE → schema khớp 100%
///   endpoint /summary/export, không thêm/sót field (AC 11.6).
class ExportPayload {
  final ExportFormat format;
  final Uint8List bytes;

  const ExportPayload({required this.format, required this.bytes});
}

/// Gọi GET /summary/export lấy file thô (CSV/JSON).
///
/// Endpoint trả `text/csv` (CSV) hoặc envelope JSON — KHÔNG đi qua
/// `ApiClient.get` vì envelope-unwrap sẽ bóc/thay đổi body. Gọi http trực tiếp
/// nhưng tái dùng token + `refreshTokens()` của ApiClient để giữ nhất quán
/// phiên đăng nhập (pattern của `SummaryApiService.exportCsv` — wave 5):
/// 401 → refresh đúng 1 lần rồi retry đúng 1 lần; refresh hỏng →
/// SESSION_EXPIRED. Timeout theo [ApiConfig.receiveTimeout] (AC 11.4 —
/// không để loading treo vô hạn).
class ExportApiService {
  final ApiClient _client;

  /// Client http riêng cho request trả file — inject được trong unit test.
  final http.Client _http;

  ExportApiService(this._client, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const List<int> _utf8Bom = [0xEF, 0xBB, 0xBF];

  /// Lấy file export của khoảng [dateFrom]..[dateTo] (YYYY-MM-DD, tối đa 366
  /// ngày — BR-18, backend tự validate) với [format] csv|json.
  Future<ExportPayload> fetch({
    required ExportFormat format,
    required String dateFrom,
    required String dateTo,
    String include = 'items',
  }) async {
    final res = await _raw(
      format: format,
      dateFrom: dateFrom,
      dateTo: dateTo,
      include: include,
    );

    var bytes = res.bodyBytes;
    // AC 11.5: đảm bảo CSV luôn có UTF-8 BOM — backend hiện đã chèn, nhưng
    // tự chở thêm 1 lớp ở client đề phòng backend bỏ BOM.
    if (format == ExportFormat.csv && !_hasUtf8Bom(bytes)) {
      bytes = Uint8List.fromList([..._utf8Bom, ...bytes]);
    }
    return ExportPayload(format: format, bytes: bytes);
  }

  // ── Bên trong ─────────────────────────────────────────────────────────────

  bool _hasUtf8Bom(List<int> bytes) =>
      bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;

  Future<http.Response> _raw({
    required ExportFormat format,
    required String dateFrom,
    required String dateTo,
    required String include,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/summary/export')
        .replace(queryParameters: {
      'format':    format.wire,
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
      throw ApiException.network(
          'Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    // Body lỗi của backend vẫn là JSON (SUMMARY_INVALID_PERIOD /
    // SUMMARY_DATE_RANGE_TOO_LARGE / ...) → parse được thành ApiException.
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
