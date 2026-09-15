import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/budget_alert.dart';
import '../../core/utils/budget_insights.dart';
import '../../core/utils/date_helper.dart';
import '../../models/item_model.dart';
import '../../providers/items_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/all_budgets_provider.dart';
import '../../services/sync_engine.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/update_dialog.dart';
import '../shopping_list/widgets/shopping_list_entry_button.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/category_chips_row.dart';
import 'widgets/item_card.dart';
import 'widgets/item_detail_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdateSilently();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// F-#12 (AC 12.8 Notes — poll khi app vào foreground): quay lại app → làm
  /// mới badge số notification chưa đọc.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(unreadNotificationsCountProvider);
    }
  }

  Future<void> _checkAppUpdateSilently() async {
    final notifier = ref.read(appUpdateProvider.notifier);
    final info = await notifier.checkSilently();
    if (!mounted || info == null || !info.hasUpdate) return;

    UpdateDialog.show(
      context,
      info: info,
      onDismiss: () => notifier.dismiss(),
      onDownload: (url) => notifier.download(url),
    );
  }

  Future<void> _checkAppUpdateManually() async {
    final notifier = ref.read(appUpdateProvider.notifier);
    AppSnackBar.show(
      context: context,
      message: 'Đang kiểm tra bản cập nhật mới...',
      duration: const Duration(seconds: 1),
    );

    try {
      final info = await notifier.checkManually();
      if (!mounted) return;

      if (info.hasUpdate) {
        UpdateDialog.show(
          context,
          info: info,
          onDismiss: () => notifier.dismiss(),
          onDownload: (url) => notifier.download(url),
        );
      } else {
        AppSnackBar.show(
          context: context,
          message: 'Bạn đang dùng phiên bản mới nhất (v${info.currentVersion})!',
          tone: AppSnackBarTone.success,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Không hiện raw exception — map sang microcopy tiếng Việt.
      AppSnackBar.show(
        context: context,
        message: apiErrorMessage(e),
        tone: AppSnackBarTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync    = ref.watch(itemsProvider);
    final budgetAsync   = ref.watch(budgetStatusProvider);
    final catsAsync     = ref.watch(categoriesProvider);
    final selectedDate  = ref.watch(selectedDateProvider);
    final syncState     = ref.watch(syncProvider);
    final updateState   = ref.watch(appUpdateProvider);
    final updateInfo    = updateState.info.valueOrNull;
    // F-#12 (AC 12.8): badge bell = số notification chưa đọc; lỗi/offline → 0.
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    // F-#12 (AC 12.13): notification bị chặn quyền → banner hướng dẫn bật.
    final permissionDenied = ref.watch(notificationPermissionDeniedProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: context.cs.primary,
          onRefresh: () async {
            ref.invalidate(itemsProvider);
            await ref.read(syncProvider.notifier).triggerSync();
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Xin chào! 👋', style: context.text.headlineMedium),
                        const SizedBox(height: 2),
                        // Ngày = overline nhỏ (HOA, ls 1.2) — bảng 4.1.
                        Text(DateHelper.formatDate(selectedDate).toUpperCase(),
                            style: AppTypography.overlineOf(
                              context.text,
                              color: context.cs.onSurfaceVariant,
                            )),
                      ]),
                      Row(
                        children: [
                          IconButton(
                            tooltip: syncState.isSyncing
                                ? 'Đang đồng bộ...'
                                : (syncState.pendingCount > 0
                                    ? 'Có ${syncState.pendingCount} thay đổi chờ đồng bộ'
                                    : 'Dữ liệu đã đồng bộ đám mây'),
                            icon: syncState.isSyncing
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.cs.primary,
                                    ),
                                  )
                                : Badge(
                                    isLabelVisible: syncState.pendingCount > 0,
                                    label: Text('${syncState.pendingCount}'),
                                    child: Icon(
                                      syncState.pendingCount > 0
                                          ? Icons.cloud_upload_outlined
                                          : Icons.cloud_done_outlined,
                                      color: syncState.status == SyncStatus.error
                                          ? context.snap.warning
                                          : (syncState.pendingCount > 0
                                              ? context.cs.primary
                                              : context.snap.success),
                                    ),
                                  ),
                            onPressed: () async {
                              final res = await ref.read(syncProvider.notifier).triggerSync();
                              if (context.mounted && res != null) {
                                AppSnackBar.show(
                                  context: context,
                                  message: res.isSuccess
                                      ? 'Đồng bộ xong (đẩy: ${res.pushedCount}, kéo: ${res.pulledCount})'
                                      : (res.errorMessage ?? 'Đồng bộ thất bại'),
                                  tone: res.isSuccess
                                      ? AppSnackBarTone.success
                                      : AppSnackBarTone.danger,
                                  duration: const Duration(seconds: 2),
                                );
                              }
                            },
                          ),
                          IconButton(
                            tooltip: updateInfo?.hasUpdate == true
                                ? 'Có bản cập nhật mới v${updateInfo!.latestVersion}'
                                : 'Kiểm tra bản cập nhật',
                            icon: Badge(
                              isLabelVisible: updateInfo?.hasUpdate == true,
                              backgroundColor: context.snap.danger,
                              child: Icon(
                                updateInfo?.hasUpdate == true
                                    ? Icons.system_update_rounded
                                    : Icons.notifications_outlined,
                                color: updateInfo?.hasUpdate == true
                                    ? context.cs.primary
                                    : context.cs.onSurfaceVariant,
                              ),
                            ),
                            onPressed: _checkAppUpdateManually,
                          ),
                          // F-#12 (AC 12.8/12.9): bell → Notification Feed,
                          // badge = số chưa đọc, biến mất khi = 0.
                          IconButton(
                            key: const Key('homeScreen_notificationBell'),
                            tooltip: unreadNotifications > 0
                                ? 'Thông báo · $unreadNotifications chưa đọc'
                                : 'Thông báo',
                            icon: Badge(
                              key: const Key('homeScreen_notificationBadge'),
                              isLabelVisible: unreadNotifications > 0,
                              backgroundColor: context.snap.danger,
                              label: Text(
                                // AC 12.8 — quá 99 thông báo: hiển thị "99+".
                                notificationBadgeLabel(unreadNotifications),
                              ),
                              child: Icon(
                                Icons.notifications_outlined,
                                color: unreadNotifications > 0
                                    ? context.cs.primary
                                    : context.cs.onSurfaceVariant,
                              ),
                            ),
                            onPressed: () => context.push('/notifications'),
                          ),
                          // F-#6: Danh sách mua + badge alert giá chưa xem.
                          const ShoppingListEntryButton(),
                          // F-#10 (AC 10.1): avatar/app bar → mở /profile.
                          IconButton(
                            key: const Key('homeScreen_profileButton'),
                            tooltip: 'Hồ sơ & dữ liệu',
                            icon: Icon(
                              Icons.account_circle_outlined,
                              color: context.cs.onSurfaceVariant,
                            ),
                            onPressed: () => context.push('/profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Update Banner (nếu có bản mới) ──────────────────────────
              if (updateInfo != null && updateInfo.hasUpdate)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: AppCard(
                      tint: context.snap.tintPrimary,
                      hairline: false,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                      onTap: () {
                        UpdateDialog.show(
                          context,
                          info: updateInfo,
                          onDismiss: () => ref.read(appUpdateProvider.notifier).dismiss(),
                          onDownload: (url) => ref.read(appUpdateProvider.notifier).download(url),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.cs.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.rocket_launch_outlined,
                              color: context.snap.onTintPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đã có phiên bản v${updateInfo.latestVersion}!',
                                  style: context.text.titleSmall
                                      ?.copyWith(color: context.snap.onTintPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nhấn để xem chi tiết và cập nhật',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: context.snap.onTintPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'Cập nhật',
                              style: context.text.labelLarge?.copyWith(
                                fontSize: 12,
                                // Badge nền onTintPrimary (#4B44CC light /
                                // #8B85FF dark) → chữ đọc onPrimary thay vì
                                // white hardcode (white chai contrast kém ở
                                // dark, light vẫn trắng y cũ).
                                color: context.cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── F-#12 (AC 12.13): notification bị chặn quyền → banner hướng
              // dẫn bật trong system settings (thay thế alert không gửi được).
              if (permissionDenied)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: AppCard(
                      key: const Key('homeNotificationPermissionBanner'),
                      tint: context.snap.warning.withOpacity(0.10),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 20, color: context.snap.warning),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Thông báo đang tắt — bật trong Cài đặt để không bỏ lỡ cảnh báo ngân sách.',
                              style: context.text.bodySmall,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            key: const Key('homeNotificationPermissionSettings'),
                            onPressed: _openSystemNotificationSettings,
                            child: const Text('Mở cài đặt'),
                          ),
                          IconButton(
                            key: const Key('homeNotificationPermissionDismiss'),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => ref
                                .read(notificationPermissionDeniedProvider.notifier)
                                .state = false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Hero card: ngân sách hôm nay (gradient tím duy nhất) ────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: budgetAsync.when(
                    data: (status) => BudgetProgressCard(
                      spent: status?.spent ?? 0,
                      total: status?.budget.amount ?? 0,
                      // F-#3 Smart Budget: kỳ ngân sách để tính burn rate /
                      // safe daily / forecast (ngày hỏng → card ẩn strip).
                      periodStart:
                          tryParseBudgetDate(status?.budget.startDate),
                      periodEnd: tryParseBudgetDate(status?.budget.endDate),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: LoadingSkeleton(
                          width: double.infinity, height: 172, radius: AppRadius.xl),
                    ),
                    // Lỗi không còn bị nuốt: hiện ErrorState + Thử lại
                    error: (e, _) => ErrorState(
                      message: apiErrorMessage(e),
                      onRetry: () {
                        ref.invalidate(allBudgetsProvider);
                        ref.invalidate(budgetStatusProvider);
                      },
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // ── Category chips ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: catsAsync.when(
                  data: (cats) => CategoryChipsRow(
                    categories: cats,
                    selected:   _filterCategory,
                    onSelected: (id) => setState(() => _filterCategory = id),
                  ),
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: SizedBox(
                      height: 38,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            const Padding(
                              padding: EdgeInsets.only(right: AppSpacing.sm),
                              child: LoadingSkeleton(width: 88, height: 34, radius: AppRadius.sm),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Lỗi không còn bị nuốt: hiện ErrorState + Thử lại
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: ErrorState(
                      message: apiErrorMessage(e),
                      onRetry: () => ref.invalidate(categoriesProvider),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // ── Section header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: itemsAsync.when(
                    data: (items) {
                      final filtered = _applyFilter(items);
                      final total    = filtered.fold(0, (s, i) => s + i.price);
                      return SectionHeader(
                        title: 'Hôm nay · ${filtered.length} mặt hàng',
                        amount: total,
                      );
                    },
                    loading: () => const Align(
                      alignment: Alignment.centerLeft,
                      child: LoadingSkeleton(width: 180, height: 20),
                    ),
                    // Lỗi không còn bị nuốt: hiện ErrorState + Thử lại
                    error: (e, _) => ErrorState(
                      message: apiErrorMessage(e),
                      onRetry: () => ref.invalidate(itemsProvider),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

              // ── Item list ───────────────────────────────────────────────
              itemsAsync.when(
                data: (items) {
                  final filtered = _applyFilter(items);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Chưa có gì hôm nay',
                        message: 'Ghi nhanh món vừa mua để theo dõi chi tiêu nhé!',
                        actionLabel: 'Thêm mặt hàng đầu tiên',
                        onAction: () => context.push('/add'),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filtered[index];
                          // Sửa bug tap chết: mở bottom-sheet sửa nhanh (H1).
                          return ItemCard(
                            key: Key('itemCard_${item.id}'),
                            item:     item,
                            onDelete: () => _deleteItem(item),
                            onTap:    () => ItemDetailSheet.show(context, item),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: SkeletonList(itemCount: 5, itemHeight: 72),
                  ),
                ),
                // Lỗi itemsProvider đã hiển thị ErrorState + "Thử lại" ở
                // section header ngay phía trên (cùng 1 provider — không lặp
                // 2 ErrorState chồng nhau).
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ItemModel> _applyFilter(List<ItemModel> items) {
    if (_filterCategory == null) return items;
    return items.where((i) => i.categoryId == _filterCategory).toList();
  }

  /// AC 12.13 — mở cài đặt hệ thống để cấp quyền POST_NOTIFICATIONS.
  /// permission_handler là method channel: môi trường test/thiết bị lạ có thể
  /// ném MissingPluginException → nuốt để banner vẫn dismiss được.
  Future<void> _openSystemNotificationSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }

  /// Xoá item — lỗi từ server (404/500, không phải mạng) → snackbar tiếng Việt;
  /// mất mạng thì deleteItem đã tự soft delete local nên không bao giờ kẹt.
  Future<void> _deleteItem(ItemModel item) async {
    try {
      await ref.read(itemsProvider.notifier).deleteItem(item.id);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: apiErrorMessage(e),
          tone: AppSnackBarTone.danger,
        );
      }
    }
  }
}
