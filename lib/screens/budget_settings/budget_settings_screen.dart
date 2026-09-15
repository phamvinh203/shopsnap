import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/budget_insights.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../providers/all_budgets_provider.dart';
import '../../providers/categories_provider.dart';
import '../../widgets/ui/ui.dart';

class BudgetSettingsScreen extends ConsumerWidget {
  const BudgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(allBudgetsProvider);
    final catsAsync    = ref.watch(categoriesProvider);

    return Scaffold(
      // Nền/appbar lấy từ theme (bỏ Colors.white + AppColors.bgMain hardcode).
      appBar: AppBar(title: const Text('Cài đặt ngân sách')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('budgetSettings_fab'),
        onPressed: () => _showAddSheet(context, ref,
            cats: catsAsync.valueOrNull ?? []),
        icon:  const Icon(Icons.add),
        label: const Text('Thêm ngân sách'),
      ),
      body: budgetsAsync.when(
        // Skeleton thay spinner trần (memo S3).
        loading: () => const SingleChildScrollView(
          // Cuộn được để không tràn trên màn hình thấp.
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SkeletonList(itemCount: 4, itemHeight: 150),
          ),
        ),
        // Không còn 'Lỗi: $e' — ErrorState + Thử lại invalidate đúng provider.
        error: (_, __) => ErrorState(
          key: const Key('budgetSettings_errorState'),
          onRetry: () => ref.invalidate(allBudgetsProvider),
        ),
        data: (budgets) => budgets.isEmpty
            ? EmptyState(
                key: const Key('budgetSettings_emptyState'),
                icon: Icons.savings_outlined,
                title: 'Chưa có ngân sách nào',
                message: 'Tạo ngân sách để theo dõi chi tiêu',
                actionLabel: 'Thêm ngân sách đầu tiên',
                onAction: () => _showAddSheet(context, ref,
                    cats: catsAsync.valueOrNull ?? []),
              )
            : RefreshIndicator(
                color: context.cs.primary,
                onRefresh: () async => ref.invalidate(allBudgetsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
                  itemCount:   budgets.length,
                  itemBuilder: (_, i) => _BudgetCard(
                    status: budgets[i],
                    cats:   catsAsync.valueOrNull ?? [],
                    onEdit: () => _showEditSheet(context, ref, budgets[i],
                        cats: catsAsync.valueOrNull ?? []),
                    onDelete: () =>
                        _confirmDelete(context, ref, budgets[i].budget.id),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Add sheet ────────────────────────────────────────────────────────────

  void _showAddSheet(BuildContext context, WidgetRef ref,
      {required List<CategoryModel> cats}) {
    AppBottomSheet.show<void>(
      context: context,
      title: 'Thêm ngân sách',
      builder: (_) => _BudgetFormSheet(
        cats: cats,
        // Ném lỗi lên sheet tự bắt → sheet không đóng, snackbar hiện lỗi
        onSave: (amount, period, catId) =>
            ref.read(allBudgetsProvider.notifier).addBudget(
              amount:     amount,
              period:     period,
              categoryId: catId,
            ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, BudgetStatus status,
      {required List<CategoryModel> cats}) {
    AppBottomSheet.show<void>(
      context: context,
      title: 'Sửa ngân sách',
      builder: (_) => _BudgetFormSheet(
        cats:          cats,
        initialAmount: status.budget.amount,
        initialPeriod: status.budget.period,
        initialCatId:  status.budget.categoryId,
        isEdit:        true,
        onSave: (amount, _, __) =>
            ref.read(allBudgetsProvider.notifier).updateAmount(
              status.budget.id, amount),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Xoá ngân sách',
      message: 'Bạn có chắc muốn xoá ngân sách này không?',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(allBudgetsProvider.notifier).deleteBudget(id);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }
}

/// Snackbar lỗi tiếng Việt chung cho screen (lỗi nghiệp vụ từ server khi
/// online: trùng kỳ, allocated > total, ngày không hợp lệ...).
void _showError(BuildContext context, Object error) {
  AppSnackBar.show(
    context: context,
    message: apiErrorMessage(error),
    tone: AppSnackBarTone.danger,
  );
}

// ── Budget card ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetStatus status;
  final List<CategoryModel> cats;
  final VoidCallback onEdit, onDelete;

  const _BudgetCard({
    required this.status,
    required this.cats,
    required this.onEdit,
    required this.onDelete,
  });

  /// F-#3: insights cho budget này (category lẫn tổng) — `null` khi thiếu
  /// kỳ hợp lệ → ẩn strip, card render như cũ.
  BudgetInsights? _insightsFor(BudgetStatus s) {
    if (s.budget.amount <= 0) return null;
    final start = tryParseBudgetDate(s.budget.startDate);
    final end = tryParseBudgetDate(s.budget.endDate);
    if (start == null || end == null) return null;
    return computeBudgetInsights(
      spent: s.spent,
      budget: s.budget.amount,
      periodStart: start,
      periodEnd: end,
      now: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;
    final b     = status.budget;
    final level = budgetLevelFromRatio(status.usageRatio);
    final color = colors.colorFor(level);
    final catName = b.categoryId != null
        ? (cats.firstWhere((c) => c.id == b.categoryId,
                orElse: () => const CategoryModel(
                    id: '',
                    name: 'Khác',
                    icon: '🛍',
                    color: '#6C63FF',
                    isDefault: false,
                    sortOrder: 0,
                    createdAt: 0))
            .name)
        : 'Tất cả danh mục';
    final periodLabel = switch (b.period) {
      BudgetPeriod.day => 'Hôm nay',
      BudgetPeriod.week => 'Tuần này',
      BudgetPeriod.month => 'Tháng này',
      BudgetPeriod.custom => 'Tuỳ chỉnh', // chỉ có ở server, không persist
    };

    return Padding(
      // AppCard không có margin — card list tự cách nhau bằng padding.
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        key: Key('budgetSettings_card_${b.id}'),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.tintPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(periodLabel,
                        style: context.text.labelLarge?.copyWith(
                            color: colors.onTintPrimary, fontSize: 11)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(catName,
                        style: context.text.bodySmall?.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xs + 2),
                Row(children: [
                  // Mực đã tiêu — tô màu semantic theo ngưỡng 80%/100%
                  // (map qua budgetLevelFromRatio, không hardcode hex).
                  Text(
                    CurrencyFormatter.format(status.spent),
                    key: Key('budgetSettings_spent_${b.id}'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: color),
                  ),
                  Text(' / ${CurrencyFormatter.format(b.amount)}',
                      style: context.text.bodySmall),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Xoá',
                        style: TextStyle(color: context.snap.danger))),
              ],
            ),
          ]),
          const SizedBox(height: AppSpacing.md - 2),
          // Bar + % badge — màu map qua budgetLevelFromRatio ở MỘT chỗ.
          BudgetProgressBar(
            key: Key('budgetSettings_progress_${b.id}'),
            spent: status.spent,
            total: b.amount,
            compact: true,
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            status.isDanger
                ? 'Đã vượt ngân sách!'
                : 'Còn lại: ${CurrencyFormatter.format(status.remaining.clamp(0, b.amount))}',
            style: context.text.bodySmall?.copyWith(
                color: status.isDanger ? colors.danger : null,
                fontWeight: status.isDanger ? FontWeight.w700 : null),
          ),
          // F-#3 (AC 3.9): ngân sách category dùng CÙNG bộ 3 chỉ số
          // burn rate / safe daily / forecast — cùng pure logic với hero card.
          // Strip tự ẩn khi ngày cuối kỳ / ngoài kỳ (AC 3.7).
          if (_insightsFor(status) != null) ...[
            const SizedBox(height: AppSpacing.sm),
            BudgetInsightsStrip(insights: _insightsFor(status)!),
          ],
        ]),
      ),
    );
  }
}

// ── Form sheet ────────────────────────────────────────────────────────────────

class _BudgetFormSheet extends StatefulWidget {
  final List<CategoryModel> cats;
  final int? initialAmount;
  final BudgetPeriod? initialPeriod;
  final String? initialCatId;
  final bool isEdit;

  /// Lưu form — Future hoàn tất = thành công; ném lỗi = giữ sheet mở để
  /// người dùng sửa lại (lỗi nghiệp vụ server khi online: trùng kỳ...).
  final Future<void> Function(int amount, BudgetPeriod period, String? catId)
      onSave;

  const _BudgetFormSheet({
    required this.cats,
    required this.onSave,
    this.initialAmount,
    this.initialPeriod,
    this.initialCatId,
    this.isEdit = false,
  });

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late final TextEditingController _amountCtrl;
  final _formKey = GlobalKey<FormState>();
  late BudgetPeriod _period;
  String? _catId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.initialAmount?.toString() ?? '');
    _period = widget.initialPeriod ?? BudgetPeriod.day;
    _catId  = widget.initialCatId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount — FIX bug validate im lặng (memo B2, budget_settings cũ
            // dòng 398: amount rỗng/≤0 thì `return;` im lặng): giờ có validator
            // hiện lỗi dưới field + snackbar danger khi bấm lưu.
            AppTextField(
              key: const Key('budgetSheet_amountField'),
              controller: _amountCtrl,
              label: 'Số tiền ngân sách',
              hint: '500000',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: Icons.wallet_outlined,
              suffix: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: Text('đ'),
              ),
              validator: (v) =>
                  (int.tryParse(v?.trim() ?? '') ?? 0) <= 0
                      ? 'Số tiền ngân sách phải lớn hơn 0'
                      : null,
            ),

            if (!widget.isEdit) ...[
              const SizedBox(height: AppSpacing.lg),

              // Period
              Text('Chu kỳ', style: context.text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<BudgetPeriod>(
                segments: const [
                  ButtonSegment(value: BudgetPeriod.day, label: Text('Ngày')),
                  ButtonSegment(value: BudgetPeriod.week, label: Text('Tuần')),
                  ButtonSegment(
                      value: BudgetPeriod.month, label: Text('Tháng')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Category
              Text('Danh mục (tuỳ chọn)', style: context.text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                value: _catId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Tất cả danh mục')),
                  ...widget.cats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.icon} ${c.name}'),
                      )),
                ],
                onChanged: (v) => setState(() => _catId = v),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('budgetSheet_submitButton'),
              label: widget.isEdit ? 'Cập nhật' : 'Tạo ngân sách',
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      );

  /// Gửi form: validation local lỗi → hiện rõ lỗi dưới field + snackbar
  /// (không còn im lặng). Thành công → đóng sheet; lỗi server → giữ sheet +
  /// snackbar tiếng Việt.
  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (!valid || amount == null || amount <= 0) {
      // FIX memo B2: báo lỗi rõ ràng thay vì `return;` im lặng.
      AppSnackBar.show(
        context: context,
        message: 'Số tiền ngân sách phải lớn hơn 0',
        tone: AppSnackBarTone.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(amount, _period, _catId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
