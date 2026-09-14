import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/services/ocr_service.dart';

class OcrResultList extends StatefulWidget {
  final List<OcrItem>          initialItems;
  final ValueChanged<List<OcrItem>> onChanged;

  const OcrResultList({required this.initialItems, required this.onChanged, super.key});
  @override
  State<OcrResultList> createState() => _OcrResultListState();
}

class _OcrResultListState extends State<OcrResultList> {
  late List<OcrItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  void _update(int idx, OcrItem item) {
    setState(() => _items[idx] = item);
    widget.onChanged(_items);
  }

  void _remove(int idx) {
    setState(() => _items.removeAt(idx));
    widget.onChanged(_items);
  }

  void _add() {
    setState(() => _items.add(OcrItem(name: '', price: 0, categoryId: 'cat_other', needsReview: true)));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ...List.generate(_items.length, (i) => _ItemRow(
        item:     _items[i],
        index:    i,
        onUpdate: (item) => _update(i, item),
        onRemove: () => _remove(i),
      )),
      // Add row button — InkWell thay GestureDetector trần (ripple + semantics),
      // touch target ≥ 48dp.
      Padding(
        // Margin ngoài InkWell để ripple không tràn vào khoảng cách.
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Material(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            key: const Key('ocrResultList_addButton'),
            onTap: _add,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: context.snap.hairline),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, size: 16, color: context.cs.primary),
                const SizedBox(width: AppSpacing.xs),
                // Glossary R14: "Thêm mặt hàng" thay "Thêm item".
                Text('Thêm mặt hàng',
                    style: context.text.labelLarge
                        ?.copyWith(color: context.cs.primary, fontSize: 13)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ItemRow extends StatefulWidget {
  final OcrItem  item;
  final int      index;
  final ValueChanged<OcrItem> onUpdate;
  final VoidCallback onRemove;

  const _ItemRow({required this.item, required this.index, required this.onUpdate, required this.onRemove});
  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(text: widget.item.price > 0 ? widget.item.price.toString() : '');
  }

  @override
  void dispose() { _nameCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final needsReview = widget.item.needsReview;
    // Giữ cấu trúc Container + Text (ocr_result_list_test phụ thuộc);
    // màu chuyển sang token: warning tint khi needsReview, surface + hairline
    // khi thường.
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: needsReview ? colors.warning.withOpacity(0.06) : context.cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: needsReview ? colors.warning.withOpacity(0.4) : colors.hairline,
        ),
      ),
      child: Row(children: [
        // Index badge
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: needsReview
                ? colors.warning.withOpacity(0.2)
                : colors.tintPrimary,
            shape: BoxShape.circle,
          ),
          child: Text('${widget.index + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: needsReview ? colors.warning : context.cs.primary)),
        ),
        const SizedBox(width: AppSpacing.md - 2),
        // Name field
        Expanded(
          flex: 3,
          child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm))),
              hintText: 'Tên sản phẩm',
            ),
            onChanged: (v) => widget.onUpdate(widget.item.copyWith(name: v)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Price field
        Expanded(
          flex: 2,
          child: TextField(
            controller: _priceCtrl,
            style: const TextStyle(fontSize: 13),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm))),
              hintText: 'Giá',
              suffixText: 'đ',
            ),
            onChanged: (v) => widget.onUpdate(widget.item.copyWith(price: int.tryParse(v) ?? 0)),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        // Delete — giữ Icons.close (test find.byIcon(Icons.close)).
        GestureDetector(
          onTap: widget.onRemove,
          child: Icon(Icons.close, size: 18, color: context.cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}
