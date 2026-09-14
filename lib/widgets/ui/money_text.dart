import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Text hiển thị số tiền — LUÔN dùng tabular figures để danh sách giá thẳng cột.
///
/// Format tiền đi qua [CurrencyFormatter] (nguồn sự thật duy nhất: `25.000đ`).
/// [colored] = tô màu MỰC (cs.onSurface) thay vì primary — tổng tiền là mực
/// đậm, không tô màu (INK LEDGER 3.11: tránh success/primary lẫn lộn).
class MoneyText extends StatelessWidget {
  final int amount;

  /// Override style (size/weight) — fontFeatures tabular luôn được giữ lại.
  final TextStyle? style;
  final bool colored;

  const MoneyText({
    super.key,
    required this.amount,
    this.style,
    this.colored = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.moneyOf(
      context.text,
      color: colored ? context.cs.onSurface : null,
    );
    return Text(
      CurrencyFormatter.format(amount),
      key: const Key('moneyText_text'),
      style: base.merge(style),
    );
  }
}
