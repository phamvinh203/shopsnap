import '../network/api_exception.dart';

/// Map [ApiException] → thông điệp tiếng Việt thân thiện cho snackbar.
///
/// Backend auth hiện trả shape Nest mặc định (không có `code` riêng) nên map
/// theo statusCode; các code api-spec (EMAIL_EXISTS, INVALID_CREDENTIALS, ...)
/// vẫn được map trước để sẵn sàng cho các module mới.
String apiErrorMessage(Object error) {
  if (error is! ApiException) return 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  switch (error.code) {
    case 'EMAIL_EXISTS':
      return 'Email này đã được đăng ký. Vui lòng dùng email khác.';
    case 'INVALID_CREDENTIALS':
      return 'Email hoặc mật khẩu không đúng.';
    case 'RATE_LIMITED':
      return 'Bạn thao tác quá nhiều lần. Vui lòng đợi ít phút rồi thử lại.';
    case 'SESSION_EXPIRED':
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    case 'NETWORK_ERROR':
      return error.message; // đã là tiếng Việt từ ApiClient

    // ── Categories (Wave 2) ────────────────────────────────────────────────
    case 'CATEGORY_DUPLICATE_NAME':
      return 'Tên danh mục này đã tồn tại. Vui lòng chọn tên khác.';
    case 'CATEGORY_DEFAULT_IMMUTABLE':
      return 'Danh mục mặc định không thể sửa hoặc xóa.';
    case 'CATEGORY_HAS_ITEMS':
      return 'Danh mục vẫn còn vật phẩm. Hãy chuyển chúng sang danh mục khác trước khi xóa.';
    case 'CATEGORY_INVALID_PARENT':
      return 'Danh mục cha không hợp lệ. Chỉ được dùng danh mục custom của bạn.';
    case 'CATEGORY_NOT_FOUND':
      return 'Không tìm thấy danh mục.';
  }

  switch (error.statusCode) {
    case 400:
      return 'Dữ liệu chưa hợp lệ: ${error.message}';
    case 401:
      return 'Email hoặc mật khẩu không đúng.';
    case 409:
      return 'Email này đã được đăng ký. Vui lòng dùng email khác.';
    case 429:
      return 'Bạn thao tác quá nhiều lần. Vui lòng đợi ít phút rồi thử lại.';
    case 500:
    case 502:
    case 503:
      return 'Lỗi máy chủ. Vui lòng thử lại sau ít phút.';
  }

  return error.message.isNotEmpty ? error.message : 'Đã có lỗi xảy ra. Vui lòng thử lại.';
}
