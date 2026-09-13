import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/theme/app_colors.dart';
import 'package:shopsnap/core/utils/currency_formatter.dart';
import 'package:shopsnap/database/daos/item_dao.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/services/ocr_service.dart';
import 'widgets/ocr_result_list.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

enum _OcrStep { idle, processing, review }

class _OcrScreenState extends ConsumerState<OcrScreen> {
  _OcrStep        _step = _OcrStep.idle;
  OcrResult?      _result;
  List<OcrItem>   _editedItems = [];
  String?         _imagePath;
  String?         _storeName;
  DateTime?       _purchaseDate;
  final TextEditingController _storeController = TextEditingController();

  @override
  void dispose() {
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;

    setState(() { _step = _OcrStep.processing; _imagePath = file.path; });

    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await OcrService.parseReceiptWithVision(file.path, apiClient: apiClient);
      setState(() {
        _result      = result;
        _editedItems = List.from(result.items);
        _storeName   = result.storeName;
        _purchaseDate = result.purchaseDate;
        _storeController.text = result.storeName ?? '';
        _step        = _OcrStep.review;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi OCR: $e'), backgroundColor: AppColors.danger),
        );
        setState(() => _step = _OcrStep.idle);
      }
    }
  }

  Future<void> _saveAll() async {
    final validItems = _editedItems.where((i) => i.name.trim().isNotEmpty && i.price > 0).toList();
    if (validItems.isEmpty) return;

    final store = _storeController.text.trim();
    final note = store.isNotEmpty ? 'Mua tại: $store' : null;
    final sourceTag = _result?.source == OcrSource.geminiVision ? 'gemini_vision' : 'ocr';

    for (final item in validItems) {
      await ref.read(itemsProvider.notifier).addItem(CreateItemDto(
        name: item.name.trim(),
        price: item.price,
        categoryId: item.categoryId,
        imagePath: _imagePath,
        note: note,
      ), source: sourceTag); // đánh dấu nguồn để thống kê server-side
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Đã lưu ${validItems.length} items từ hóa đơn'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chụp hóa đơn'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: switch (_step) {
        _OcrStep.idle       => _buildIdle(),
        _OcrStep.processing => _buildProcessing(),
        _OcrStep.review     => _buildReview(),
      },
    );
  }

  // ── Step 1: Idle ──────────────────────────────────────────────────────────
  Widget _buildIdle() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Container(
        width: double.infinity, height: 200,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🧾', style: TextStyle(fontSize: 56)),
          SizedBox(height: 12),
          Text('Chụp hoặc chọn ảnh hóa đơn',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
        ]),
      ),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: () => _pickAndProcess(ImageSource.camera),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Chụp hóa đơn'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _pickAndProcess(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
        label: const Text('Chọn từ thư viện', style: TextStyle(color: AppColors.primary)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primary),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Đặt hóa đơn trên nền tối, chụp thẳng góc và đủ ánh sáng để OCR chính xác hơn.',
            style: TextStyle(fontSize: 12, color: AppColors.primary),
          )),
        ]),
      ),
    ]),
  );

  // ── Step 2: Processing ────────────────────────────────────────────────────
  Widget _buildProcessing() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: AppColors.primary),
      SizedBox(height: 20),
      Text('Đang phân tích hóa đơn...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      SizedBox(height: 6),
      Text('ML Kit đang nhận diện văn bản', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );

  // ── Step 3: Review ────────────────────────────────────────────────────────
  Widget _buildReview() {
    final total = _editedItems.fold(0, (s, i) => s + i.price);
    final quality = _result?.quality;

    return Column(children: [
      // Source & Quality banner
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _result?.source == OcrSource.geminiVision
              ? const Color(0xFF8B5CF6).withOpacity(0.12)
              : (_qualityColor(quality ?? OcrQuality.fair)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _result?.source == OcrSource.geminiVision
                ? const Color(0xFF8B5CF6).withOpacity(0.4)
                : (_qualityColor(quality ?? OcrQuality.fair)).withOpacity(0.3),
          ),
        ),
        child: Row(children: [
          Icon(
            _result?.source == OcrSource.geminiVision ? Icons.auto_awesome : _qualityIcon(quality ?? OcrQuality.fair),
            color: _result?.source == OcrSource.geminiVision ? const Color(0xFF8B5CF6) : _qualityColor(quality ?? OcrQuality.fair),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _result?.source == OcrSource.geminiVision
                  ? '✨ Phân tích bởi Gemini AI Vision'
                  : _qualityText(quality ?? OcrQuality.fair),
              style: TextStyle(
                color: _result?.source == OcrSource.geminiVision ? const Color(0xFF7C3AED) : _qualityColor(quality ?? OcrQuality.fair),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _step = _OcrStep.idle),
            child: const Text('Chụp lại', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),

      // Items list
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Store & Date card
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _storeController,
                          decoration: const InputDecoration(
                            hintText: 'Tên siêu thị / cửa hàng (tùy chọn)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (_purchaseDate != null) ...[
                    const Divider(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Ngày mua: ${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(children: [
              Text('Nhận diện được ${_editedItems.length} items',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text(CurrencyFormatter.format(total),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
            ]),
            if (_result?.totalFromReceipt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tổng trên hóa đơn: ${CurrencyFormatter.format(_result!.totalFromReceipt!)}  '
                '${(total - _result!.totalFromReceipt!).abs() < 1000 ? "✅ Khớp" : "⚠️ Lệch"}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            OcrResultList(
              initialItems: _editedItems,
              onChanged:    (items) => setState(() => _editedItems = items),
            ),
          ],
        ),
      ),

      // Bottom action
      Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _editedItems.isEmpty ? null : _saveAll,
          child: Text('✅  Lưu tất cả ${_editedItems.length} items'),
        ),
      ),
    ]);
  }

  Color _qualityColor(OcrQuality q) => switch (q) {
    OcrQuality.good => AppColors.success,
    OcrQuality.fair => AppColors.warning,
    OcrQuality.poor => AppColors.danger,
  };

  IconData _qualityIcon(OcrQuality q) => switch (q) {
    OcrQuality.good => Icons.check_circle_outline,
    OcrQuality.fair => Icons.warning_amber_outlined,
    OcrQuality.poor => Icons.error_outline,
  };

  String _qualityText(OcrQuality q) => switch (q) {
    OcrQuality.good => 'Nhận diện tốt — vui lòng kiểm tra lại',
    OcrQuality.fair => 'Một số mục cần kiểm tra (vàng)',
    OcrQuality.poor => 'Chất lượng thấp — nên chụp lại',
  };
}
