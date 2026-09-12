import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class PriceComparisonHint extends StatelessWidget {
  final int  currentPrice;
  final int? lastPrice;
  final int? avgPrice;

  const PriceComparisonHint({
    required this.currentPrice,
    this.lastPrice,
    this.avgPrice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (lastPrice == null && avgPrice == null) return const SizedBox.shrink();

    final widgets = <Widget>[];

    if (lastPrice != null && lastPrice! > 0) {
      final diff      = currentPrice - lastPrice!;
      final pct       = (diff / lastPrice! * 100).round().abs();
      final isCheaper = diff <= 0;
      widgets.add(_HintChip(
        icon:  isCheaper ? Icons.arrow_downward : Icons.arrow_upward,
        color: isCheaper ? AppColors.success     : AppColors.danger,
        label: 'Lần trước: ${CurrencyFormatter.format(lastPrice!)}  (${isCheaper ? "-" : "+"}$pct%)',
      ));
    }

    if (avgPrice != null && avgPrice! > 0 && currentPrice <= avgPrice! * 0.90) {
      widgets.add(const _HintChip(
        icon: Icons.star_outline, color: AppColors.success, label: 'Giá tốt hơn trung bình!',
      ));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...widgets.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)),
    ]);
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _HintChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}
