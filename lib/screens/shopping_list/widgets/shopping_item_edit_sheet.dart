import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_model.dart';
import '../../../models/shopping_list_item_model.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/shopping_list_provider.dart';
import '../../../widgets/ui/app_bottom_sheet.dart';
import '../../../widgets/ui/app_button.dart';
import '../../../widgets/ui/app_text_field.dart';

/// Sheet chỉnh tác một món trong list (F-#6 AC 6.6): số lượng, giá dự kiến,
/// danh mục — TẤT CẢ tuỳ chọn, bỏ trống được (bỏ trống = xoá giá trị cũ).
class ShoppingItemEditSheet extends ConsumerStatefulWidget {
  final ShoppingListItem item;

  const ShoppingItemEditSheet({super.key, required this.item});

  /// Entry từ tile: tap vào thân dòng (không phải checkbox) — AC 6.6.
  static Future<void> show(BuildContext context, ShoppingListItem item) {
    return AppBottomSheet.show(
      context: context,
      title: 'Sửa món trong danh sách',
      builder: (_) => ShoppingItemEditSheet(item: item),
    );
  }

  @override
  ConsumerState<ShoppingItemEditSheet> createState() =>
      _ShoppingItemEditSheetState();
}

class _ShoppingItemEditSheetState extends ConsumerState<ShoppingItemEditSheet> {
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _priceCtrl;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(
      text: widget.item.quantity?.toString() ?? '',
    );
    _priceCtrl = TextEditingController(
      text: widget.item.expectedPrice != null
          ? '${widget.item.expectedPrice}'
          : '',
    );
    _categoryId = widget.item.categoryId;
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final quantityText = _quantityCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();

    await ref.read(shoppingListProvider.notifier).updateDetails(
          widget.item.id,
          quantity: quantityText.isEmpty ? null : int.tryParse(quantityText),
          expectedPrice:
              priceText.isEmpty ? null : CurrencyFormatter.parse(priceText),
          clearQuantity: quantityText.isEmpty,
          clearExpectedPrice: priceText.isEmpty,
          categoryId: _categoryId,
          clearCategoryId: _categoryId == null,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final options = _categoryOptions(catsAsync.valueOrNull ?? const []);

    return Column(
      key: const Key('shoppingItemEditSheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.item.name,
          key: const Key('shoppingItemEditSheet_name'),
          style: context.text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          key: const Key('shoppingItemEditSheet_quantityField'),
          controller: _quantityCtrl,
          label: 'Số lượng (tuỳ chọn)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('shoppingItemEditSheet_priceField'),
          controller: _priceCtrl,
          label: 'Giá dự kiến (VNĐ, tuỳ chọn)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          key: const Key('shoppingItemEditSheet_categoryField'),
          value: _categoryId,
          hint: const Text('Chọn danh mục (tuỳ chọn)'),
          decoration: const InputDecoration(labelText: 'Danh mục'),
          items: [
            for (final cat in options)
              DropdownMenuItem(value: cat.id, child: Text('${cat.icon}  ${cat.name}')),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: GhostButton(
            key: const Key('shoppingItemEditSheet_clearCategory'),
            label: 'Bỏ chọn danh mục',
            onPressed: () => setState(() => _categoryId = null),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const Key('shoppingItemEditSheet_saveButton'),
          label: 'Lưu',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  /// Bảo đảm category hiện tại của món có mặt trong dropdown (category sync
  /// chưa xong thì vẫn hiển thị lựa chọn cũ) — cùng cách ItemDetailSheet làm.
  List<CategoryModel> _categoryOptions(List<CategoryModel> cats) {
    final options = [...cats];
    final currentId = widget.item.categoryId;
    if (currentId != null &&
        currentId.isNotEmpty &&
        !options.any((c) => c.id == currentId)) {
      options.insert(
        0,
        CategoryModel(
          id: currentId,
          name: 'Danh mục hiện tại',
          icon: '📦',
          color: '#DDA0DD',
          isDefault: false,
          sortOrder: -1,
          createdAt: 0,
        ),
      );
    }
    return options;
  }
}
