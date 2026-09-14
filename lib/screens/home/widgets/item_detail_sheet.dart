import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/api_error_messages.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_model.dart';
import '../../../models/item_model.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/items_provider.dart';
import '../../../widgets/ui/app_bottom_sheet.dart';
import '../../../widgets/ui/app_button.dart';
import '../../../widgets/ui/app_text_field.dart';
import '../../../widgets/ui/confirm_dialog.dart';

/// Bottom-sheet XEM CHI TIẾT + SỬA NHANH mặt hàng (PO chốt ở biên bản 00:
/// làm bottom-sheet sửa nhanh trước, màn Item Detail đầy đủ ở phase sau).
///
/// Sửa được: tên, giá, danh mục — CHỈ gọi method CÓ SẴN của `itemsProvider`
/// (`updateItem`, `deleteItem` — offline-first, không thêm logic mới).
///
/// ⚠️ Số lượng (`ItemModel.quantity`) CHỈ hiển thị để xem: `updateItem` chưa
/// nhận param quantity (backend có, sqflite/DAO chưa có cột) — cần BE/provider
/// bổ sung trước khi cho sửa (ghi nhận trong báo cáo Phase 3a).
class ItemDetailSheet extends ConsumerStatefulWidget {
  final ItemModel item;

  const ItemDetailSheet({super.key, required this.item});

  /// Entry point từ Home: tap ItemCard → mở sheet sửa nhanh.
  static Future<void> show(BuildContext context, ItemModel item) {
    return AppBottomSheet.show(
      context: context,
      title: 'Sửa nhanh mặt hàng',
      builder: (_) => ItemDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late String? _categoryId;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(
      text: widget.item.price > 0 ? '${widget.item.price}' : '',
    );
    _categoryId = widget.item.categoryId.isEmpty ? null : widget.item.categoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  /// Danh sách option cho dropdown — luôn bảo đảm category hiện tại của item
  /// có mặt (category sync chưa xong / lỗi thì vẫn chọn được lựa chọn cũ).
  List<CategoryModel> _categoryOptions(List<CategoryModel> cats) {
    final options = [...cats];
    final currentId = widget.item.categoryId;
    if (currentId.isNotEmpty && !options.any((c) => c.id == currentId)) {
      options.insert(
        0,
        CategoryModel(
          id: currentId,
          name: widget.item.categoryName.isEmpty
              ? 'Danh mục hiện tại'
              : widget.item.categoryName,
          icon: widget.item.categoryIcon,
          color: widget.item.categoryColor,
          isDefault: false,
          sortOrder: -1,
          createdAt: 0,
        ),
      );
    }
    return options;
  }

  bool get _hasChange =>
      _nameCtrl.text.trim() != widget.item.name ||
      CurrencyFormatter.parse(_priceCtrl.text) != widget.item.price ||
      _categoryId != widget.item.categoryId;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = CurrencyFormatter.parse(_priceCtrl.text);

    if (name.isEmpty) {
      setState(() => _error = 'Tên mặt hàng không được để trống.');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Giá tiền phải lớn hơn 0.');
      return;
    }
    if (!_hasChange) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(itemsProvider.notifier).updateItem(
            widget.item.id,
            name: name != widget.item.name ? name : null,
            price: price != widget.item.price ? price : null,
            categoryId: _categoryId != widget.item.categoryId ? _categoryId : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop(); // Home tự cập nhật theo itemsProvider
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Xoá mặt hàng?',
      message: 'Bạn có chắc muốn xoá "${widget.item.name}" không?',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(itemsProvider.notifier).deleteItem(widget.item.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final options = _categoryOptions(catsAsync.valueOrNull ?? const []);
    final item = widget.item;

    return Column(
      key: const Key('itemDetailSheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Info: số lượng (chỉ xem — chưa sửa được, xem ghi chú class) ─────
        if (item.quantity != null) ...[
          Row(
            key: const Key('itemDetailSheet_quantity'),
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 14, color: context.cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text('Số lượng: ${item.quantity}', style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Form sửa nhanh ──────────────────────────────────────────────────
        AppTextField(
          key: const Key('itemDetailSheet_nameField'),
          controller: _nameCtrl,
          label: 'Tên mặt hàng',
          prefixIcon: Icons.shopping_bag_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('itemDetailSheet_priceField'),
          controller: _priceCtrl,
          label: 'Giá (VNĐ)',
          prefixIcon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
          // Chặn ký tự không phải số ngay từ input (paste "1abc0" → "10"),
          // không dựa vào CurrencyFormatter.parse lọc im lặng (bug QA M2).
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          key: const Key('itemDetailSheet_categoryField'),
          value: _categoryId,
          hint: const Text('Chọn danh mục'),
          decoration: const InputDecoration(labelText: 'Danh mục'),
          items: [
            for (final cat in options)
              DropdownMenuItem(
                value: cat.id,
                child: Text('${cat.icon}  ${cat.name}'),
              ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            key: const Key('itemDetailSheet_error'),
            style: context.text.bodySmall?.copyWith(color: context.snap.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          key: const Key('itemDetailSheet_saveButton'),
          label: 'Lưu thay đổi',
          loading: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          key: const Key('itemDetailSheet_deleteButton'),
          label: 'Xoá mặt hàng',
          danger: true,
          onPressed: _deleting ? null : _delete,
        ),
      ],
    );
  }
}
