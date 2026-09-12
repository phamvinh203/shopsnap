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

    // ── Items (Wave 3) ──────────────────────────────────────────────────────
    case 'ITEM_DUPLICATE':
      return 'Bạn vừa thêm sản phẩm này cách đây không lâu.';
    case 'ITEM_NOT_FOUND':
      return 'Không tìm thấy vật phẩm (có thể đã bị xóa).';
    case 'ITEM_INVALID_PRICE':
      return 'Giá tiền không hợp lệ.';
    case 'ITEM_INVALID_CATEGORY':
      return 'Danh mục của vật phẩm không hợp lệ.';
    case 'ITEM_INVALID_SORT':
      return 'Cách sắp xếp không hợp lệ.';
    case 'ITEM_EMPTY_UPDATE':
      return 'Không có thông tin nào để cập nhật.';
    case 'ITEM_BULK_TOO_LARGE':
      return 'Chỉ thêm được tối đa 50 vật phẩm mỗi lần.';
    case 'ITEM_CREATE_FAILED':
      return 'Không thể lưu vật phẩm. Vui lòng thử lại.';

    // ── Budgets (Wave 4) ────────────────────────────────────────────────────
    case 'BUDGET_OVERLAP':
      return 'Khoảng thời gian này trùng với một ngân sách khác cùng loại.';
    case 'BUDGET_DATE_INVALID':
      return 'Ngày bắt đầu / kết thúc không hợp lệ. Vui lòng kiểm tra lại.';
    case 'BUDGET_NEGATIVE_AMOUNT':
      return 'Số tiền ngân sách phải lớn hơn 0.';
    case 'BUDGET_ALLOCATED_EXCEEDS_TOTAL':
      return 'Tổng tiền phân bổ cho các danh mục vượt quá tổng ngân sách.';
    case 'BUDGET_CATEGORY_CONFLICT':
      return 'Mỗi danh mục chỉ được phân bổ một lần trong ngân sách.';
    case 'BUDGET_CATEGORY_NOT_FOUND':
      return 'Danh mục trong ngân sách không tồn tại (có thể đã bị xóa).';
    case 'BUDGET_NOT_FOUND':
      return 'Không tìm thấy ngân sách (có thể đã bị xóa).';
    case 'BUDGET_INVALID':
      return 'Dữ liệu ngân sách chưa hợp lệ. Vui lòng kiểm tra lại.';

    // ── Summary (Wave 5) ────────────────────────────────────────────────────
    case 'SUMMARY_INVALID_PERIOD':
      return 'Kỳ thống kê hoặc ngày không hợp lệ. Vui lòng kiểm tra lại.';
    case 'SUMMARY_DATE_RANGE_TOO_LARGE':
      return 'Khoảng thống kê tối đa 366 ngày. Vui lòng chọn phạm vi ngắn hơn.';
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
