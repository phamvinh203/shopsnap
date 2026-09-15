import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/relative_time.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_api_service.dart';
import '../../widgets/ui/ui.dart';

/// Màn Notification Feed (F-#12 AC 12.9–12.12) — mở từ bell icon trên app bar
/// Home. Mới nhất trước (BE sort), mỗi dòng title/body/thời gian tương đối +
/// trạng thái read; pull-to-refresh; empty state; offline → giữ cache kèm
/// chỉ báo "chưa cập nhật được". Bấm dòng → PATCH mark-read (im lặng khi lỗi)
/// và badge trên Home giảm tương ứng (AC 12.10).
class NotificationFeedScreen extends ConsumerStatefulWidget {
  const NotificationFeedScreen({super.key});

  @override
  ConsumerState<NotificationFeedScreen> createState() =>
      _NotificationFeedScreenState();
}

class _NotificationFeedScreenState extends ConsumerState<NotificationFeedScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// AC 12.9 Notes — poll khi app vào foreground: quay lại app khi đang mở
  /// feed → tự refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationFeedProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(notificationFeedProvider);

    return AppScaffold(
      title: 'Thông báo',
      body: SafeArea(
        top: false,
        child: feedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SkeletonList(itemCount: 6, itemHeight: 76),
          ),
          error: (e, _) => ErrorState(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(notificationFeedProvider),
          ),
          data: (feed) => RefreshIndicator(
            color: context.cs.primary,
            onRefresh: () => ref.read(notificationFeedProvider.notifier).refresh(),
            child: _FeedList(feed: feed),
          ),
        ),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  final NotificationFeedState feed;
  const _FeedList({required this.feed});

  @override
  Widget build(BuildContext context) {
    if (feed.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Chưa có thông báo',
            message: 'Cảnh báo ngân sách và cập nhật giá sẽ xuất hiện ở đây.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      itemCount: feed.items.length + (feed.isStale ? 1 : 0),
      itemBuilder: (context, index) {
        // AC 12.12 — chỉ báo "chưa cập nhật được" đặt đầu danh sách.
        if (feed.isStale && index == 0) return const _StaleBanner();
        final notification = feed.items[index - (feed.isStale ? 1 : 0)];
        return _NotificationTile(
          key: Key('notificationTile_${notification.id}'),
          notification: notification,
        );
      },
    );
  }
}

/// Đúng tokens Ink Ledger: card warning tint + icon + microcopy tiếng Việt.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('notificationFeed_staleBanner'),
        margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.snap.warning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: context.snap.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Chưa cập nhật được — đang hiển thị dữ liệu đã tải. Kéo xuống để thử lại.',
              style: context.text.bodySmall?.copyWith(color: context.snap.warning),
            ),
          ),
        ]),
      );
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.snap;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
      onTap: () => ref.read(notificationFeedProvider.notifier).markRead(notification.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trạng thái read: chấm accent khi chưa đọc, icon mờ khi đã đọc.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: notification.read
                  ? colors.hairline
                  : colors.tintPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              notification.type.contains('price')
                  ? Icons.local_offer_outlined
                  : Icons.savings_outlined,
              size: 18,
              color: notification.read ? colors.textSecondary : colors.onTintPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (!notification.read)
                    Container(
                      key: const Key('notificationTile_unreadDot'),
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      decoration:
                          BoxDecoration(color: context.cs.primary, shape: BoxShape.circle),
                    ),
                  Expanded(
                    child: Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight:
                            notification.read ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatRelativeTime(
              notification.createdAt.toLocal(),
              now: DateTime.now(),
            ),
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
