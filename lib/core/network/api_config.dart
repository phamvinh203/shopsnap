import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Cấu hình kết nối backend API.
///
/// Base URL được quyết định theo thứ tự ưu tiên:
/// 1. Override lúc build: `flutter run --dart-define=SHOPSNAP_API_URL=http://192.168.1.x:3000/api/v1`
/// 2. Mặc định theo nền tảng: Android emulator → 10.0.2.2 (alias localhost của máy host),
///    web / iOS simulator / desktop → localhost.
class ApiConfig {
  ApiConfig._();

  /// Override qua --dart-define (chuỗi rỗng nếu không truyền).
  static const _overrideUrl = String.fromEnvironment('SHOPSNAP_API_URL');

  /// Timeout cho một request hoàn chỉnh.
  static const receiveTimeout = Duration(seconds: 20);

  /// Base URL của backend — luôn không có dấu "/" ở cuối.
  static String get baseUrl {
    if (_overrideUrl.isNotEmpty) return _stripTrailingSlash(_overrideUrl);
    if (kIsWeb) return _defaultLocal;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/v1'; // Android emulator → localhost
    return _defaultLocal; // iOS simulator / desktop → localhost
  }

  static const _defaultLocal = 'http://localhost:3000/api/v1';
  // static const _defaultLocal = 'https://api.shopsnap.vn/api/v1'; // Production

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
