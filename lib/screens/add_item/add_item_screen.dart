import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../database/daos/item_dao.dart';
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

  // Price comparison hints
  int? _lastPrice;
  int? _avgPrice;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String value) async {
    // Auto-classify category
    final suggested = CategoryClassifier.classify(value);
    if (suggested != 'cat_other') {
      setState(() => _selectedCategory = suggested);
    }
    // Fetch price hint
    if (value.trim().length >= 3) {
      final db   = await ref.read(databaseProvider.future);
      final hint = await ItemDao(db).getPriceHint(value, null);
      setState(() { _lastPrice = hint.lastPrice; _avgPrice = hint.avgPrice; });
    } else {
      setState(() { _lastPrice = null; _avgPrice = null; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(itemsProvider.notifier).addItem(CreateItemDto(
        name:       _nameCtrl.text.trim(),
        price:      CurrencyFormatter.parse(_priceCtrl.text),
        categoryId: _selectedCategory,
        imagePath:  _imagePath,
        note:       _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));

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
                      if (result['category_id'] != null) _selectedCategory = result['category_id'] as String;
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
                categories: cats,
                selected:   _selectedCategory,
                onChanged:  (id) => setState(() => _selectedCategory = id),
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
