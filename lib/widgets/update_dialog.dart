import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/snap_colors.dart';
import '../models/app_update_model.dart';

/// Dialog "Có bản cập nhật mới" — Phase 4: mọi màu đọc qua token
/// (`context.cs` / `context.snap`) để tự dark; light giữ nguyên hex cũ
/// (tintPrimary == primaryLight, textPrimary/textSecondary/hairline/success
/// trùng đúng giá trị AppColors trước đây — xem snap_colors.dart).
class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;
  final VoidCallback? onDismiss;
  final ValueChanged<String>? onDownload;

  const UpdateDialog({
    super.key,
    required this.info,
    this.onDismiss,
    this.onDownload,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo info,
    VoidCallback? onDismiss,
    ValueChanged<String>? onDownload,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(
        info: info,
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss?.call();
        },
        onDownload: (url) {
          Navigator.of(ctx).pop();
          onDownload?.call(url);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon & Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.tintPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🚀', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Có bản cập nhật mới!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'v${info.currentVersion}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: colors.textSecondary),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${info.latestVersion}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: 14),

            // Release Title & Notes
            if (info.releaseTitle.isNotEmpty) ...[
              Text(
                info.releaseTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (info.releaseNotes.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Nền khối notes = màu nền app (light #F7F8FC đúng hex cũ,
                  // dark thành inset tối trên surface).
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.hairline),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ] else ...[
              Text(
                'Bản cập nhật bao gồm các cải tiến hiệu năng và sửa lỗi quan trọng.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextButton(
                    onPressed: () {
                      if (onDismiss != null) {
                        onDismiss!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Để sau',
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final url = info.releasePageUrl ??
                          (info.latestVersion.isNotEmpty
                              ? 'https://github.com/${AppConstants.githubRepo}/releases/tag/v${info.latestVersion}'
                              : 'https://github.com/${AppConstants.githubRepo}/releases');
                      if (onDownload != null) {
                        onDownload!(url);
                      }
                    },
                    // onPrimary: light = trắng (giữ nguyên), dark = chữ tối
                    // trên primary #8B85FF — đủ contrast cả 2 mode.
                    icon: Icon(Icons.open_in_new_rounded,
                        size: 18, color: context.cs.onPrimary),
                    label: Text(
                      'Cập nhật ngay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.cs.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.cs.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
