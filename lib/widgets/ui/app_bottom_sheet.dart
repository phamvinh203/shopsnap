import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Bottom sheet chuẩn hoá — handle bar + top radius 24 + padding đuỗi đúng
/// keyboard inset (form trong sheet không bị bàn phím che).
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isScrollControlled = true,
  }) {
    final colors = context.snap;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      backgroundColor: context.cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        // Clip để top rule hairline chạy theo góc bo của sheet ("kẻ dòng thay
        // bóng đổ" — INK LEDGER 3.10).
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top rule hairline thay shadow.
            Container(height: 1, color: colors.hairline),
            Container(
              key: const Key('appBottomSheet_handle'),
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                // Handle = mực @20% thay hairline.
                color: context.cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  title,
                  key: const Key('appBottomSheet_title'),
                  style: sheetContext.text.titleMedium,
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: builder(sheetContext),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
