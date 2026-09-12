/// Exception chuẩn của tầng API — gom mọi lỗi (backend + mạng) về một shape duy nhất
/// để UI chỉ cần bắt [ApiException] và hiển thị `message`.
class ApiException implements Exception {
  /// Mã lỗi từ backend (vd. 'EMAIL_EXISTS') hoặc mã suy ra từ HTTP status
  /// (vd. 'Conflict', 'VALIDATION_ERROR', 'NETWORK_ERROR', 'SESSION_EXPIRED').
  final String code;

  /// Thông điệp gốc từ backend (nếu có).
  final String message;

  /// HTTP status code (null nếu lỗi mạng — không nhận được response).
  final int? statusCode;

  /// Field bị lỗi (nếu backend trả về, shape api-spec).
  final String? field;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.field,
  });

  /// Parse body lỗi từ backend. Hỗ trợ 2 shape:
  /// - Chuẩn api-spec (module mới): `{ "error": { "code", "message", "field?", "timestamp" } }`
  /// - Shape mặc định của NestJS (module auth cũ):
  ///   `{ "statusCode", "message": string | string[], "error"? }`
  factory ApiException.fromBody(dynamic body, int statusCode) {
    var code    = 'HTTP_$statusCode';
    var message = 'Đã có lỗi xảy ra ($statusCode)';
    String? field;

    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        // Shape api-spec: { error: { code, message, field? } }
        code    = (err['code'] as String?) ?? code;
        message = (err['message'] as String?) ?? message;
        field   = err['field'] as String?;
      } else {
        // Shape Nest mặc định: { statusCode, message, error? }
        final msg = body['message'];
        if (msg is List && msg.isNotEmpty) {
          message = msg.join('; ');
          code    = 'VALIDATION_ERROR';
        } else if (msg is String && msg.isNotEmpty) {
          message = msg;
        }
        final nestError = body['error'];
        if (nestError is String && nestError.isNotEmpty) code = nestError;
      }
    }

    // 429 — throttle của auth endpoints (Nest trả 'ThrottlerException: ...')
    if (statusCode == 429) code = 'RATE_LIMITED';

    return ApiException(code: code, message: message, statusCode: statusCode, field: field);
  }

  /// Lỗi mạng / timeout — không nhận được response từ server.
  factory ApiException.network(String message) =>
      ApiException(code: 'NETWORK_ERROR', message: message);

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
