import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../widgets/ui/app_card.dart';

/// F-#2 (AC 2.5): card insight FALLBACK khi AI lỗi / quá timeout / chưa đăng
/// nhập — text sinh local từ aggregates (pure `heuristicSpendingInsight`).
/// Dashboard KHÔNG được bỏ trống ô insight trong mọi trường hợp.
class HeuristicInsightCard extends StatelessWidget {
  final String text;

  const HeuristicInsightCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: AppCard(
        key: const Key('aiInsight_fallback'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.tintPrimary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.lightbulb_outline,
                  color: colors.onTintPrimary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gợi ý nhanh',
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    text,
                    key: const Key('aiInsight_fallbackText'),
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// F-#2 (AC 2.6): skeleton RIÊNG của AI card trong lúc chờ AI — các phần khác
/// (hero, breakdown) KHÔNG chờ AI, render luôn.
class AiInsightSkeleton extends StatelessWidget {
  const AiInsightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('aiInsight_loading'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.snap.skeleton,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 12,
                    color: context.snap.skeleton,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    height: 10,
                    color: context.snap.skeleton,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
