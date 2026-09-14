import 'package:flutter/material.dart';

import '../../core/theme/snap_colors.dart';
import 'money_text.dart';

/// Header section — thay Row "Hôm nay · N items | 123.000đ" copy-paste.
///
/// Truyền hoặc [trailing] (widget tuỳ ý) hoặc [amount] (int → MoneyText màu
/// brand, tabular figures).
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
            title,
            key: const Key('sectionHeader_title'),
            style: context.text.titleSmall,
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
            style: TextStyle(fontSize: 14, color: context.cs.primary),
          ),
      ],
    );
  }
}
