import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/app_typography.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/core/utils/receipt_auto_match.dart';
import 'package:shopsnap/core/utils/receipt_duplicate.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/services/ocr_service.dart';

/// F-#5 P1 / M-1 — một dòng ở màn CONFIRM hóa đơn: state UI do màn chủ
/// (ocr review) sở hữu, widget này chỉ render + bắn sự kiện chỉnh sửa về.
///
/// - [item]: tên/giá/category hiện tại (editable inline — AC 5.1).
/// - [categoryLocked]: user đã TỰ chọn category → không auto-đổi theo tên nữa.
/// - [keepAnyway]: checkbox "vẫn thêm" — p1: khi dòng trùng (AC 5.3/5.4,
///   mặc định KHÔNG tick); M-1: dòng auto-match tự tick sẵn (AC 5.15), user
///   bỏ tick được (AC 5.21).
/// - [duplicate]: match trùng hiện tại (recompute real-time khi edit — AC 5.5).
/// - [autoMatch]: match "chắc chắn" với sổ giá local (M-1 — AC 5.15/5.16);
///   null → dòng đi luồng uncertain p1 (AC 5.19).
/// - [reviewed]: user ĐÃ tương tác dòng (sửa tên/giá/category hoặc tự thao tác
///   checkbox — AC 5.22/5.23); auto-tick của matcher KHÔNG tính.
/// - [failedReason]: lý do dòng thất bại ở lần bulk gần nhất (AC 5.7).
class OcrConfirmLine {
  final String uid;
  final OcrItem item;
  final bool categoryLocked;
  final bool keepAnyway;
  final ReceiptDuplicateMatch? duplicate;
  final AutoMatchResult? autoMatch;
  final bool reviewed;
  final String? failedReason;

  const OcrConfirmLine({
    required this.uid,
    required this.item,
    this.categoryLocked = false,
    this.keepAnyway = false,
    this.duplicate,
    this.autoMatch,
    this.reviewed = false,
    this.failedReason,
  });

  OcrConfirmLine copyWith({
    OcrItem? item,
    bool? categoryLocked,
    bool? keepAnyway,
    ReceiptDuplicateMatch? duplicate,
    AutoMatchResult? autoMatch,
    String? failedReason,
    bool? reviewed,
    bool clearDuplicate = false,
    bool clearAutoMatch = false,
    bool clearFailedReason = false,
  }) =>
      OcrConfirmLine(
        uid: uid,
        item: item ?? this.item,
        categoryLocked: categoryLocked ?? this.categoryLocked,
        keepAnyway: keepAnyway ?? this.keepAnyway,
        duplicate: clearDuplicate ? null : (duplicate ?? this.duplicate),
        autoMatch: clearAutoMatch ? null : (autoMatch ?? this.autoMatch),
        reviewed: reviewed ?? this.reviewed,
        failedReason:
            clearFailedReason ? null : (failedReason ?? this.failedReason),
      );

  /// Dòng hợp lệ để đưa vào batch: có tên + giá, và (không trùng HOẶC đã tick
  /// "vẫn thêm") — AC 5.4/5.12; M-1: dòng auto-match cũng phải đang được tick
  /// mới vào batch (bỏ tick = loại khỏi batch ngay — AC 5.21).
  bool get isSubmittable =>
      item.name.trim().isNotEmpty &&
      item.price > 0 &&
      (duplicate == null || keepAnyway) &&
      (autoMatch == null || keepAnyway);
}

/// Thay đổi trên một dòng — các field null = giữ nguyên.
class OcrLineEdit {
  final String? name;
  final int? price;
  final String? categoryId;
  final bool? categoryLocked;
  final bool? keepAnyway;

  const OcrLineEdit({
    this.name,
    this.price,
    this.categoryId,
    this.categoryLocked,
    this.keepAnyway,
  });
}

typedef OcrLineEditCallback = void Function(String uid, OcrLineEdit edit);
typedef OcrLineRemoveCallback = void Function(String uid);

/// Danh sách dòng hóa đơn ở chế độ CONFIRM (F-#5 P1): tên + giá editable,
/// dropdown category (mặc định = gợi ý của classifier, user đổi được),
/// badge cảnh báo trùng + checkbox "vẫn thêm", recompute real-time khi edit.
class OcrResultList extends StatelessWidget {
  final List<OcrConfirmLine> lines;

  /// Danh mục cho dropdown — rỗng → dùng bộ default seed của app.
  final List<CategoryModel> categories;
  final OcrLineEditCallback onEdit;
  final OcrLineRemoveCallback onRemove;
  final VoidCallback onAdd;

  const OcrResultList({
    required this.lines,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    this.categories = const [],
    super.key,
  });

  static const _defaultCategories = <CategoryModel>[
    CategoryModel(id: 'cat_food', name: 'Ăn uống', icon: '🍜', color: '#FF6B6B', isDefault: true, sortOrder: 1, createdAt: 0),
    CategoryModel(id: 'cat_clothes', name: 'Quần áo', icon: '👕', color: '#4ECDC4', isDefault: true, sortOrder: 2, createdAt: 0),
    CategoryModel(id: 'cat_souvenir', name: 'Đồ lưu niệm', icon: '🎁', color: '#45B7D1', isDefault: true, sortOrder: 3, createdAt: 0),
    CategoryModel(id: 'cat_tech', name: 'Điện tử', icon: '📱', color: '#96CEB4', isDefault: true, sortOrder: 4, createdAt: 0),
    CategoryModel(id: 'cat_personal', name: 'Chăm sóc cá nhân', icon: '🧴', color: '#FFEAA7', isDefault: true, sortOrder: 5, createdAt: 0),
    CategoryModel(id: 'cat_other', name: 'Khác', icon: '📦', color: '#DDA0DD', isDefault: true, sortOrder: 6, createdAt: 0),
  ];

  @override
  Widget build(BuildContext context) {
    final cats = categories.isEmpty ? _defaultCategories : categories;
    return Column(children: [
      ...List.generate(lines.length, (i) => _ItemRow(
        key: ValueKey(lines[i].uid),
        line:     lines[i],
        index:    i,
        categories: cats,
        onEdit:   onEdit,
        onRemove: onRemove,
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
            onTap: onAdd,
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
  final OcrConfirmLine line;
  final int index;
  final List<CategoryModel> categories;
  final OcrLineEditCallback onEdit;
  final OcrLineRemoveCallback onRemove;

  const _ItemRow({
    required this.line,
    required this.index,
    required this.categories,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.line.item.name);
    _priceCtrl = TextEditingController(
        text: widget.line.item.price > 0 ? widget.line.item.price.toString() : '');
  }

  @override
  void didUpdateWidget(covariant _ItemRow old) {
    super.didUpdateWidget(old);
    // Dòng được parent cập nhật từ ngoài (vd. gợi ý category đổi theo tên) —
    // sync controller nếu text khác (edit của chính row echo về là giống nhau
    // nên không nhảy con trỏ).
    final item = widget.line.item;
    if (_nameCtrl.text != item.name) _nameCtrl.text = item.name;
    final priceText = item.price > 0 ? item.price.toString() : '';
    if (_priceCtrl.text != priceText) _priceCtrl.text = priceText;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final line  = widget.line;
    final item  = line.item;
    final needsReview = item.needsReview;
    final isDuplicate = line.duplicate != null;
    // Row trùng: viền/tint warning (cùng họ với needsReview) để nổi bật.
    final highlighted = needsReview || isDuplicate || line.failedReason != null;

    // Category hiển thị: giá trị hiện tại phải nằm trong danh sách dropdown,
    // không thì hiện hint (giữ nguyên categoryId trong state để submit).
    final categoryValue =
        widget.categories.any((c) => c.id == item.categoryId)
            ? item.categoryId
            : null;

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
        color: highlighted ? colors.warning.withOpacity(0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          bottom: BorderSide(
            color: highlighted
                ? colors.warning.withOpacity(0.4)
                : colors.hairline,
          ),
        ),
      ),
      child: Column(children: [
        Row(children: [
          // Index badge — số Space Grotesk (moneyOf)
          Container(
            width: 24, height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted
                  ? colors.warning.withOpacity(0.2)
                  : colors.tintPrimary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${widget.index + 1}',
              style: AppTypography.moneyOf(
                context.text,
                size: 11,
                color: highlighted ? colors.warning : colors.onTintPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md - 2),
          // Name field (AC 5.1 — editable)
          Expanded(
            flex: 3,
            child: TextField(
              key: Key('ocrConfirm_name_${line.uid}'),
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
                border: UnderlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                hintText: 'Tên sản phẩm',
              ),
              onChanged: (v) => widget.onEdit(line.uid, OcrLineEdit(name: v)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Price field — số Space Grotesk (AC 5.1 — editable, numeric)
          Expanded(
            flex: 2,
            child: TextField(
              key: Key('ocrConfirm_price_${line.uid}'),
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
              onChanged: (v) =>
                  widget.onEdit(line.uid, OcrLineEdit(price: int.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          // Delete — giữ Icons.close (test find.byIcon(Icons.close)).
          GestureDetector(
            onTap: () => widget.onRemove(line.uid),
            child: Icon(Icons.close, size: 18, color: context.cs.onSurfaceVariant),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        // Hàng phụ: dropdown category (AC 5.1/5.2) + badge trùng/checkbox
        // (AC 5.3/5.4) + badge lỗi bulk (AC 5.7).
        Row(children: [
          const SizedBox(width: 24 + AppSpacing.md - 2),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: Key('ocrConfirm_category_${line.uid}'),
              value: categoryValue,
              isDense: true,
              style: context.text.bodySmall,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
                border: UnderlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2))),
                hintText: 'Chọn danh mục',
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(
                          '${c.icon}  ${c.name}',
                          style: context.text.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => v == null
                  ? null
                  : widget.onEdit(line.uid, OcrLineEdit(
                      categoryId: v,
                      categoryLocked: true, // user chủ động chọn (AC 5.2)
                    )),
            ),
          ),
        ]),
        // M-1 (AC 5.15/5.21) — badge "Tự khớp: <tên record>" + checkbox tick
        // sẵn. Badge giữ nguyên KỂ KHI user bỏ tick (user hiểu vì sao dòng
        // từng được tự tick — AC 5.21); recompute real-time khi edit nên
        // badge tự biến mất khi match không còn (AC 5.22).
        if (line.autoMatch != null && !isDuplicate) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Container(
            key: Key('ocrConfirm_autoBadge_${line.uid}'),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome, size: 14, color: colors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tự khớp: "${line.autoMatch!.matchedName}"',
                  style: context.text.bodySmall
                      ?.copyWith(color: colors.success, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 26,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 18, width: 18,
                    child: Checkbox(
                      key: Key('ocrConfirm_keep_${line.uid}'),
                      value: line.keepAnyway,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      activeColor: colors.success,
                      onChanged: (v) => widget.onEdit(line.uid, OcrLineEdit(
                        keepAnyway: v ?? false, // AC 5.21 — bỏ tick được, không dialog
                      )),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Vẫn thêm',
                      style: context.text.labelSmall
                          ?.copyWith(color: colors.success, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ],
        if (isDuplicate) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Container(
            key: Key('ocrConfirm_dupBadge_${line.uid}'),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(Icons.copy_all_outlined, size: 14, color: colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  // AC 5.3 — "Có thể trùng với <tên item> ngày X".
                  'Có thể trùng với "${line.duplicate!.matchedName}" '
                  'ngày ${line.duplicate!.purchasedAt.day}/${line.duplicate!.purchasedAt.month}',
                  style: context.text.bodySmall
                      ?.copyWith(color: colors.warning, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 26,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 18, width: 18,
                    child: Checkbox(
                      key: Key('ocrConfirm_keep_${line.uid}'),
                      value: line.keepAnyway,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      activeColor: colors.warning,
                      onChanged: (v) => widget.onEdit(line.uid, OcrLineEdit(
                        keepAnyway: v ?? false, // AC 5.4 — mặc định KHÔNG tick
                      )),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Vẫn thêm',
                      style: context.text.labelSmall
                          ?.copyWith(color: colors.warning, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ],
        if (line.failedReason != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Container(
            key: Key('ocrConfirm_failBadge_${line.uid}'),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.danger.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, size: 14, color: colors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Chưa lưu được: ${line.failedReason}',
                  style: context.text.bodySmall
                      ?.copyWith(color: colors.danger, fontSize: 11),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
