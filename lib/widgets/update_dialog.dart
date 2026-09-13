import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/app_update_model.dart';

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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.bgCard,
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
                    color: AppColors.primaryLight,
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
                      const Text(
                        'Có bản cập nhật mới!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'v${info.currentVersion}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${info.latestVersion}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
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
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 14),

            // Release Title & Notes
            if (info.releaseTitle.isNotEmpty) ...[
              Text(
                info.releaseTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (info.releaseNotes.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgMain,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ] else ...[
              const Text(
                'Bản cập nhật bao gồm các cải tiến hiệu năng và sửa lỗi quan trọng.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                    child: const Text(
                      'Để sau',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
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
                      final url = info.downloadUrl ?? info.releasePageUrl;
                      if (url != null && onDownload != null) {
                        onDownload!(url);
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Cập nhật ngay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
