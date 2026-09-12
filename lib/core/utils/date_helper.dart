import 'package:intl/intl.dart';

abstract class DateHelper {
  static String formatTime(int timestampMs) =>
      DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

  static String formatDate(DateTime date) =>
      DateFormat('EEEE, d MMMM', 'vi_VN').format(date);

  static String formatDateShort(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  static String formatMonthYear(DateTime date) =>
      DateFormat('MMMM yyyy', 'vi_VN').format(date);

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
