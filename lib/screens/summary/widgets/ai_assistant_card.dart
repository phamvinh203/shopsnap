import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/ai_assistant_model.dart';
import '../../../widgets/ui/app_card.dart';

/// Thẻ hiển thị phân tích dự báo tài chính và lời khuyên tiết kiệm thông minh
/// từ AI. Restyle P3c: chỉ đổi da qua tokens/components (AppCard, context.snap,
/// context.text) — toàn bộ chuỗi và dữ liệu hiển thị giữ nguyên.
class AiAssistantCard extends StatelessWidget {
  final AiAssistantResponse data;

  const AiAssistantCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final pred = data.prediction;
    final advice = data.aiAdvice;
    final riskColor = _riskColor(context, pred);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: AppCard(
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header với biểu tượng AI ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.tintPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: colors.onTintPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md - 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trợ lý AI Tài Chính',
                          style: context.text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          data.periodLabel,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                _buildRiskBadge(context, pred),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Bảng thông số Dự báo chi tiêu ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              decoration: BoxDecoration(
                color: colors.tintPrimary.withOpacity(0.55),
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(
                        context,
                        label: 'Tốc độ chi tiêu',
                        value: '${CurrencyFormatter.format(pred.burnRatePerDay)}/ngày',
                        icon: Icons.speed,
                      ),
                      _buildMetric(
                        context,
                        label: 'Dự kiến cả tháng',
                        value: CurrencyFormatter.format(pred.projectedSpent),
                        icon: Icons.trending_up,
                        color: riskColor,
                        isBold: true,
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xl, thickness: 0.8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(
                        context,
                        label: 'Ngân sách tháng',
                        value: pred.budgetAmount != null
                            ? CurrencyFormatter.format(pred.budgetAmount!)
                            : 'Chưa đặt',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      _buildMetric(
                        context,
                        label: 'Hạn mức an toàn',
                        value: '${CurrencyFormatter.format(pred.safeDailyBudget)}/ngày',
                        icon: Icons.shield_outlined,
                        color: colors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Cảnh báo vượt ngân sách (nếu có) ───────────────────────────
            if (pred.isHighRisk && advice.warning != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.md - 2),
                decoration: BoxDecoration(
                  color: colors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md - 2),
                  border: Border.all(color: colors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: colors.danger, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        advice.warning!,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md + 2),

            // ── Nhận xét tổng quan của AI ──────────────────────────────────
            Text(
              advice.summary,
              style: (context.text.bodyMedium ?? const TextStyle())
                  .copyWith(height: 1.4, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: AppSpacing.md + 2),

            // ── 3 Mẹo tiết kiệm thông minh ─────────────────────────────────
            Text(
              'Mẹo hành động từ AI:',
              style: context.text.titleSmall
                  ?.copyWith(color: colors.onTintPrimary),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            ...advice.tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 3, right: AppSpacing.sm),
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: colors.onTintPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: (context.text.bodySmall ?? const TextStyle())
                              .copyWith(height: 1.35, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: AppSpacing.sm),

            // ── Source badge ───────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                data.source == 'gemini' ? '✨ Powered by Gemini' : '💡 Powered by Smart Heuristics',
                style: context.text.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: context.cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(BuildContext context, SpendingPrediction pred) {
    if (pred.isHighRisk) return context.snap.danger;
    if (pred.isMediumRisk) return context.snap.warning;
    return context.snap.success;
  }

  Widget _buildRiskBadge(BuildContext context, SpendingPrediction pred) {
    final color = _riskColor(context, pred);
    final label = pred.isHighRisk
        ? 'Nguy cơ bội chi'
        : (pred.isMediumRisk ? 'Cần lưu ý' : 'An toàn');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            label,
            style: context.text.labelLarge?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? context.cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs + 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: context.text.bodySmall?.copyWith(fontSize: 11)),
            Text(
              value,
              style: context.text.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: isBold ? color : context.cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
