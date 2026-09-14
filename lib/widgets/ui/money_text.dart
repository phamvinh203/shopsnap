import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Text hiển thị số tiền — LUÔN dùng tabular figures để danh sách giá thẳng cột.
///
/// Format tiền đi qua [CurrencyFormatter] (nguồn sự thật duy nhất: `25.000đ`).
/// [colored] = tô màu brand primary (dùng cho tổng/trong section header).
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
      color: colored ? context.cs.primary : null,
    );
    return Text(
      CurrencyFormatter.format(amount),
      key: const Key('moneyText_text'),
      style: base.merge(style),
    );
  }
}
