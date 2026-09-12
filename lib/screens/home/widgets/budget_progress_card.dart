import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class BudgetProgressCard extends StatelessWidget {
  final int spent;
  final int total;

  const BudgetProgressCard({required this.spent, required this.total, super.key});

  Color get _barColor {
    if (total == 0) return AppColors.success;
    final r = spent / total;
    if (r >= 1.0)  return AppColors.danger;
    if (r >= 0.80) return AppColors.warning;
    return AppColors.success;
  }

  double get _ratio => total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
  int    get _pct   => total > 0 ? (spent / total * 100).round()   : 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('💰 Ngân sách hôm nay',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _barColor.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
            child: Text('$_pct%', style: TextStyle(color: _barColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _ratio),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: _barColor,
              backgroundColor: _barColor.withOpacity(0.12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Đã dùng: ${CurrencyFormatter.format(spent)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(total > 0
              ? 'Còn lại: ${CurrencyFormatter.format((total - spent).clamp(0, total))}'
              : 'Chưa đặt ngân sách',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}
