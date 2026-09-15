import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../models/shopping_list_item_model.dart';
import '../../providers/shopping_list_provider.dart';
import '../../widgets/ui/app_scaffold.dart';
import '../../widgets/ui/app_states.dart';
import '../../widgets/ui/app_text_field.dart';
import '../../widgets/ui/loading_skeleton.dart';
import 'widgets/shopping_list_item_tile.dart';

/// F-#6 Shopping List — danh sách mua offline-first (SQLite local, KHÔNG
/// network, KHÔNG sync — AC 6.7/6.8/6.17).
///
/// Layout: quick-add field luôn trên cùng (nhận gõ + Enter ngay khi vào màn —
/// AC 6.1/6.2), dưới là danh sách hoặc empty state có CTA focus lại ô nhập.
///
/// [highlightItemId] (AC 12.5): deep-link từ price alert — dòng tương ứng
/// được scroll tới và highlight tạm thời để user thấy ngay món vừa báo giá.
class ShoppingListScreen extends ConsumerStatefulWidget {
  final String? highlightItemId;

  const ShoppingListScreen({super.key, this.highlightItemId});

  @override
  ConsumerState<ShoppingListScreen> createState() =>
      _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _quickAddCtrl = TextEditingController();
  final _quickAddFocus = FocusNode();
  bool _showEmptyInputHint = false;

  /// AC 12.5 — key theo item id để Scrollable.ensureVisible tới đúng dòng.
  final _tileKeys = <String, GlobalKey>{};
  String? _highlightId;
  bool _didScrollToHighlight = false;

  @override
  void initState() {
    super.initState();
    // AC 6.13: mở màn list → các alert giá đã xem (badge trên entry tự clear).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shoppingListProvider.notifier).markAlertsSeen();
    });
  }

  @override
  void dispose() {
    _quickAddCtrl.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  /// AC 6.2/6.3: Enter với nội dung → thêm (đã trim) + clear input;
  /// rỗng/toàn space → KHÔNG tạo dòng, hiện hint nhẹ.
  Future<void> _submitQuickAdd() async {
    final text = _quickAddCtrl.text;
    if (text.trim().isEmpty) {
      setState(() => _showEmptyInputHint = true);
      return;
    }
    await ref.read(shoppingListProvider.notifier).addQuick(text);
    if (!mounted) return;
    setState(() {
      _showEmptyInputHint = false;
      _quickAddCtrl.clear();
    });
  }

  /// AC 12.5 — deep-link `?item=<id>`: scroll tới dòng và highlight tạm thời
  /// (3 giây) để user nhận ra món vừa được thông báo giá tốt.
  void _maybeScrollToHighlight(List<ShoppingListItem> items) {
    final target = widget.highlightItemId;
    if (target == null || target.isEmpty || _didScrollToHighlight) return;
    if (!items.any((i) => i.id == target)) return; // món đã bị xoá → bỏ qua

    _didScrollToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tileContext = _tileKeys[target]?.currentContext;
      if (tileContext != null) {
        await Scrollable.ensureVisible(
          tileContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
      }
      if (!mounted) return;
      setState(() => _highlightId = target);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightId = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(shoppingListProvider);

    return AppScaffold(
      title: 'Danh sách mua',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Quick-add (luôn sẵn sàng nhận gõ — AC 6.1) ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: AppTextField(
              key: const Key('shoppingList_quickAddField'),
              controller: _quickAddCtrl,
              focusNode: _quickAddFocus,
              hint: 'Thêm món…',
              prefixIcon: Icons.edit_outlined,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_showEmptyInputHint) {
                  setState(() => _showEmptyInputHint = false);
                }
              },
              onFieldSubmitted: (_) => _submitQuickAdd(),
            ),
          ),
          // AC 6.3: hint nhẹ khi Enter trên input rỗng — biến mất khi gõ/thêm.
          if (_showEmptyInputHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg + 4, AppSpacing.xs, AppSpacing.lg, 0),
              child: Text(
                'Gõ tên món cần mua rồi nhấn Enter để thêm vào danh sách',
                key: const Key('shoppingList_emptyInputHint'),
                style: context.text.bodySmall
                    ?.copyWith(color: context.snap.textSecondary),
              ),
            ),
          // ── Danh sách / empty state ────────────────────────────────────────
          Expanded(
            child: listAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: SkeletonList(itemCount: 4, itemHeight: 72),
              ),
              // Local-only: không có lỗi network thật; lỗi DB hiển thị + retry.
              error: (e, _) => ErrorState(
                message: 'Không đọc được danh sách mua trên máy này.',
                onRetry: () => ref.invalidate(shoppingListProvider),
              ),
              data: (items) {
                _maybeScrollToHighlight(items);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'Danh sách đang trống',
                    message:
                        'Gõ món cần mua ở ô trên rồi nhấn Enter — món khớp sản '
                        'phẩm bạn từng mua sẽ hiện luôn mức giá tốt nhất 90 ngày.',
                    actionLabel: 'Nhập món đầu tiên',
                    onAction: () => _quickAddFocus.requestFocus(),
                  );
                }
                return RefreshIndicator(
                  color: context.cs.primary,
                  onRefresh: () async {
                    // AC 6.11: local render tức thì; kéo để làm mới intel giá
                    // (merge ngầm từ server khi có mạng).
                    ref.invalidate(shoppingItemPriceIntelProvider);
                    await ref.read(shoppingListProvider.future);
                  },
                  child: ListView.builder(
                    key: const Key('shoppingList_listView'),
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final tileKey =
                          _tileKeys.putIfAbsent(item.id, () => GlobalKey());
                      return ShoppingListItemTile(
                        key: tileKey,
                        item: item,
                        highlighted: item.id == _highlightId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
