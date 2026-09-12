import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Callback gọi khi session hết hạn vĩnh viễn (refresh thất bại) —
/// AuthNotifier đăng ký để đồng bộ trạng thái đăng xuất toàn cục.
typedef SessionExpiredCallback = void Function();

/// Wrapper mỏng quanh package:http dùng chung cho mọi call lên backend.
///
/// - `auth: true` → tự gắn `Authorization: Bearer <accessToken>` từ [TokenStorage]
/// - Envelope thành công `{ "success": true, "data": ... }` → trả thẳng `data`
/// - Lỗi → ném [ApiException] với code/message lấy từ body lỗi của backend
/// - Nhận 401 khi `auth: true` → thử POST /auth/refresh đúng 1 lần, persist token
///   mới rồi retry request gốc đúng 1 lần; refresh thất bại → xoá session và
///   báo qua [onSessionExpired]
class ApiClient {
  final http.Client _http;
  final TokenStorage storage;
  SessionExpiredCallback? onSessionExpired;

  /// Chống nhiều request 401 song song cùng trigger refresh — gom vào một request.
  Future<bool>? _refreshInFlight;

  ApiClient({http.Client? client, TokenStorage? storage})
      : _http   = client ?? http.Client(),
        storage = storage ?? SharedPreferencesTokenStorage();

  // ── API chính ─────────────────────────────────────────────────────────────

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = false,
  }) {
    return _send(method, path, body: body, query: query, auth: auth);
  }

  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = false}) =>
      request('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = false}) =>
      request('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Map<String, dynamic>? body, bool auth = false}) =>
      request('PUT', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body, bool auth = false}) =>
      request('PATCH', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = false}) =>
      request('DELETE', path, auth: auth);

  // ── Refresh token ─────────────────────────────────────────────────────────

  /// Gọi POST /auth/refresh bằng refresh token đang lưu. Thành công → persist
  /// token mới vào storage. Trả true/false (không ném) để caller xử lý gọn.
  Future<bool> refreshTokens() {
    _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  Future<bool> _doRefresh() async {
    final tokens = await storage.readTokens();
    if (tokens == null) return false;
    try {
      final res = await _execute('POST', '${ApiConfig.baseUrl}/auth/refresh',
          body: {'refreshToken': tokens.refreshToken});
      final decoded = _tryDecode(res.body);
      if (res.statusCode == 200 && decoded is Map && decoded['data'] is Map) {
        final data = decoded['data'] as Map;
        final access  = data['accessToken'];
        final refresh = data['refreshToken'];
        if (access is String && refresh is String) {
          await storage.saveTokens(
              AuthTokens(accessToken: access, refreshToken: refresh));
          return true;
        }
      }
      return false;
    } catch (_) {
      return false; // Lỗi mạng khi refresh → coi như chưa refresh được
    }
  }

  // ── Bên trong ─────────────────────────────────────────────────────────────

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = false,
    bool isRetry = false,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (auth) {
        final tokens = await storage.readTokens();
        if (tokens != null) headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }

      final res = await _execute(method, '${ApiConfig.baseUrl}$path',
          body: body, query: query, headers: headers);
      final decoded = _tryDecode(res.body);

      // Thành công → unwrap envelope
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (decoded is Map && decoded['success'] == true && decoded.containsKey('data')) {
          return decoded['data'];
        }
        return decoded; // vd. logout trả { success: true } không có data
      }

      // 401 → thử refresh đúng 1 lần rồi retry request gốc đúng 1 lần
      if (res.statusCode == 401 && auth && !isRetry) {
        final refreshed = await refreshTokens();
        if (refreshed) {
          return _send(method, path,
              body: body, query: query, auth: auth, isRetry: true);
        }
        // Refresh hỏng → session chết
        await storage.clear();
        onSessionExpired?.call();
        throw const ApiException(
          code: 'SESSION_EXPIRED',
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          statusCode: 401,
        );
      }

      throw ApiException.fromBody(decoded, res.statusCode);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException.network('Kết nối tới máy chủ quá chậm. Vui lòng thử lại.');
    } catch (_) {
      throw ApiException.network('Không thể kết nối tới máy chủ. Kiểm tra mạng rồi thử lại.');
    }
  }

  Future<http.Response> _execute(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    var uri = Uri.parse(url);
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    final req = http.Request(method, uri)..headers.addAll(headers ?? const {});
    if (body != null) {
      // Bắt buộc khai báo charset=utf-8: nếu không, http package mặc định
      // encode latin-1 → ném lỗi với ký tự tiếng Việt (vd. tên "Nguyễn Văn A")
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.encoding = utf8;
      req.body = jsonEncode(body);
    }

    final streamed = await _http.send(req).timeout(ApiConfig.receiveTimeout);
    return http.Response.fromStream(streamed).timeout(ApiConfig.receiveTimeout);
  }

  dynamic _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null; // body không phải JSON → ApiException.fromBody sẽ xử lý
    }
  }
}
