import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/api_error_messages.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/barcode_provider.dart';
import '../../../services/barcode_contribute_service.dart';
import '../../../widgets/ui/ui.dart';

/// Sheet đóng góp dữ liệu barcode (Wave 6 — POST /barcode/contribute).
///
/// Mở khi quét được mã mà lookup không ra sản phẩm: chỉ cần tên sản phẩm
/// (backend bắt buộc), giá tuỳ chọn; các field còn lại pre-fill từ ngữ cảnh
/// nếu có. Thành công → pop trả về [BarcodeContribution] để caller hiện
/// snackbar cảm ơn; Huỷ → pop null.
///
/// Chưa đăng nhập / mất mạng: caller nên ẩn điểm mở sheet; nếu vẫn gọi,
/// submit sẽ hiện hint đăng nhập hoặc message mạng tiếng Việt — không crash.
class BarcodeContributeSheet extends ConsumerStatefulWidget {
  final String barcode;

  // Pre-fill từ ngữ cảnh caller (form add_item, kết quả lookup...) — tuỳ chọn.
  final String? initialName;
  final int? initialPrice;
  final String? categoryId;
  final String? storeName;
  final String? brand;

  const BarcodeContributeSheet({
    super.key,
    required this.barcode,
    this.initialName,
    this.initialPrice,
    this.categoryId,
    this.storeName,
    this.brand,
  });

  @override
  ConsumerState<BarcodeContributeSheet> createState() => _BarcodeContributeSheetState();
}

class _BarcodeContributeSheetState extends ConsumerState<BarcodeContributeSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.initialName ?? '');
    _priceCtrl = TextEditingController(
        text: widget.initialPrice == null ? '' : '$widget.initialPrice');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final barcode = widget.barcode.trim();

    // Validate client-side theo ContributeBarcodeDto (barcode 4–30, name 1–255)
    // → hầu như không bao giờ chạm 400 của server (message 400 là tiếng Anh).
    if (barcode.length < 4 || barcode.length > 30) {
      setState(() => _error = 'Mã barcode phải từ 4 đến 30 ký tự');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên sản phẩm');
      return;
    }
    // AppTextField không hỗ trợ maxLength → giữ cap 255 ký tự của DTO tại đây
    // (trước đây dùng TextField.maxLength).
    if (name.length > 255) {
      setState(() => _error = 'Tên sản phẩm tối đa 255 ký tự');
      return;
    }

    final authenticated = ref.read(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) {
      setState(() => _error = 'Vui lòng đăng nhập để đóng góp thông tin.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final contributed = await ref.read(barcodeContributeServiceProvider).contribute(
        barcode:    barcode,
        name:       name,
        format:     guessBarcodeFormat(barcode),
        brand:      widget.brand,
        categoryId: widget.categoryId,
        price:      _priceCtrl.text.trim().isEmpty ? null : CurrencyFormatter.parse(_priceCtrl.text),
        storeName:  widget.storeName,
      );
      if (mounted) Navigator.pop(context, contributed);
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = _vnError(e); });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        });
      }
    }
  }

  /// Map lỗi đóng góp → tiếng Việt. Backend barcode module không trả code riêng
  /// (400 là shape Nest mặc định với message tiếng Anh — đã verify bằng curl)
  /// nên 400 đổi thành câu gọn thay vì leak message gốc; các lỗi khác đi qua
  /// [apiErrorMessage] chung (NETWORK_ERROR đã là tiếng Việt sẵn).
  String _vnError(ApiException e) {
    if (e.statusCode == 400) {
      return 'Thông tin đóng góp chưa hợp lệ. Vui lòng kiểm tra lại.';
    }
    return apiErrorMessage(e);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxl + 4),
        // Surface qua theme (dark-mode ready) thay Colors.white hardcode.
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                  color: colors.hairline,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            )),
            Text('Đóng góp thông tin sản phẩm', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Giúp cộng đồng ShopSnap biết sản phẩm của mã này',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Barcode — chỉ hiển thị, không sửa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md - 2),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                border: Border.all(color: colors.hairline),
              ),
              child: Row(children: [
                Icon(Icons.qr_code_2, size: 18, color: context.cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(widget.barcode,
                      style: context.text.titleSmall?.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),

            const SizedBox(height: AppSpacing.md),

            // Tên sản phẩm — bắt buộc (backend yêu cầu)
            Text('Tên sản phẩm *', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs + 2),
            AppTextField(
              key: const Key('contributeSheet_nameField'),
              controller: _nameCtrl,
              autofocus: (widget.initialName ?? '').isEmpty,
              textCapitalization: TextCapitalization.sentences,
              prefixIcon: Icons.shopping_bag_outlined,
              hint: 'VD: Sữa tươi Vinamilk 1L...',
            ),

            // Lỗi validate/server — hiện rõ dưới field thay vì nuốt im lặng
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Icon(Icons.error_outline, size: 16, color: colors.danger),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _error!,
                    key: const Key('contributeSheet_error'),
                    style: context.text.bodySmall
                        ?.copyWith(color: colors.danger),
                  ),
                ),
              ]),
            ],

            const SizedBox(height: AppSpacing.sm),

            // Giá tiền — tuỳ chọn
            Text('Giá tiền (đ) — tuỳ chọn', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs + 2),
            AppTextField(
              key: const Key('contributeSheet_priceField'),
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: Icons.attach_money,
              suffix: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: Text('đ'),
              ),
              hint: '0',
            ),

            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('contributeSheet_submitButton'),
              label: 'Gửi đóng góp',
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
