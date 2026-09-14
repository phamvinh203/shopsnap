import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/app_typography.dart';
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
      // Add row button — "khối mực" radius 6 (4.6): giữ cấu trúc
      // Material/InkWell/Container/Text + key mà test khoá.
      Padding(
        // Margin ngoài InkWell để ripple không tràn vào khoảng cách.
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Material(
          color: context.cs.onSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            key: const Key('ocrResultList_addButton'),
            onTap: _add,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, size: 16, color: context.cs.surface),
                const SizedBox(width: AppSpacing.xs),
                // Glossary R14: "Thêm mặt hàng" thay "Thêm item".
                Text('Thêm mặt hàng',
                    style: context.text.labelLarge
                        ?.copyWith(color: context.cs.surface, fontSize: 13)),
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
    // "Rows kẻ dòng" (4.6): row thường = đường kẻ hairline DƯỚI (như sổ),
    // không còn hộp bo; row cần soát lại giữ cơ chế warning tint + viền.
    // Cấu trúc Container + Text giữ nguyên (ocr_result_list_test phụ thuộc).
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: needsReview ? colors.warning.withOpacity(0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          bottom: BorderSide(
            color: needsReview
                ? colors.warning.withOpacity(0.4)
                : colors.hairline,
          ),
        ),
      ),
      child: Row(children: [
        // Index badge — số Space Grotesk (moneyOf)
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: needsReview
                ? colors.warning.withOpacity(0.2)
                : colors.tintPrimary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '${widget.index + 1}',
            style: AppTypography.moneyOf(
              context.text,
              size: 11,
              color: needsReview ? colors.warning : colors.onTintPrimary,
            ),
          ),
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
              border: UnderlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
              hintText: 'Tên sản phẩm',
            ),
            onChanged: (v) => widget.onUpdate(widget.item.copyWith(name: v)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Price field — số Space Grotesk
        Expanded(
          flex: 2,
          child: TextField(
            controller: _priceCtrl,
            style: AppTypography.moneyOf(context.text, size: 13),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              border: UnderlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
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
