import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

abstract class DateHelper {
  /// Cờ guards cho lazy init — chỉ init đúng 1 lần per isolate.
  static bool _localeDataReady = false;

  /// Đảm bảo dữ liệu date symbols/patterns của intl đã được cài.
  ///
  /// ROOT CAUSE bug "3 tab trắng" (v1.0.5): `DateFormat('...', 'vi_VN')` ném
  /// `LocaleDataException` nếu chưa ai gọi `initializeDateFormatting` — chỉ
  /// trừ en_US (fallback duy nhất intl bundle sẵn). App chỉ gọi init trong
  /// `setUpAll` của WIDGET TEST nên test luôn xanh, còn bản release trên máy
  /// thật: Home (formatDate) và Lịch sử (formatMonthYear) gọi ngay trong
  /// `build()` của screen → NỔ TOÀN MÀN; Tổng kết nổ vùng date-nav
  /// (_DateNavBar gọi formatDate khi xem kỳ ≠ hôm nay; formatTime dùng
  /// pattern không locale nên rơi về en_US, an toàn).
  /// Vùng lỗi bị thay bằng ErrorWidget (release = hộp xám, chớp mắt thấy
  /// "trắng tinh").
  ///
  /// `initializeDateFormatting` (date_symbol_data_local) cài data cho TẤT CẢ
  /// locale MỘT CÁCH ĐỒNG BỘ (param locale bị bỏ qua — xem source intl 0.19)
  /// nên gọi lười ở đây là đủ và an toàn cho mọi entry point (main, test).
  /// main.dart cũng gọi 1 lần lúc khởi động để che cả case dùng DateFormat
  /// trực tiếp ngoài DateHelper.
  static void _ensureLocaleData() {
    if (_localeDataReady) return;
    initializeDateFormatting('vi_VN');
    _localeDataReady = true;
  }

  static String formatTime(int timestampMs) {
    _ensureLocaleData();
    return DateFormat('HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  }

  static String formatDate(DateTime date) {
    _ensureLocaleData();
    return DateFormat('EEEE, d MMMM', 'vi_VN').format(date);
  }

  static String formatDateShort(DateTime date) {
    _ensureLocaleData();
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatMonthYear(DateTime date) {
    _ensureLocaleData();
    return DateFormat('MMMM yyyy', 'vi_VN').format(date);
  }

  static int dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

  static int dayEnd(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1).millisecondsSinceEpoch;

  static int monthStart(DateTime date) =>
      DateTime(date.year, date.month, 1).millisecondsSinceEpoch;

  static int monthEnd(DateTime date) =>
      DateTime(date.year, date.month + 1, 1).millisecondsSinceEpoch;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
