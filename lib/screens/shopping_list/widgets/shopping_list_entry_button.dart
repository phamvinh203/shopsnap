import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/snap_colors.dart';
import '../../../providers/shopping_list_provider.dart';

/// Entry Shopping List trên app bar Home (F-#6).
///
/// [QUYẾT ENTRY POINT] Spec không chỉ định vị trí cụ thể → đặt icon trên app
/// bar Home, theo đúng pattern F-#10 (/profile) — KHÔNG thêm bottom-nav tab
/// (shell giữ nguyên 3 tab). Badge đếm số món có alert giá CHƯA xem (AC 6.13);
/// badge tự clear khi user mở màn list.
class ShoppingListEntryButton extends ConsumerWidget {
  const ShoppingListEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unseenAsync = ref.watch(shoppingListUnseenAlertsProvider);
    final unseen = unseenAsync.valueOrNull ?? 0;

    return IconButton(
      key: const Key('homeScreen_shoppingListButton'),
      tooltip: unseen > 0
          ? 'Danh sách mua · $unseen món có giá tốt'
          : 'Danh sách mua',
      icon: Badge(
        key: const Key('homeScreen_shoppingListBadge'),
        isLabelVisible: unseen > 0,
        label: Text('$unseen'),
        backgroundColor: context.snap.danger,
        child: Icon(
          unseen > 0
              ? Icons.notifications_active_rounded
              : Icons.checklist_rounded,
          color: unseen > 0 ? context.cs.primary : context.cs.onSurfaceVariant,
        ),
      ),
      onPressed: () => context.push('/shopping-list'),
    );
  }
}
