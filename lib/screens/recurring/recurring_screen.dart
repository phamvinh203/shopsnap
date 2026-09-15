import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../models/recurring_expense_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recurring_expense_provider.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/app_scaffold.dart';
import '../../widgets/ui/app_states.dart';
import '../../widgets/ui/loading_skeleton.dart';
import 'widgets/recurring_expense_edit_sheet.dart';
import 'widgets/recurring_expense_tile.dart';
import 'widgets/recurring_suggestion_card.dart';

/// M-2 — Màn quản lý khoản chi định kỳ (route `/recurring`, HOÀN TOÀN LOCAL:
/// SQLite, không network, không sync — AC 4.7/4.15).
///
/// Layout: card gợi ý "Có vẻ là khoản định kỳ" (AC 4.10 — ẩn khi rỗng) phía
/// trên danh sách; mục chính là các entry đang bật, dưới là mục "Đã tắt"
/// (style mờ — AC 4.2). Mở màn → re-arm nhắc trước hạn (AC 4.11b/4.12).
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  @override
  void initState() {
    super.initState();
    // AC 4.11(b)/4.12: app mở lên màn recurring → re-arm (hủy schedule cũ +
    // đặt đúng 1 pending cho chu kỳ kế tiếp của mỗi entry đang bật).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurringExpensesProvider.notifier).rearmReminders();
    });
  }

  Future<void> _openAddSheet() =>
      RecurringExpenseEditSheet.showForCreate(context);

  Future<void> _toggle(RecurringExpense entry, bool active) async {
    await ref.read(recurringExpensesProvider.notifier).setActive(
          entry.id,
          active,
        );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(recurringExpensesProvider);
    final suggestionsAsync = ref.watch(recurringSuggestionsProvider);
    final permissionDenied = ref.watch(notificationPermissionDeniedProvider);

    return AppScaffold(
      title: 'Khoản định kỳ',
      actions: [
        IconButton(
          key: const Key('recurring_addButton'),
          icon: const Icon(Icons.add),
          tooltip: 'Thêm khoản định kỳ',
          onPressed: _openAddSheet,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: listAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: SkeletonList(itemCount: 3, itemHeight: 96),
              ),
              // Local-only: không có lỗi network thật; lỗi DB → ErrorState + retry.
              error: (e, _) => ErrorState(
                message: 'Không đọc được khoản định kỳ trên máy này.',
                onRetry: () => ref.invalidate(recurringExpensesProvider),
              ),
              data: (entries) {
                final active =
                    entries.where((e) => e.isActive).toList(growable: false);
                final inactive =
                    entries.where((e) => !e.isActive).toList(growable: false);
                final suggestions =
                    suggestionsAsync.valueOrNull ?? const [];

                return ListView(
                  key: const Key('recurring_listView'),
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    // ── AC 4.14: thiếu quyền POST_NOTIFICATIONS → hint hướng
                    // dẫn bật trong system settings; thao tác vẫn chạy bình thường.
                    if (permissionDenied) ...[
                      AppCard(
                        key: const Key('recurring_permissionHint'),
                        tint: context.snap.warning.withOpacity(0.10),
                        child: Row(
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 20, color: context.snap.warning),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Thông báo đang tắt — khoản vẫn được lưu, nhưng sẽ không có nhắc. Bật trong Cài đặt để nhận nhắc trước hạn.',
                                style: context.text.bodySmall,
                              ),
                            ),
                            TextButton(
                              key: const Key('recurring_permissionSettings'),
                              onPressed: _openSystemNotificationSettings,
                              child: const Text('Mở cài đặt'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── AC 4.10: card gợi ý — ẩn hoàn toàn khi không có gợi ý.
                    if (suggestions.isNotEmpty) ...[
                      RecurringSuggestionCard(suggestions: suggestions),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    if (entries.isEmpty) ...[
                      const SizedBox(height: AppSpacing.huge),
                      EmptyState(
                        icon: Icons.event_repeat_rounded,
                        title: 'Chưa có khoản định kỳ',
                        message:
                            'Khai báo các khoản chi lặp lại (tiền nhà, mạng, '
                            'Netflix…) để nhận nhắc trước ngày đến hạn. App cũng '
                            'sẽ tự nhận diện từ lịch sử mua của bạn.',
                        actionLabel: 'Thêm khoản định kỳ',
                        onAction: _openAddSheet,
                      ),
                    ] else ...[
                      for (final e in active)
                        RecurringExpenseTile(
                          key: ValueKey('recurring_row_${e.id}'),
                          entry: e,
                          onToggle: (v) => _toggle(e, v),
                          onTap: () =>
                              RecurringExpenseEditSheet.showForEdit(context, e),
                        ),

                      // ── Mục "Đã tắt" (AC 4.2/4.5): style mờ, toggle bật lại.
                      if (inactive.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xs, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
                          child: Text(
                            'ĐÃ TẮT',
                            key: const Key('recurring_inactiveHeader'),
                            style: context.text.labelMedium?.copyWith(
                              color: context.cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        for (final e in inactive)
                          RecurringExpenseTile(
                            key: ValueKey('recurring_row_${e.id}'),
                            entry: e,
                            onToggle: (v) => _toggle(e, v),
                            onTap: () => RecurringExpenseEditSheet.showForEdit(
                                context, e),
                          ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// AC 4.14 — mở cài đặt hệ thống để cấp quyền POST_NOTIFICATIONS (pattern
  /// AC 12.13 của Home). permission_handler là method channel: môi trường
  /// test/thiết bị lạ có thể ném MissingPluginException → nuốt để hint vẫn dùng được.
  Future<void> _openSystemNotificationSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}
