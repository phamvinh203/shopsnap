import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/currency_formatter.dart';
import '../../database/daos/item_dao.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/barcode_contribute_service.dart';
import '../../services/category_classifier.dart';
import '../../widgets/ui/ui.dart';
import '../scan/widgets/barcode_contribute_sheet.dart';
import 'widgets/image_picker_section.dart';
import 'widgets/category_selector.dart';
import 'widgets/price_comparison_hint.dart';
import 'widgets/store_field.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});
  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _priceCtrl   = TextEditingController();
  final _noteCtrl    = TextEditingController();
  final _storeCtrl   = TextEditingController(); // M-3: "Nơi mua" (tuỳ chọn)

  String? _imagePath;
  String  _selectedCategory = 'cat_other';
  bool    _isSaving         = false;

  // ── Wave 2: gợi ý category từ server (/categories/suggest) ─────────────────
  Timer?  _suggestDebounce;     // debounce 500ms trước khi gọi API
  String? _suggestedCategoryId; // id được server gợi ý (hiện badge "Gợi ý")
  bool    _manualCategory = false; // user đã tự chọn → không auto-đổi nữa

  // Price comparison hints
  int? _lastPrice;
  int? _avgPrice;

  // ── Wave 6: barcode quét được mà lookup không ra sản phẩm ──────────────────
  // Giữ mã lại để hiện action "Đóng góp thông tin" (POST /barcode/contribute).
  // Lookup RA sản phẩm thì dữ liệu đã có trên hệ thống → không hiện banner.
  String? _scannedBarcode;
  bool    _barcodeNotFound = false;

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String value) async {
    final name = value.trim();

    // Auto-classify local — phản hồi tức thì, dùng được cả offline.
    // User đã tự chọn category thì không tự ghi đè lựa chọn của họ.
    final suggested = CategoryClassifier.classify(name);
    if (suggested != 'cat_other' && !_manualCategory) {
      setState(() => _selectedCategory = suggested);
    }
    // Fetch price hint
    if (name.length >= 3) {
      final db   = await ref.read(databaseProvider.future);
      final hint = await ItemDao(db).getPriceHint(name, null);
      setState(() { _lastPrice = hint.lastPrice; _avgPrice = hint.avgPrice; });
    } else {
      setState(() { _lastPrice = null; _avgPrice = null; });
    }

    // Gợi ý từ server — debounce ~500ms, chỉ chạy khi chưa tự chọn category
    _suggestDebounce?.cancel();
    if (name.length < 2) {
      if (mounted && _suggestedCategoryId != null) {
        setState(() => _suggestedCategoryId = null);
      }
      return;
    }
    _suggestDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _fetchServerSuggestion(name),
    );
  }

  /// GET /categories/suggest — pre-select category gợi ý + hiện badge "Gợi ý".
  /// Lỗi (mạng/401...) → bỏ qua lặng lẽ, classifier local ở trên vẫn còn tác dụng.
  Future<void> _fetchServerSuggestion(String name) async {
    // Endpoint cần JWT — chưa đăng nhập thì classifier local đã đủ
    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) return;

    try {
      final sugg = await ref.read(categoryApiServiceProvider).suggestCategory(name);
      if (!mounted || _manualCategory) return;

      final categoryId = sugg.isMeaningful ? sugg.suggestedCategoryId : null;
      setState(() => _suggestedCategoryId = categoryId);
      // Auto chọn category gợi ý nếu user chưa tự chọn
      if (categoryId != null && categoryId != _selectedCategory) {
        setState(() => _selectedCategory = categoryId);
      }
    } catch (_) {
      // im lặng — offline vẫn chạy với classifier local
    }
  }

  /// User chủ động chọn category → khoá auto-suggest cho đến khi rời màn.
  void _onCategoryPicked(String id) {
    _suggestDebounce?.cancel();
    setState(() {
      _selectedCategory    = id;
      _manualCategory      = true;
      _suggestedCategoryId = null; // tắt badge "Gợi ý"
    });
  }

  /// Sheet tạo nhanh category custom (POST /categories khi online, local khi offline).
  /// Thành công → tự chọn luôn category vừa tạo.
  Future<void> _showAddCategorySheet() async {
    final created = await AppBottomSheet.show<CategoryModel>(
      context: context,
      title:   'Thêm danh mục',
      builder: (_) => const _AddCategorySheet(),
    );
    if (created != null && mounted) _onCategoryPicked(created.id);
  }

  /// Wave 6 — sheet đóng góp dữ liệu barcode chưa có trên hệ thống
  /// (POST /barcode/contribute), pre-fill từ những gì user đã nhập ở form.
  Future<void> _showContributeSheet() async {
    final barcode = _scannedBarcode;
    if (barcode == null) return;

    final contributed = await showModalBottomSheet<BarcodeContribution>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => BarcodeContributeSheet(
        barcode:      barcode,
        initialName:  _nameCtrl.text.trim(),
        initialPrice: _priceCtrl.text.trim().isEmpty ? null : CurrencyFormatter.parse(_priceCtrl.text),
        categoryId:   _contributeCategoryId(),
      ),
    );
    if (contributed == null || !mounted) return;

    setState(() => _barcodeNotFound = false); // đã đóng góp → gỡ banner
    AppSnackBar.show(
      context: context,
      message: contributed.message.isEmpty
          ? 'Cảm ơn bạn đã đóng góp!'
          : 'Cảm ơn bạn đã đóng góp! ${contributed.message}',
      tone: AppSnackBarTone.success,
      duration: const Duration(seconds: 3),
    );
  }

  /// category_id gửi kèm đóng góp — chỉ khi user CHỦ ĐỘNG chọn và là id thật
  /// của server (id `local_` chưa đồng bộ / mặc định 'Khác' thì bỏ trống:
  /// đóng góp category sai còn tệ hơn để server tự xử lý khi duyệt).
  String? _contributeCategoryId() {
    if (!_manualCategory) return null;
    final id = _selectedCategory;
    return (id.isNotEmpty && !id.startsWith('local_')) ? id : null;
  }

  Future<void> _save({bool force = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // User để mặc định "Khác" (không tự chọn, classifier/suggest cũng không
      // match) → bỏ category_id cho server auto-classify (BR-04) — server trả
      // category chuẩn rồi upsert ngược về local.
      final fallbackOther = !_manualCategory && _selectedCategory == 'cat_other';
      await ref.read(itemsProvider.notifier).addItem(CreateItemDto(
        name:       _nameCtrl.text.trim(),
        price:      CurrencyFormatter.parse(_priceCtrl.text),
        categoryId: fallbackOther ? null : _selectedCategory,
        imagePath:  _imagePath,
        note:       _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        // M-3 (AC 7.3/7.5): trim; rỗng → null (item KHÔNG có nơi mua).
        storeName:  sanitizeStoreName(_storeCtrl.text),
      ), force: force);

      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: 'Đã lưu "${_nameCtrl.text.trim()}"',
          tone: AppSnackBarTone.success,
          duration: const Duration(seconds: 2),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 ITEM_DUPLICATE — server nghi item trùng vừa thêm (cùng giá + danh
      // mục + cửa hàng trong 5 phút) → hỏi user có muốn ghi lại lần nữa không.
      if (e.code == 'ITEM_DUPLICATE') {
        final retry = await _confirmDuplicateSave(e.message);
        if (retry && mounted) {
          setState(() => _isSaving = false);
          await _save(force: true); // POST lại với ?force=true
        }
        return;
      }
      AppSnackBar.show(
        context: context,
        message: apiErrorMessage(e),
        tone: AppSnackBarTone.danger,
      );
    } catch (_) {
      if (mounted) {
        // Không hiện raw exception — microcopy tiếng Việt chuẩn.
        AppSnackBar.show(
          context: context,
          message: 'Đã có lỗi xảy ra. Vui lòng thử lại.',
          tone: AppSnackBarTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Dialog xác nhận khi server trả 409 ITEM_DUPLICATE:
  /// true = "Ghi lại lần nữa" (POST lại với force=true), false = Huỷ.
  Future<bool> _confirmDuplicateSave(String serverMessage) => ConfirmDialog.show(
    context:       context,
    title:         'Vật phẩm trùng?',
    message:       '$serverMessage\nBạn muốn ghi lại lần nữa chứ?',
    confirmLabel:  'Ghi lại lần nữa',
    cancelLabel:   'Huỷ',
  );

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    // Banner đóng góp chỉ dành cho user đã đăng nhập (endpoint cần JWT);
    // offline vẫn hiện — submit lỗi mạng sẽ có message tiếng Việt, không crash.
    final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;
    final showContributeBar = authenticated && _scannedBarcode != null && _barcodeNotFound;

    return AppScaffold(
      title: 'Thêm mặt hàng',
      // Nút ✕ đóng form (thay leading mặc định) — giữ hành vi pop hiện có.
      leading: IconButton(
        key: const Key('addItem_closeButton'),
        icon: const Icon(Icons.close),
        tooltip: 'Đóng',
        onPressed: () => context.pop(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Quick action row: Quét mã + OCR + AR ─────────────────────
            // (I4: bỏ nút OCR trùng lặp trên appbar — chỉ còn 1 điểm vào ở đây.)
            Row(children: [
              Expanded(child: _QuickAction(
                key: const Key('addItem_quickScan'),
                icon: Icons.qr_code_scanner,
                label: 'Quét mã',
                onTap: () async {
                  final result = await context.push<Map<String, dynamic>>('/scan');
                  if (result != null && mounted) {
                    setState(() {
                      if (result['name'] != null) _nameCtrl.text = result['name'] as String;
                      if (result['category_id'] != null) {
                        _selectedCategory = result['category_id'] as String;
                        // Category từ dữ liệu barcode coi như đã chọn — không auto-đổi
                        _manualCategory = true;
                        _suggestedCategoryId = null;
                      }
                      // Wave 6: giữ barcode khi lookup hụt (result không có
                      // 'name') để mời đóng góp; đã đóng góp rồi thì thôi.
                      if (result['barcode'] is String) {
                        _scannedBarcode  = result['barcode'] as String;
                        _barcodeNotFound = result['name'] == null && result['contributed'] != true;
                      } else {
                        _scannedBarcode  = null;
                        _barcodeNotFound = false;
                      }
                    });
                    _onNameChanged(_nameCtrl.text);
                  }
                },
              )),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _QuickAction(
                icon: Icons.document_scanner_outlined,
                label: 'Chụp hóa đơn',
                onTap: () => context.push('/ocr'),
              )),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _QuickAction(
                icon: Icons.auto_fix_high_outlined,
                label: 'Nhãn giá AR',
                onTap: () async {
                  final path = await context.push<String>('/ar');
                  if (path != null && mounted) {
                    setState(() => _imagePath = path);
                  }
                },
              )),
            ]),

            // ── Wave 6: barcode chưa có dữ liệu → mời đóng góp cho cộng đồng ──
            if (showContributeBar) ...[
              const SizedBox(height: AppSpacing.lg),
              _ContributeBanner(
                barcode: _scannedBarcode ?? '',
                onContribute: _showContributeSheet,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── Image picker ─────────────────────────────────────────────
            ImagePickerSection(
              imagePath:    _imagePath,
              onImagePicked: (p) => setState(() => _imagePath = p),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Tên sản phẩm ──────────────────────────────────────────
            AppTextField(
              key: const Key('addItem_nameField'),
              controller:  _nameCtrl,
              label:       'Tên sản phẩm',
              hint:        'VD: Cà phê sữa, Áo thun xanh...',
              prefixIcon:  Icons.shopping_bag_outlined,
              onChanged:   _onNameChanged,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên sản phẩm' : null,
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Giá tiền — "sân khấu chính" cho bàn phím số (4.5): khối
            // surfaceVariant radius 10, số moneyOf 32 w700 canh phải.
            // (Key addItem_priceField giữ nguyên; validator giữ nguyên.)
            Text(
              'Giá tiền (đ)'.toUpperCase(),
              style: AppTypography.overlineOf(
                context.text,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: TextFormField(
                key: const Key('addItem_priceField'),
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                style: AppTypography.moneyOf(context.text, size: 32)
                    .copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: AppTypography.moneyOf(context.text, size: 32)
                      .copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.cs.onSurfaceVariant
                              .withOpacity(0.5)),
                  suffixText: 'đ',
                  suffixStyle: AppTypography.moneyOf(
                    context.text,
                    size: 14,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập giá';
                  if (int.tryParse(v) == null) return 'Giá không hợp lệ';
                  return null;
                },
              ),
            ),

            // Price comparison hint (chỉ hiện khi giá > 0 — xem component)
            if (_lastPrice != null || _avgPrice != null) ...[
              const SizedBox(height: AppSpacing.sm),
              PriceComparisonHint(
                currentPrice: CurrencyFormatter.parse(_priceCtrl.text),
                lastPrice:    _lastPrice,
                avgPrice:     _avgPrice,
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // ── Danh mục ──────────────────────────────────────────────
            const SectionHeader(title: 'Danh mục'),
            const SizedBox(height: AppSpacing.sm),
            catsAsync.when(
              data: (cats) => CategorySelector(
                categories:    cats,
                selected:      _selectedCategory,
                suggestedId:   _manualCategory ? null : _suggestedCategoryId,
                onAddCategory: _showAddCategorySheet,
                onChanged:     _onCategoryPicked,
              ),
              loading: () => const LoadingSkeleton(height: 40, radius: AppRadius.md),
              error:   (_, __) => ErrorState(
                message: 'Không tải được danh mục.',
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── M-3: Nơi mua (tuỳ chọn) + gợi ý theo tần suất local ─────
            StoreFieldSuggestions(
              controller: _storeCtrl,
              suggestions: ref.watch(storeSuggestionsProvider).valueOrNull ??
                  const <String>[],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Ghi chú ───────────────────────────────────────────────
            AppTextField(
              key: const Key('addItem_noteField'),
              controller: _noteCtrl,
              label:      'Ghi chú (tuỳ chọn)',
              hint:       'Ghi chú thêm về sản phẩm...',
              maxLines:   3,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Save button ───────────────────────────────────────────
            PrimaryButton(
              key: const Key('addItem_saveButton'),
              label:    'Lưu mặt hàng',
              loading:  _isSaving,
              onPressed: _save,
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Nút quick action (Quét mã / Chụp hóa đơn / Nhãn giá AR) — "ruled tile":
/// nền giấy + hairline border, icon + label 12/w600 (4.5), Material+InkWell
/// có ripple + semantics (I5).
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.hairline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Material(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: colors.textPrimary, size: 22),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner mời đóng góp barcode — style từ tokens, giữ nguyên text/luồng Wave 6.
class _ContributeBanner extends StatelessWidget {
  final String barcode;
  final VoidCallback onContribute;

  const _ContributeBanner({required this.barcode, required this.onContribute});

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.tintPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.cs.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.volunteer_activism_outlined,
            color: context.cs.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barcode: $barcode',
                  style: context.text.labelLarge?.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              Text('Chưa có dữ liệu — giúp cộng đồng nhé?',
                  style: context.text.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
        ),
        TextButton(onPressed: onContribute, child: const Text('Đóng góp')),
      ]),
    );
  }
}

// ── Sheet tạo nhanh category custom (Wave 2) ────────────────────────────────

class _AddCategorySheet extends ConsumerStatefulWidget {
  const _AddCategorySheet();
  @override
  ConsumerState<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<_AddCategorySheet> {
  final _nameCtrl = TextEditingController();

  String  _icon   = _iconChoices.first;
  String  _color  = _colorChoices.first;
  bool    _saving = false;
  String? _error;

  static const _iconChoices = [
    '🛒', '🐾', '📚', '💐', '🎮', '☕', '🍰', '🚗', '🏠', '💊', '🎁', '⚽',
  ];
  static const _colorChoices = [
    '#8BC34A', '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
    '#FFEAA7', '#DDA0DD', '#FFA726',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên danh mục');
      return;
    }
    if (name.length > 100) {
      setState(() => _error = 'Tên danh mục tối đa 100 ký tự');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final cat = await ref.read(categoriesProvider.notifier)
          .createCategory(name: name, color: _color, icon: _icon);
      if (mounted) Navigator.pop(context, cat);
    } catch (e) {
      // 409 trùng tên v.v. → message tiếng Việt từ api_error_messages
      if (mounted) setState(() { _saving = false; _error = apiErrorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          key: const Key('addCategorySheet_nameField'),
          controller: _nameCtrl,
          label: 'Tên danh mục',
          hint: 'VD: Thú cưng, Đồ dùng học tập...',
          prefixIcon: Icons.category_outlined,
          autofocus: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            key: const Key('addCategorySheet_error'),
            style: context.text.bodySmall?.copyWith(color: colors.danger),
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // Icon (emoji — dữ liệu category, giữ nguyên danh sách choice)
        Text('Biểu tượng', style: context.text.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm, runSpacing: AppSpacing.sm,
          children: _iconChoices.map((e) => InkWell(
            onTap: () => setState(() => _icon = e),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        _icon == e ? colors.tintPrimary : context.cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _icon == e ? colors.onTintPrimary : colors.hairline,
                  width: 1.5,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 18)),
            ),
          )).toList(),
        ),

        const SizedBox(height: AppSpacing.md),

        // Màu
        Text('Màu sắc', style: context.text.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _colorChoices.map((hex) => InkWell(
            onTap: () => setState(() => _color = hex),
            customBorder: const CircleBorder(),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _hexToColor(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _color == hex ? context.cs.primary : colors.hairline,
                  width: 3,
                ),
              ),
            ),
          )).toList(),
        ),

        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          key: const Key('addCategorySheet_submitButton'),
          label: 'Tạo danh mục',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
