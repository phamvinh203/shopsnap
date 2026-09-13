import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/ai_assistant_model.dart';

/// Thẻ hiển thị phân tích dự báo tài chính và lời khuyên tiết kiệm thông minh từ AI
class AiAssistantCard extends StatelessWidget {
  final AiAssistantResponse data;

  const AiAssistantCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final pred = data.prediction;
    final advice = data.aiAdvice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shadowColor: Colors.deepPurple.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF9F8FF),
              Color(0xFFFFFFFF),
            ],
          ),
          border: Border.all(
            color: pred.isHighRisk
                ? Colors.red.withOpacity(0.3)
                : const Color(0xFF6C5CE7).withOpacity(0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(18),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trợ lý AI Tài Chính',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        Text(
                          data.periodLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildRiskBadge(pred),
              ],
            ),

            const SizedBox(height: 16),

            // ── Bảng thông số Dự báo chi tiêu ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(
                        label: 'Tốc độ chi tiêu',
                        value: '${CurrencyFormatter.format(pred.burnRatePerDay)}/ngày',
                        icon: Icons.speed,
                        color: Colors.blueGrey,
                      ),
                      _buildMetric(
                        label: 'Dự kiến cả tháng',
                        value: CurrencyFormatter.format(pred.projectedSpent),
                        icon: Icons.trending_up,
                        color: pred.isHighRisk ? Colors.red : AppColors.primary,
                        isBold: true,
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 0.8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(
                        label: 'Ngân sách tháng',
                        value: pred.budgetAmount != null
                            ? CurrencyFormatter.format(pred.budgetAmount!)
                            : 'Chưa đặt',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.black87,
                      ),
                      _buildMetric(
                        label: 'Hạn mức an toàn',
                        value: '${CurrencyFormatter.format(pred.safeDailyBudget)}/ngày',
                        icon: Icons.shield_outlined,
                        color: Colors.green[700]!,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Cảnh báo vượt ngân sách (nếu có) ───────────────────────────
            if (pred.isHighRisk && advice.warning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        advice.warning!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Nhận xét tổng quan của AI ──────────────────────────────────
            Text(
              advice.summary,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF2D3436),
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 14),

            // ── 3 Mẹo tiết kiệm thông minh ─────────────────────────────────
            const Text(
              'Mẹo hành động từ AI:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C5CE7),
              ),
            ),
            const SizedBox(height: 6),
            ...advice.tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 8),
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Color(0xFF6C5CE7),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 8),

            // ── Source badge ───────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                data.source == 'gemini' ? '✨ Powered by Gemini' : '💡 Powered by Smart Heuristics',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(SpendingPrediction pred) {
    Color bg;
    Color text;
    String label;

    if (pred.isHighRisk) {
      bg = Colors.red.withOpacity(0.12);
      text = Colors.red[700]!;
      label = 'Nguy cơ bội chi';
    } else if (pred.isMediumRisk) {
      bg = Colors.orange.withOpacity(0.12);
      text = Colors.orange[800]!;
      label = 'Cần lưu ý';
    } else {
      bg = Colors.green.withOpacity(0.12);
      text = Colors.green[700]!;
      label = 'An toàn';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: text, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: isBold ? color : const Color(0xFF2D3436),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
