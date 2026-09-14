import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/core/utils/api_error_messages.dart';
import 'package:shopsnap/core/utils/currency_formatter.dart';
import 'package:shopsnap/database/daos/item_dao.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/services/ocr_service.dart';
import 'package:shopsnap/widgets/ui/ui.dart';
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
        _purchaseDate = result.purchaseDate;
        _storeController.text = result.storeName ?? '';
        _step        = _OcrStep.review;
      });
    } catch (e) {
      if (mounted) {
        // Không còn 'Lỗi OCR: $e' raw — map sang microcopy tiếng Việt.
        AppSnackBar.show(
          context: context,
          message: apiErrorMessage(e),
          tone: AppSnackBarTone.danger,
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
      // Glossary R14: "mặt hàng" thay "items"; snackbar chuẩn hoá (AppSnackBar).
      AppSnackBar.show(
        context: context,
        message: 'Đã lưu ${validItems.length} mặt hàng từ hóa đơn',
        tone: AppSnackBarTone.success,
      );
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
        _OcrStep.idle       => _buildIdle(context),
        _OcrStep.processing => _buildProcessing(context),
        _OcrStep.review     => _buildReview(context),
      },
    );
  }

  // ── Step 1: Idle ──────────────────────────────────────────────────────────
  Widget _buildIdle(BuildContext context) {
    final colors = context.snap;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(children: [
        Container(
          width: double.infinity, height: 200,
          decoration: BoxDecoration(
            color: colors.tintPrimary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
                color: context.cs.primary.withOpacity(0.3), width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🧾', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text('Chụp hoặc chọn ảnh hóa đơn',
                style: context.text.titleSmall
                    ?.copyWith(color: colors.onTintPrimary)),
          ]),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        PrimaryButton(
          key: const Key('ocrScreen_cameraButton'),
          label: 'Chụp hóa đơn',
          icon: Icons.camera_alt_outlined,
          onPressed: () => _pickAndProcess(ImageSource.camera),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          key: const Key('ocrScreen_galleryButton'),
          label: 'Chọn từ thư viện',
          onPressed: () => _pickAndProcess(ImageSource.gallery),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.tintPrimary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Icon(Icons.lightbulb_outline,
                color: colors.onTintPrimary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(
              'Đặt hóa đơn trên nền tối, chụp thẳng góc và đủ ánh sáng để OCR chính xác hơn.',
              style: context.text.bodySmall
                  ?.copyWith(color: colors.onTintPrimary),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── Step 2: Processing ────────────────────────────────────────────────────
  Widget _buildProcessing(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: context.cs.primary),
      const SizedBox(height: AppSpacing.xl),
      Text('Đang phân tích hóa đơn...',
          style: context.text.titleMedium),
      const SizedBox(height: AppSpacing.xs + 2),
      Text('Hệ thống đang nhận diện văn bản',
          style: context.text.bodySmall),
    ]),
  );

  // ── Step 3: Review ────────────────────────────────────────────────────────
  Widget _buildReview(BuildContext context) {
    final colors = context.snap;
    final total = _editedItems.fold(0, (s, i) => s + i.price);
    final quality = _result?.quality;
    final isGemini = _result?.source == OcrSource.geminiVision;
    final bannerColor =
        isGemini ? colors.onTintPrimary : _qualityColor(context, quality ?? OcrQuality.fair);

    return Column(children: [
      // Source & Quality banner
      Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bannerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          border: Border.all(color: bannerColor.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(
            isGemini ? Icons.auto_awesome : _qualityIcon(quality ?? OcrQuality.fair),
            color: bannerColor,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isGemini
                  ? '✨ Phân tích bởi Gemini AI Vision'
                  : _qualityText(quality ?? OcrQuality.fair),
              style: context.text.bodySmall
                  ?.copyWith(color: bannerColor, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            key: const Key('ocrScreen_retakeButton'),
            onTap: () => setState(() => _step = _OcrStep.idle),
            child: Text('Chụp lại',
                style: context.text.labelLarge
                    ?.copyWith(color: context.cs.primary, fontSize: 12)),
          ),
        ]),
      ),

      // Items list
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Store & Date card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 18, color: context.cs.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _storeController,
                          decoration: const InputDecoration(
                            hintText: 'Tên siêu thị / cửa hàng (tùy chọn)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
                            border: InputBorder.none,
                            filled: false,
                          ),
                          style: context.text.titleSmall
                              ?.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (_purchaseDate != null) ...[
                    const Divider(height: AppSpacing.md + 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: context.cs.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Ngày mua: ${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(children: [
              Text('Nhận diện được ${_editedItems.length} mặt hàng',
                  style: context.text.titleSmall),
              const Spacer(),
              // Tổng tiền — MoneyText tabular figures, màu brand.
              MoneyText(
                key: const Key('ocrScreen_total'),
                amount: total,
                colored: true,
              ),
            ]),
            if (_result?.totalFromReceipt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tổng trên hóa đơn: ${CurrencyFormatter.format(_result!.totalFromReceipt!)}  '
                '${(total - _result!.totalFromReceipt!).abs() < 1000 ? "✅ Khớp" : "⚠️ Lệch"}',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OcrResultList(
              initialItems: _editedItems,
              onChanged:    (items) => setState(() => _editedItems = items),
            ),
          ],
        ),
      ),

      // Bottom action
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: PrimaryButton(
          key: const Key('ocrScreen_saveAllButton'),
          // Bỏ emoji ✅ khỏi label (memo I7) — icon tự thêm khi cần.
          label: 'Lưu tất cả ${_editedItems.length} mặt hàng',
          onPressed: _editedItems.isEmpty ? null : _saveAll,
        ),
      ),
    ]);
  }

  Color _qualityColor(BuildContext context, OcrQuality q) => switch (q) {
    OcrQuality.good => context.snap.success,
    OcrQuality.fair => context.snap.warning,
    OcrQuality.poor => context.snap.danger,
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
