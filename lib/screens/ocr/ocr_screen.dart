import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/core/utils/api_error_messages.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/services/ocr_service.dart';
import 'package:shopsnap/widgets/ui/ui.dart';
import 'widgets/ocr_review_confirm.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

enum _OcrStep { idle, processing, review }

class _OcrScreenState extends ConsumerState<OcrScreen> {
  _OcrStep   _step = _OcrStep.idle;
  OcrResult? _result;

  Future<void> _pickAndProcess(ImageSource source) async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;

    setState(() { _step = _OcrStep.processing; });

    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await OcrService.parseReceiptWithVision(file.path, apiClient: apiClient);
      setState(() {
        _result = result;
        _step   = _OcrStep.review;
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

  // ── Step 3: Review → CONFIRM từng dòng (F-#5 P1) ──────────────────────────
  // Toàn bộ UI + logic confirm (category gợi ý, cảnh báo trùng, bulk create)
  // nằm ở OcrReviewConfirm — screen này chỉ điều phối các bước.
  Widget _buildReview(BuildContext context) {
    return OcrReviewConfirm(
      result: _result!,
      onFinished: () => context.pop(),
      onRetake: () => setState(() => _step = _OcrStep.idle),
    );
  }
}
