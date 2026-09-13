/// Cấu hình kết nối backend API.
///
/// Base URL được quyết định theo thứ tự ưu tiên:
/// 1. Override lúc build: `flutter run --dart-define=SHOPSNAP_API_URL=...`
/// 2. Mặc định trỏ về Render Cloud Production: `https://shopsnap-api-fj4i.onrender.com/api/v1`
class ApiConfig {
  ApiConfig._();

  /// Override qua --dart-define (chuỗi rỗng nếu không truyền).
  static const _overrideUrl = String.fromEnvironment('SHOPSNAP_API_URL');

  /// Timeout cho một request hoàn chỉnh (tăng 35s cho Render cold-start).
  static const receiveTimeout = Duration(seconds: 35);

  /// Production backend trên Render
  static const productionUrl = 'https://shopsnap-api-fj4i.onrender.com/api/v1';

  /// Local development URLs
  static const defaultLocal = 'http://localhost:3000/api/v1';
  static const androidEmulatorLocal = 'http://10.0.2.2:3000/api/v1';

  /// Base URL của backend — luôn không có dấu "/" ở cuối.
  static String get baseUrl {
    if (_overrideUrl.isNotEmpty) return _stripTrailingSlash(_overrideUrl);
    return productionUrl;
  }

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
