import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import 'app_button.dart';

/// State rỗng chuẩn hoá — "vòng tròn kẻ đứt nét + tiêu đề serif italic"
/// (giọng tạp chí của Ink Ledger).
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
    final ink = context.snap.textPrimary;
    return Center(
      key: const Key('emptyState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: _DashedCirclePainter(
                color: context.snap.hairline,
                strokeWidth: 1.2,
              ),
              child: Center(
                child: Icon(icon, size: 40, color: ink.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            key: const Key('emptyState_title'),
            style: GoogleFonts.fraunces(
              textStyle: context.text.titleMedium,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: ink,
            ),
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

/// Vòng tròn viền đứt nét — tự viết ~20 dòng (KHÔNG thêm package, không
/// cần path_utils: chia đường tròn thành các cung ngắn).
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  static const int _dashCount = 28;
  static const double _dashToGapRatio = 0.55;

  const _DashedCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    const sweep = (2 * 3.1415926535897932) / _dashCount;
    for (var i = 0; i < _dashCount; i++) {
      canvas.drawArc(inset, i * sweep, sweep * _dashToGapRatio, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// State lỗi chuẩn hoá — cùng ngôn ngữ EmptyState, icon danger.
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
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: _DashedCirclePainter(
                color: colors.danger.withOpacity(0.4),
                strokeWidth: 1.2,
              ),
              child: Center(
                child: Icon(Icons.error_outline_rounded,
                    size: 40, color: colors.danger),
              ),
            ),
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
