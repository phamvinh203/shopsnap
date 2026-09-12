import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopsnap/core/theme/app_colors.dart';
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
      // Add row button
      GestureDetector(
        onTap: _add,
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add, size: 16, color: AppColors.primary),
            SizedBox(width: 4),
            Text('Thêm item', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
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
    final needsReview = widget.item.needsReview;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: needsReview ? AppColors.warning.withOpacity(0.06) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsReview ? AppColors.warning.withOpacity(0.4) : AppColors.divider,
        ),
      ),
      child: Row(children: [
        // Index badge
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: needsReview ? AppColors.warning.withOpacity(0.2) : AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Text('${widget.index + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: needsReview ? AppColors.warning : AppColors.primary)),
        ),
        const SizedBox(width: 10),
        // Name field
        Expanded(
          flex: 3,
          child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              hintText: 'Tên sản phẩm',
            ),
            onChanged: (v) => widget.onUpdate(widget.item.copyWith(name: v)),
          ),
        ),
        const SizedBox(width: 8),
        // Price field
        Expanded(
          flex: 2,
          child: TextField(
            controller: _priceCtrl,
            style: const TextStyle(fontSize: 13),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              hintText: 'Giá',
              suffixText: 'đ',
            ),
            onChanged: (v) => widget.onUpdate(widget.item.copyWith(price: int.tryParse(v) ?? 0)),
          ),
        ),
        const SizedBox(width: 6),
        // Delete
        GestureDetector(
          onTap: widget.onRemove,
          child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}
