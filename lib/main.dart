import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  // M-2 (AC 4.11): zonedSchedule của flutter_local_notifications yêu cầu
  // database timezone đã init (spec bắt buộc thêm package `timezone` + init
  // ở main). Thời điểm nhắc vẫn tính bằng DateTime local của thiết bị nên
  // không cần native tz name — xem NotificationService.scheduleRecurringReminder.
  tz_data.initializeTimeZones();
  // Bug "3 tab trắng" (v1.0.5): intl chỉ bundle sẵn en_US — không init date
  // symbols thì DateFormat locale 'vi_VN' ném LocaleDataException NGAY LÚC
  // build (Home/Lịch sử gọi trực tiếp trong build). Hàm này cài data cho tất
  // cả locale đồng bộ (data bundle sẵn, không network); DateHelper còn có
  // lazy guard riêng để tự che mọi entry point khác — xem date_helper.dart.
  await initializeDateFormatting('vi_VN', null);
  runApp(const ProviderScope(child: ShopSnapApp()));
}
