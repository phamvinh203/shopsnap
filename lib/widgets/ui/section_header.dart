import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import 'money_text.dart';

/// Header section — "số là nhân vật": title = overline HOA 11/w700 ls 1.2,
/// amount = moneyOf 14 mực. Thay Row "Hôm nay · N items | 123.000đ" copy-paste.
///
/// Truyền hoặc [trailing] (widget tuỳ ý) hoặc [amount] (int → MoneyText mực,
/// tabular figures).
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final int? amount;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('sectionHeader'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            // Overline hiện HOA theo spec (caller truyền dạng tự nhiên).
            title.toUpperCase(),
            key: const Key('sectionHeader_title'),
            style: AppTypography.overlineOf(
              context.text,
              color: context.cs.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          trailing!
        else if (amount != null)
          MoneyText(
            key: const Key('sectionHeader_amount'),
            amount: amount!,
            colored: true,
            style: const TextStyle(fontSize: 14),
          ),
      ],
    );
  }
}
