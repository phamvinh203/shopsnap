import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/snap_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../database/daos/recurring_expense_dao.dart';
import '../../../models/recurring_expense_model.dart';
import '../../../providers/recurring_expense_provider.dart';
import '../../../widgets/ui/app_bottom_sheet.dart';
import '../../../widgets/ui/app_button.dart';
import '../../../widgets/ui/app_snack_bar.dart';
import '../../../widgets/ui/app_text_field.dart';

/// Dữ liệu điền sẵn khi mở sheet từ gợi ý (AC 4.10) — tên + số tiền + ngày
/// đến hạn = ngày của lần mua gần nhất (đã chặn 1..28).
class RecurringExpensePrefill {
  final String name;
  final int amount;
  final int dueDay;

  const RecurringExpensePrefill({
    required this.name,
    required this.amount,
    required this.dueDay,
  });
}

/// Sheet thêm mới / sửa khoản định kỳ (M-2 AC 4.3/4.4).
///
/// Validation bắt buộc, lỗi INLINE tại field, vi phạm → KHÔNG lưu:
/// - Tên trim khác rỗng.
/// - Số tiền > 0 (VND nguyên).
/// - Ngày đến hạn 1..28 (tránh lệch tháng 30/31 — [ASSUMPTION] spec AC 4.3).
/// Kỳ mặc định `monthly` (UI đợt này chỉ mở monthly — out of scope yearly);
/// `remind_days_before` mặc định 1, chọn được 0–3.
class RecurringExpenseEditSheet extends ConsumerStatefulWidget {
  final RecurringExpense? existing;
  final RecurringExpensePrefill? prefill;

  const RecurringExpenseEditSheet({super.key, this.existing, this.prefill})
      : assert(
          existing == null || prefill == null,
          'Sheet là THÊM (prefill) hoặc SỬA (existing), không dùng cả hai',
        );

  static Future<void> showForCreate(
    BuildContext context, {
    RecurringExpensePrefill? prefill,
  }) {
    return AppBottomSheet.show(
      context: context,
      title: 'Thêm khoản định kỳ',
      builder: (_) => RecurringExpenseEditSheet(prefill: prefill),
    );
  }

  static Future<void> showForEdit(
    BuildContext context,
    RecurringExpense entry,
  ) {
    return AppBottomSheet.show(
      context: context,
      title: 'Sửa khoản định kỳ',
      builder: (_) => RecurringExpenseEditSheet(existing: entry),
    );
  }

  @override
  ConsumerState<RecurringExpenseEditSheet> createState() =>
      _RecurringExpenseEditSheetState();
}

class _RecurringExpenseEditSheetState
    extends ConsumerState<RecurringExpenseEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _dueDayCtrl;
  late int _remindDaysBefore;
  bool _saving = false;

  final _nameFocus = FocusNode();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final prefill = widget.prefill;
    _nameCtrl = TextEditingController(
      text: existing?.name ?? prefill?.name ?? '',
    );
    _amountCtrl = TextEditingController(
      text: existing != null ? '${existing.amount}' : (prefill == null ? '' : '${prefill.amount}'),
    );
    _dueDayCtrl = TextEditingController(
      text: existing != null
          ? '${existing.dueDay}'
          : (prefill == null ? '' : '${prefill.dueDay}'),
    );
    _remindDaysBefore =
        existing?.remindDaysBefore ?? AppConstants.recurringRemindDaysBeforeDefault;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nhập tên khoản';
    return null;
  }

  String? _validateAmount(String? v) {
    final amount = CurrencyFormatter.parse(v ?? '');
    if (amount <= 0) return 'Số tiền phải lớn hơn 0';
    return null;
  }

  String? _validateDueDay(String? v) {
    final day = int.tryParse((v ?? '').trim());
    if (day == null ||
        day < AppConstants.recurringDueDayMin ||
        day > AppConstants.recurringDueDayMax) {
      return 'Ngày đến hạn từ 1 đến 28';
    }
    return null;
  }

  Future<void> _save() async {
    // Validate inline tại field — vi phạm → KHÔNG gọi lưu (AC 4.3).
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final dto = CreateRecurringExpenseDto(
      name: _nameCtrl.text,
      amount: CurrencyFormatter.parse(_amountCtrl.text),
      dueDay: int.parse(_dueDayCtrl.text.trim()),
      remindDaysBefore: _remindDaysBefore,
    );

    final notifier = ref.read(recurringExpensesProvider.notifier);
    if (_isEdit) {
      await notifier.updateEntry(
        widget.existing!.id,
        name: dto.name,
        amount: dto.amount,
        dueDay: dto.dueDay,
        remindDaysBefore: dto.remindDaysBefore,
      );
    } else {
      final created = await notifier.add(dto);
      if (!mounted) return;
      if (created == null) {
        // Phòng thủ cuối (DAO từ chối) — không pop, cho user sửa lại.
        setState(() => _saving = false);
        AppSnackBar.show(context: context, message: 'Không lưu được khoản này.');
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
      key: const Key('recurringExpenseSheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          key: const Key('recurringSheet_nameField'),
          controller: _nameCtrl,
          focusNode: _nameFocus,
          autofocus: !_isEdit && _nameCtrl.text.isEmpty,
          label: 'Tên khoản (vd: Tiền mạng, Netflix)',
          textCapitalization: TextCapitalization.sentences,
          validator: _validateName,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('recurringSheet_amountField'),
          controller: _amountCtrl,
          label: 'Số tiền mỗi kỳ (VNĐ)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validateAmount,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('recurringSheet_dueDayField'),
          controller: _dueDayCtrl,
          label: 'Ngày đến hạn (1–28)',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          validator: _validateDueDay,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
          key: const Key('recurringSheet_remindField'),
          value: _remindDaysBefore,
          decoration: const InputDecoration(labelText: 'Nhắc trước'),
          items: [
            for (var d = AppConstants.recurringRemindDaysBeforeMin;
                d <= AppConstants.recurringRemindDaysBeforeMax;
                d++)
              DropdownMenuItem(
                value: d,
                child: Text(d == 0 ? 'Cùng ngày đến hạn' : 'Trước $d ngày'),
              ),
          ],
          onChanged: (v) =>
              setState(() => _remindDaysBefore = v ?? AppConstants.recurringRemindDaysBeforeDefault),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Nhắc lúc 09:00 với nội dung chung — chi tiết khoản chỉ hiện trong ứng dụng.',
          style: context.text.bodySmall
              ?.copyWith(color: context.snap.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const Key('recurringSheet_saveButton'),
          label: _isEdit ? 'Lưu thay đổi' : 'Thêm khoản',
          loading: _saving,
          onPressed: _save,
        ),
      ],
      ),
    );
  }
}
