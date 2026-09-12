import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/api_error_messages.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/barcode_provider.dart';
import '../../../services/barcode_contribute_service.dart';

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
          const Text('Đóng góp thông tin sản phẩm',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Giúp cộng đồng ShopSnap biết sản phẩm của mã này',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Barcode — chỉ hiển thị, không sửa
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(children: [
              const Icon(Icons.qr_code_2, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.barcode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Tên sản phẩm — bắt buộc (backend yêu cầu)
          const Text('Tên sản phẩm *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            maxLength: 255,
            autofocus: (widget.initialName ?? '').isEmpty,
            textCapitalization: TextCapitalization.sentences,
            buildCounter: (_, {required currentLength, required isFocused, int? maxLength}) => null,
            decoration: InputDecoration(
              hintText:   'VD: Sữa tươi Vinamilk 1L...',
              prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
              errorText:  _error,
            ),
          ),

          const SizedBox(height: 8),

          // Giá tiền — tuỳ chọn
          const Text('Giá tiền (đ) — tuỳ chọn',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText:   '0',
              prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
              suffixText: 'đ',
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Gửi đóng góp'),
            ),
          ),
        ],
      ),
    ),
  );
}
