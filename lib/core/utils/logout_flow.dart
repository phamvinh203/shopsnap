import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/ui/confirm_dialog.dart';

/// Luồng đăng xuất dùng chung cho settings sheet (MainShell) và /profile
/// (F-#10) — giữ đúng 1 chỗ để 2 entry không lệch hành vi.
///
/// AC 10.7: confirm dialog trước khi xoá token local.
/// AC 10.8: còn pending changes (G2 — sync chưa persist bền vững) → dialog
/// cảnh báo mất dữ liệu + yêu cầu xác nhận LẦN NỮA trước khi thực sự đăng xuất.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await ConfirmDialog.show(
    context: context,
    title: 'Đăng xuất',
    message: 'Bạn chắc chắn muốn đăng xuất khỏi ShopSnap?',
    confirmLabel: 'Đăng xuất',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final pending = ref.read(syncProvider).pendingCount;
  if (pending > 0) {
    final confirmedAgain = await ConfirmDialog.show(
      context: context,
      title: 'Còn thay đổi chưa đồng bộ',
      message: 'Bạn có $pending thay đổi chưa được đẩy lên máy chủ. '
          'Đăng xuất lúc này có thể làm mất các thay đổi này khỏi thiết bị. '
          'Vẫn đăng xuất?',
      confirmLabel: 'Vẫn đăng xuất',
      destructive: true,
    );
    if (!confirmedAgain) return;
  }

  await ref.read(authStateProvider.notifier).logout();
  // Auth gate mềm (PO chốt 2026-09-14): user ở lại màn đang đứng — banner
  // đăng nhập và trạng thái "chưa đăng nhập" của /profile tự cập nhật.
}
