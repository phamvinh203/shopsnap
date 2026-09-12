import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/currency_formatter.dart';
import '../../database/daos/item_dao.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/category_classifier.dart';
import 'widgets/image_picker_section.dart';
import 'widgets/category_selector.dart';
import 'widgets/price_comparison_hint.dart';

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

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
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
    final created = await showModalBottomSheet<CategoryModel>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => const _AddCategorySheet(),
    );
    if (created != null && mounted) _onCategoryPicked(created.id);
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
      ), force: force);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Đã lưu "${_nameCtrl.text.trim()}"'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Dialog xác nhận khi server trả 409 ITEM_DUPLICATE:
  /// true = "Ghi lại lần nữa" (POST lại với force=true), false = Huỷ.
  Future<bool> _confirmDuplicateSave(String serverMessage) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Vật phẩm trùng?'),
      content: Text(
        '$serverMessage\n'
        'Bạn muốn ghi lại lần nữa chứ?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ghi lại lần nữa',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  ).then((v) => v == true);

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm vật phẩm'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          // Shortcut: OCR hóa đơn
          IconButton(
            tooltip: 'Chụp hóa đơn',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/ocr'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Quick action row: Scan + OCR + AR ────────────────────────
            Row(children: [
              Expanded(child: _QuickBtn(
                icon: Icons.qr_code_scanner,
                label: 'Scan barcode',
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
                    });
                    _onNameChanged(_nameCtrl.text);
                  }
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: _QuickBtn(
                icon: Icons.document_scanner_outlined,
                label: 'Chụp hóa đơn',
                onTap: () => context.push('/ocr'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _QuickBtn(
                icon: Icons.auto_fix_high_outlined,
                label: 'AR Sticker',
                onTap: () async {
                  final path = await context.push<String>('/ar');
                  if (path != null && mounted) {
                    setState(() => _imagePath = path);
                  }
                },
              )),
            ]),

            const SizedBox(height: 16),

            // ── Image picker ─────────────────────────────────────────────
            ImagePickerSection(
              imagePath:    _imagePath,
              onImagePicked: (p) => setState(() => _imagePath = p),
            ),

            const SizedBox(height: 20),

            // ── Tên sản phẩm ──────────────────────────────────────────
            const _Label('Tên sản phẩm'),
            const SizedBox(height: 6),
            TextFormField(
              controller:  _nameCtrl,
              onChanged:   _onNameChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:    'VD: Cà phê sữa, Áo thun xanh...',
                prefixIcon:  Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên sản phẩm' : null,
            ),

            const SizedBox(height: 16),

            // ── Giá tiền ──────────────────────────────────────────────
            const _Label('Giá tiền (đ)'),
            const SizedBox(height: 6),
            TextFormField(
              controller:  _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText:   '0',
                prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                suffixText: 'đ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập giá';
                if (int.tryParse(v) == null) return 'Giá không hợp lệ';
                return null;
              },
            ),

            // Price comparison hint
            if (_lastPrice != null || _avgPrice != null) ...[
              const SizedBox(height: 8),
              PriceComparisonHint(
                currentPrice: CurrencyFormatter.parse(_priceCtrl.text),
                lastPrice:    _lastPrice,
                avgPrice:     _avgPrice,
              ),
            ],

            const SizedBox(height: 20),

            // ── Danh mục ──────────────────────────────────────────────
            const _Label('Danh mục'),
            const SizedBox(height: 8),
            catsAsync.when(
              data: (cats) => CategorySelector(
                categories:    cats,
                selected:      _selectedCategory,
                suggestedId:   _manualCategory ? null : _suggestedCategoryId,
                onAddCategory: _showAddCategorySheet,
                onChanged:     _onCategoryPicked,
              ),
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              error:   (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // ── Ghi chú ───────────────────────────────────────────────
            const _Label('Ghi chú (tuỳ chọn)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteCtrl,
              maxLines:   3,
              decoration: const InputDecoration(
                hintText:    'Ghi chú thêm về sản phẩm...',
                prefixIcon:  Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_outlined, color: AppColors.primary),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 28),

            // ── Save button ───────────────────────────────────────────
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('💾  Lưu vật phẩm'),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
  );
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          )),
          const Text('Thêm danh mục',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),

          // Tên danh mục
          const Text('Tên danh mục',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            maxLength: 100,
            autofocus: true,
            buildCounter: (_, {required currentLength, required isFocused, int? maxLength}) => null,
            decoration: InputDecoration(
              hintText:   'VD: Thú cưng, Đồ dùng học tập...',
              prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
              errorText:  _error,
            ),
          ),

          const SizedBox(height: 8),

          // Icon (emoji)
          const Text('Biểu tượng',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _iconChoices.map((e) => GestureDetector(
              onTap: () => setState(() => _icon = e),
              child: Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:        _icon == e ? AppColors.primaryLight : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _icon == e ? AppColors.primary : AppColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 18)),
              ),
            )).toList(),
          ),

          const SizedBox(height: 12),

          // Màu
          const Text('Màu sắc',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _colorChoices.map((hex) => GestureDetector(
              onTap: () => setState(() => _color = hex),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _hexToColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _color == hex ? AppColors.textPrimary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Tạo danh mục'),
            ),
          ),
        ],
      ),
    ),
  );
}
