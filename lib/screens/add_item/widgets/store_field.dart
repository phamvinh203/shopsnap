import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../widgets/ui/app_text_field.dart';

/// M-3 (AC 7.3–7.5) — Field "Nơi mua" (TUỲ CHỌN) khi thêm mặt hàng:
///
/// - TextField nhập tự do: giá trị mới chưa từng có vẫn lưu nguyên văn,
///   không chặn không tự sửa; khoảng trắng 2 đầu được trim khi lưu (AC 7.5).
/// - Suggestion chips theo TẦN SUẤT giảm dần từ dữ liệu local (caller query
///   `ItemDao.getStoreSuggestions` — nguyên văn user đã dùng, tối đa 10 —
///   AC 7.4); tap chip → điền đúng nguyên văn giá trị đó (AC 7.5).
/// - Bỏ trống → item KHÔNG có store_name (AC 7.3, caller sanitize rỗng → null).
/// - Tách widget riêng (không giữ state) để widget test trực tiếp không cần
///   dựng cả màn thêm item; style tokens Ink Ledger, không thêm token mới.
class StoreFieldSuggestions extends StatelessWidget {
  final TextEditingController controller;

  /// Gợi ý đã xếp theo tần suất giảm dần (từ SQLite local — chạy offline).
  final List<String> suggestions;
  final ValueChanged<String>? onChanged;

  const StoreFieldSuggestions({
    super.key,
    required this.controller,
    this.suggestions = const [],
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          key: const Key('addItem_storeField'),
          controller: controller,
          label: 'Nơi mua (tuỳ chọn)',
          hint: 'VD: CoopMart, Bách Hóa Xanh...',
          prefixIcon: Icons.storefront_outlined,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.sentences,
        ),

        // Chips gợi ý theo tần suất — ẩn khi không có dữ liệu local.
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            key: const Key('addItem_storeSuggestions'),
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < suggestions.length; i++)
                InkWell(
                  key: Key('addItem_storeChip_$i'),
                  onTap: () {
                    controller.text = suggestions[i]; // nguyên văn (AC 7.5)
                    // Đưa con trỏ về cuối để user gõ tiếp ngay.
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                    onChanged?.call(suggestions[i]);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: controller.text == suggestions[i]
                          ? colors.tintPrimary
                          : context.cs.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: controller.text == suggestions[i]
                            ? colors.onTintPrimary
                            : colors.hairline,
                      ),
                    ),
                    child: Text(
                      suggestions[i],
                      style: context.text.labelLarge?.copyWith(
                        fontSize: 12,
                        color: controller.text == suggestions[i]
                            ? colors.onTintPrimary
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
