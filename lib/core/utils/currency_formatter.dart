import 'package:intl/intl.dart';

abstract class CurrencyFormatter {
  static final _fmt = NumberFormat('#,###', 'vi_VN');

  static String format(int amountVnd) => '${_fmt.format(amountVnd)}đ';

  static String formatShort(int amountVnd) {
    if (amountVnd >= 1000000) return '${(amountVnd / 1000000).toStringAsFixed(1)}tr';
    if (amountVnd >= 1000)    return '${(amountVnd / 1000).toStringAsFixed(0)}k';
    return '${amountVnd}đ';
  }

  static int parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
}
