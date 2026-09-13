import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/item_model.dart';
import '../../providers/items_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/sync_engine.dart';
import '../../widgets/update_dialog.dart';
import 'widgets/budget_progress_card.dart';
import 'widgets/category_chips_row.dart';
import 'widgets/item_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdateSilently();
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang kiểm tra bản cập nhật mới...'),
        duration: Duration(seconds: 1),
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bạn đang dùng phiên bản mới nhất (v${info.currentVersion})!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể kiểm tra cập nhật: $e'),
          backgroundColor: AppColors.danger,
        ),
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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(itemsProvider);
            await ref.read(syncProvider.notifier).triggerSync();
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Xin chào! 👋',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 2),
                        Text(DateHelper.formatDate(selectedDate),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
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
                                          ? Colors.orange
                                          : (syncState.pendingCount > 0 ? AppColors.primary : Colors.green),
                                    ),
                                  ),
                            onPressed: () async {
                              final res = await ref.read(syncProvider.notifier).triggerSync();
                              if (context.mounted && res != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.isSuccess
                                        ? 'Đồng bộ xong (đẩy: ${res.pushedCount}, kéo: ${res.pulledCount})'
                                        : (res.errorMessage ?? 'Đồng bộ thất bại')),
                                    duration: const Duration(seconds: 2),
                                  ),
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
                              backgroundColor: AppColors.danger,
                              child: Icon(
                                updateInfo?.hasUpdate == true
                                    ? Icons.system_update_rounded
                                    : Icons.notifications_outlined,
                                color: updateInfo?.hasUpdate == true
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            onPressed: _checkAppUpdateManually,
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Material(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          UpdateDialog.show(
                            context,
                            info: updateInfo,
                            onDismiss: () => ref.read(appUpdateProvider.notifier).dismiss(),
                            onDownload: (url) => ref.read(appUpdateProvider.notifier).download(url),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Text('🚀', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đã có phiên bản v${updateInfo.latestVersion}!',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Nhấn để xem chi tiết và cập nhật',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Cập nhật',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Budget card ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: budgetAsync.when(
                    data: (status) => BudgetProgressCard(
                      spent: status?.spent ?? 0,
                      total: status?.budget.amount ?? 0,
                    ),
                    loading: () => const _SkeletonCard(height: 100),
                    error:   (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Category chips ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: catsAsync.when(
                  data: (cats) => CategoryChipsRow(
                    categories: cats,
                    selected:   _filterCategory,
                    onSelected: (id) => setState(() => _filterCategory = id),
                  ),
                  loading: () => const SizedBox(height: 36),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Section header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: itemsAsync.when(
                    data: (items) {
                      final filtered = _applyFilter(items);
                      final total    = filtered.fold(0, (s, i) => s + i.price);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Hôm nay · ${filtered.length} items',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(CurrencyFormatter.format(total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error:   (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Item list ───────────────────────────────────────────────
              itemsAsync.when(
                data: (items) {
                  final filtered = _applyFilter(items);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🛍️', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('Chưa có gì hôm nay',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          const Text('Nhấn + để thêm vật phẩm đầu tiên',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ]),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ItemCard(
                          item:     filtered[index],
                          onDelete: () => _deleteItem(filtered[index]),
                          onTap:    () {},
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: _SkeletonCard(height: 72),
                    ),
                    childCount: 5,
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Lỗi: $e')),
                ),
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

  /// Xoá item — lỗi từ server (404/500, không phải mạng) → snackbar tiếng Việt;
  /// mất mạng thì deleteItem đã tự soft delete local nên không bao giờ kẹt.
  Future<void> _deleteItem(ItemModel item) async {
    try {
      await ref.read(itemsProvider.notifier).deleteItem(item.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:  Text(apiErrorMessage(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin:   const EdgeInsets.all(12),
        ));
      }
    }
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.divider.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
