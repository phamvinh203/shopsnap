import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import 'app_button.dart';

/// State rỗng chuẩn hoá — thay Column emoji thủ công ở home/summary.
///
/// Action tuỳ chọn: truyền cặp [actionLabel] + [onAction] để hiện CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('emptyState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.snap.tintPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: context.cs.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            key: const Key('emptyState_title'),
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              key: const Key('emptyState_message'),
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('emptyState_action'),
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// State lỗi chuẩn hoá — thay `Text('Lỗi: $e')` rải rác.
///
/// BẮT BUỘC có nút "Thử lại" gắn [onRetry] (QA checklist mục 5.1.3).
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message = 'Đã có lỗi xảy ra. Vui lòng thử lại.',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Center(
      key: const Key('errorState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.danger.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.error_outline_rounded, size: 40, color: colors.danger),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            key: const Key('errorState_message'),
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            key: const Key('errorState_retry'),
            label: 'Thử lại',
            onPressed: onRetry,
            expand: false,
          ),
        ],
      ),
    );
  }
}
