import 'package:flutter/material.dart';

import '../../core/theme/snap_colors.dart';
import 'app_button.dart';

/// Dialog xác nhận chuẩn hoá — thay 3 AlertDialog copy-paste (xoá item,
/// đăng xuất, duplicate).
///
/// ⚠️ KHÔNG đổi label do caller truyền (VD "Xóa vật phẩm?", "Huỷ") — widget
/// test hiện có find theo text. Chuỗi nằm ở caller, không hardcode tại đây.
class ConfirmDialog {
  ConfirmDialog._();

  /// Trả về `true` nếu người dùng xác nhận, `false` nếu huỷ/dismiss.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Huỷ',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.snap;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            GhostButton(
              key: const Key('confirmDialog_cancel'),
              label: cancelLabel,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            if (destructive)
              FilledButton(
                key: const Key('confirmDialog_confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: dialogContext.cs.onPrimary,
                ),
                child: Text(confirmLabel),
              )
            else
              PrimaryButton(
                key: const Key('confirmDialog_confirm'),
                label: confirmLabel,
                expand: false,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
