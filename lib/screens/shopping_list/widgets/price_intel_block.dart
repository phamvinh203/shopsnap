import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/shopping_list_item_model.dart';
import '../../../providers/shopping_list_provider.dart';
import 'price_sparkline.dart';

/// Khối price intelligence trên mỗi dòng Shopping List (F-#6 AC 6.9–6.12).
///
/// - Món KHÔNG khớp sản phẩm đã mua (hoặc đang loading/lỗi tra cứu) → ẩn TOÀN
///   BỘ khối — không chart rỗng, không "0 đ" (AC 6.10).
/// - Khớp → sparkline + nhãn "Giá tốt nhất trong 90 ngày: X đ (ngày Y)" với X
///   format VND số nguyên qua [CurrencyFormatter] (AC 6.9).
/// - Nút "Theo dõi giá" toggle watched, persist local (AC 6.12).
class PriceIntelBlock extends ConsumerWidget {
  final ShoppingListItem item;

  const PriceIntelBlock({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ShoppingMatchKey(name: item.name, barcode: item.barcode);
    final intelAsync = ref.watch(shoppingItemPriceIntelProvider(key));

    return intelAsync.when(
      skipLoadingOnReload: true,
      data: (intel) {
        // AC 6.10: không khớp → không render gì.
        if (intel == null || intel.points.isEmpty) return const SizedBox.shrink();

        final best = intel.bestIn90Days;
        final snap = context.snap;

        return Container(
          key: Key('priceIntelBlock_${item.id}'),
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: snap.tintPrimary.withOpacity(0.45),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PriceSparkline(prices: intel.points.map((p) => p.price).toList()),
              const SizedBox(height: AppSpacing.sm),
              if (best != null)
                Text(
                  'Giá tốt nhất trong 90 ngày: ${CurrencyFormatter.format(best.price)} '
                  '(ngày ${best.date.day}/${best.date.month})',
                  key: Key('priceIntel_bestLabel_${item.id}'),
                  style: context.text.labelMedium
                      ?.copyWith(color: snap.onTintPrimary),
                ),
              Text(
                'Giá gần nhất: ${CurrencyFormatter.format(intel.latestPrice)}',
                key: Key('priceIntel_latestLabel_${item.id}'),
                style: context.text.bodySmall
                    ?.copyWith(color: snap.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              _WatchButton(item: item),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _WatchButton extends ConsumerWidget {
  final ShoppingListItem item;

  const _WatchButton({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = context.snap;
    final watched = item.watched;

    // Ngôn ngữ CategoryChip: lime "bút dạ" = trạng thái bật (đang theo dõi).
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        key: Key('shoppingItem_watch_${item.id}'),
        avatar: Icon(
          watched
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: 16,
          color: watched ? snap.onAccent : context.cs.onSurfaceVariant,
        ),
        label: Text(
          watched ? 'Đang theo dõi giá' : 'Theo dõi giá',
          style: context.text.labelMedium?.copyWith(
            color: watched ? snap.onAccent : context.cs.onSurfaceVariant,
          ),
        ),
        backgroundColor: watched ? snap.accent : Colors.transparent,
        side: BorderSide(color: watched ? Colors.transparent : snap.hairline),
        onPressed: () =>
            ref.read(shoppingListProvider.notifier).toggleWatched(item.id),
      ),
    );
  }
}
