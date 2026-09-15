import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/logout_flow.dart';
import '../../providers/auth_provider.dart';
import '../../providers/export_provider.dart';
import '../../providers/notification_preferences_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/theme_mode_section.dart';

/// Màn Hồ sơ & dữ liệu (/profile) — F-#10.
///
/// 6 section đúng thứ tự spec (AC 10.2): Account info → Sync status →
/// Dữ liệu local → Appearance → Export → Logout.
///
/// Auth gate mềm (PO chốt 2026-09-14): CHƯA đăng nhập vẫn mở được /profile —
/// các mục account/sync hiện trạng thái "chưa đăng nhập" kèm CTA đăng nhập.
/// Delete account KHÔNG render ở bất kỳ đâu (AC 10.9 — chưa đủ điều kiện
/// security: re-auth + tombstone sync).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final authenticated = auth?.isAuthenticated == true;
    final user = auth?.user;

    return AppScaffold(
      title: 'Hồ sơ & dữ liệu',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _SectionHeader('Tài khoản'),
          _AccountSection(
            authenticated: authenticated,
            name: user?.displayName ?? '',
            email: user?.email ?? '',
          ),

          const _SectionHeader('Đồng bộ'),
          _SyncStatusSection(authenticated: authenticated),

          const _SectionHeader('Dữ liệu local'),
          const _LocalDataSection(),
          const SizedBox(height: AppSpacing.sm),
          // M-2: Khoản chi định kỳ — entry point theo spec Notes (nhóm quản
          // lý dữ liệu của /profile, [ASSUMPTION]); offline hoàn toàn, auth
          // gate mềm: chưa đăng nhập vẫn dùng được.
          const _RecurringEntrySection(),

          const _SectionHeader('Giao diện'),
          const AppCard(child: ThemeModeSection()),

          // F-#12 (AC 12.7): toggle notification — chỉ lưu local (BE chưa có
          // endpoint preference); tắt → không local notification loại đó,
          // feed server vẫn hiện record do BE tạo.
          const _SectionHeader('Thông báo'),
          const _NotificationPrefsSection(),

          const _SectionHeader('Xuất dữ liệu'),
          const _ExportSection(),

          if (authenticated) ...[
            const _SectionHeader('Tài khoản'),
            const _LogoutSection(),
          ],
        ],
      ),
    );
  }
}

// ── Section header nhỏ ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs,
            AppSpacing.xs, AppSpacing.sm),
        child: Text(
          title.toUpperCase(),
          style: context.text.labelMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );
}

// ── 1. Account info (AC 10.2 mục 1) ──────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  final bool authenticated;
  final String name;
  final String email;

  const _AccountSection({
    required this.authenticated,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    if (!authenticated) {
      // Chưa đăng nhập → tile mời đăng nhập (auth gate mềm, như settings sheet).
      return AppCard(
        child: ListTile(
          key: const Key('profile_accountLoggedOut'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.account_circle_outlined,
              size: 40, color: context.cs.onSurfaceVariant),
          title: const Text('Chưa đăng nhập'),
          subtitle: Text('Dữ liệu đang lưu trên máy này',
              style: context.text.bodySmall),
          trailing: Icon(Icons.chevron_right,
              color: context.cs.onSurfaceVariant),
          onTap: () => context.push('/login'),
        ),
      );
    }

    return AppCard(
      child: Row(
        key: const Key('profile_accountCard'),
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: context.snap.tintPrimary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: context.text.titleMedium
                  ?.copyWith(color: context.snap.onTintPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(email, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Sync status (AC 10.3) ─────────────────────────────────────────────────

class _SyncStatusSection extends ConsumerWidget {
  final bool authenticated;
  const _SyncStatusSection({required this.authenticated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authenticated) {
      return const AppCard(
        child: ListTile(
          key: Key('profile_syncLoggedOut'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Chưa đăng nhập'),
          subtitle: Text('Đăng nhập để đồng bộ dữ liệu lên máy chủ'),
        ),
      );
    }

    final sync = ref.watch(syncProvider);
    final persisted = ref.watch(syncPersistedProvider);
    final last = sync.lastSyncedAt;

    return AppCard(
      key: const Key('profile_syncSection'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusRow(
            icon: Icons.history_rounded,
            label: 'Last synced',
            value: last == null
                ? 'Chưa từng đồng bộ'
                : '${DateHelper.formatDateShort(last)} '
                    '${DateHelper.formatTime(last.millisecondsSinceEpoch)}',
            valueKey: const Key('profile_syncLastSynced'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(
            icon: Icons.sync_problem_outlined,
            label: 'Thay đổi chờ đồng bộ',
            value: sync.isSyncing ? 'Đang đồng bộ…' : '${sync.pendingCount}',
            valueKey: const Key('profile_syncPending'),
          ),
          // G2 chưa mở → nhãn trạng thái để user không hiểu lầm là đã backup
          // an toàn (AC 10.3).
          if (!persisted) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              key: const Key('profile_syncNotPersisted'),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs + 1),
              decoration: BoxDecoration(
                color: context.snap.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline,
                    size: 14, color: context.snap.warning),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Chưa có đồng bộ nền',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.snap.warning),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Key valueKey;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: context.cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Text(value,
              key: valueKey,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      );
}

// ── 3. Dữ liệu local (AC 10.4) ───────────────────────────────────────────────

class _LocalDataSection extends ConsumerWidget {
  const _LocalDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(localDataStatsProvider);

    return AppCard(
      key: const Key('profile_localSection'),
      child: statsAsync.when(
        loading: () => const Padding(
          key: Key('profile_localLoading'),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => ErrorState(
          message: 'Không đọc được dữ liệu local trên máy này.',
          onRetry: () => ref.invalidate(localDataStatsProvider),
        ),
        data: (stats) => Row(
          key: const Key('profile_localStats'),
          children: [
            _LocalStat(
                key: const Key('profile_localItems'),
                icon: Icons.inventory_2_outlined,
                label: 'Vật phẩm',
                value: stats.items),
            _LocalStat(
                key: const Key('profile_localProducts'),
                icon: Icons.qr_code_2_rounded,
                label: 'Sản phẩm',
                value: stats.products),
            _LocalStat(
                key: const Key('profile_localPriceHistories'),
                icon: Icons.trending_up_rounded,
                label: 'Lịch sử giá',
                value: stats.priceHistories),
          ],
        ),
      ),
    );
  }
}

class _LocalStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _LocalStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 22, color: context.cs.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$value',
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label,
                style: context.text.bodySmall
                    ?.copyWith(color: context.cs.onSurfaceVariant)),
          ],
        ),
      );
}

// ── 3.1 Khoản định kỳ (M-2 — entry point từ /profile) ────────────────────────

class _RecurringEntrySection extends StatelessWidget {
  const _RecurringEntrySection();

  @override
  Widget build(BuildContext context) => AppCard(
        child: ListTile(
          key: const Key('profile_recurringEntry'),
          contentPadding: EdgeInsets.zero,
          leading:
              Icon(Icons.event_repeat_rounded, color: context.cs.primary),
          title: const Text('Khoản chi định kỳ'),
          subtitle: Text(
            'Khai báo & nhận nhắc trước ngày đến hạn (lưu trên máy này)',
            style: context.text.bodySmall,
          ),
          trailing:
              Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
          onTap: () => context.push('/recurring'),
        ),
      );
}

// ── 4.5 Thông báo (F-#12 AC 12.7) ───────────────────────────────────────────

class _NotificationPrefsSection extends ConsumerWidget {
  const _NotificationPrefsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider).valueOrNull ??
        NotificationPreferences.allEnabled;

    return AppCard(
      key: const Key('profile_notificationSection'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('profile_budgetAlertsToggle'),
            contentPadding: EdgeInsets.zero,
            value: prefs.budgetAlerts,
            onChanged: (enabled) => ref
                .read(notificationPreferencesProvider.notifier)
                .setBudgetAlerts(enabled),
            title: const Text('Budget alerts'),
            subtitle: Text(
              'Nhắc khi chi tiêu chạm ngưỡng ngân sách (lưu trên máy này)',
              style: context.text.bodySmall,
            ),
          ),
          SwitchListTile(
            key: const Key('profile_priceAlertsToggle'),
            contentPadding: EdgeInsets.zero,
            value: prefs.priceAlerts,
            onChanged: (enabled) => ref
                .read(notificationPreferencesProvider.notifier)
                .setPriceAlerts(enabled),
            title: const Text('Price alerts'),
            subtitle: Text(
              'Báo khi món đang theo dõi có mức giá tốt (lưu trên máy này)',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. Export (F-#11) ────────────────────────────────────────────────────────

class _ExportSection extends ConsumerWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastExportProvider);

    return AppCard(
      child: ListTile(
        key: const Key('profile_exportEntry'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.ios_share_rounded, color: context.cs.primary),
        title: const Text('Xuất dữ liệu (CSV / JSON)'),
        subtitle: Text(
          last == null
              ? 'Tải dữ liệu ra file để mở trên máy tính'
              : 'Gần nhất: ${last.filename}',
          style: context.text.bodySmall,
        ),
        trailing:
            Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
        onTap: () => context.push('/export'),
      ),
    );
  }
}

// ── 6. Logout (AC 10.7/10.8) ─────────────────────────────────────────────────

class _LogoutSection extends ConsumerWidget {
  const _LogoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
        child: ListTile(
          key: const Key('profile_logoutEntry'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.logout_rounded, color: context.snap.danger),
          title: Text('Đăng xuất',
              style: context.text.titleSmall
                  ?.copyWith(color: context.snap.danger)),
          onTap: () => confirmAndLogout(context, ref),
        ),
      );
}
