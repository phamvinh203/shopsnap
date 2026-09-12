import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../providers/all_budgets_provider.dart';
import '../../providers/categories_provider.dart';

class BudgetSettingsScreen extends ConsumerWidget {
  const BudgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(allBudgetsProvider);
    final catsAsync    = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor:  Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Cài đặt ngân sách',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref,
            cats: catsAsync.valueOrNull ?? []),
        icon:  const Icon(Icons.add),
        label: const Text('Thêm ngân sách'),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Lỗi: $e')),
        data:    (budgets) => budgets.isEmpty
            ? _EmptyBudget(onAdd: () => _showAddSheet(context, ref,
                cats: catsAsync.valueOrNull ?? []))
            : ListView.builder(
                padding:     const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount:   budgets.length,
                itemBuilder: (_, i) => _BudgetCard(
                  status: budgets[i],
                  cats:   catsAsync.valueOrNull ?? [],
                  onEdit: () => _showEditSheet(context, ref, budgets[i],
                      cats: catsAsync.valueOrNull ?? []),
                  onDelete: () => _confirmDelete(context, ref, budgets[i].budget.id),
                ),
              ),
      ),
    );
  }

  // ── Add sheet ────────────────────────────────────────────────────────────

  void _showAddSheet(BuildContext context, WidgetRef ref,
      {required List<CategoryModel> cats}) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _BudgetFormSheet(
        cats:    cats,
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
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _BudgetFormSheet(
        cats:         cats,
        initialAmount: status.budget.amount,
        initialPeriod: status.budget.period,
        initialCatId:  status.budget.categoryId,
        isEdit:        true,
        onSave:        (amount, _, __) =>
            ref.read(allBudgetsProvider.notifier).updateAmount(
              status.budget.id, amount),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Xoá ngân sách'),
        content: const Text('Bạn có chắc muốn xoá ngân sách này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          TextButton(
            onPressed:  () => Navigator.pop(context, true),
            child: const Text('Xoá', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(allBudgetsProvider.notifier).deleteBudget(id);
    }
  }
}

// ── Budget card ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetStatus     status;
  final List<CategoryModel> cats;
  final VoidCallback     onEdit, onDelete;

  const _BudgetCard({
    required this.status,
    required this.cats,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final b        = status.budget;
    final ratio    = status.usageRatio.clamp(0.0, 1.0);
    final color    = status.isDanger
        ? AppColors.danger
        : status.isWarning
            ? AppColors.warning
            : AppColors.success;
    final catName  = b.categoryId != null
        ? (cats.firstWhere((c) => c.id == b.categoryId,
                orElse: () => const CategoryModel(id: '', name: 'Khác', icon: '🛍',
                    color: '#6C63FF', isDefault: false, sortOrder: 0, createdAt: 0))
              .name)
        : 'Tất cả danh mục';
    final periodLabel = switch (b.period) {
      BudgetPeriod.day   => 'Hôm nay',
      BudgetPeriod.week  => 'Tuần này',
      BudgetPeriod.month => 'Tháng này',
    };

    return Card(
      margin:    const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color:     Colors.white,
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(periodLabel,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(catName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text(CurrencyFormatter.format(status.spent),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   18,
                          color:      color)),
                  Text(' / ${CurrencyFormatter.format(b.amount)}',
                      style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 13)),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',   child: Text('Sửa')),
                const PopupMenuItem(value: 'delete',
                    child: Text('Xoá', style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:             ratio,
              backgroundColor:   color.withOpacity(0.12),
              valueColor:        AlwaysStoppedAnimation(color),
              minHeight:         7,
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              status.isDanger
                  ? 'Đã vượt ngân sách!'
                  : 'Còn lại: ${CurrencyFormatter.format(status.remaining)}',
              style: TextStyle(
                  color:      status.isDanger ? AppColors.danger : AppColors.textSecondary,
                  fontSize:   11,
                  fontWeight: status.isDanger ? FontWeight.w700 : FontWeight.w400),
            ),
            Text(
              '${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  color:      color,
                  fontSize:   11,
                  fontWeight: FontWeight.w700),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Form sheet ────────────────────────────────────────────────────────────────

class _BudgetFormSheet extends StatefulWidget {
  final List<CategoryModel> cats;
  final int?          initialAmount;
  final BudgetPeriod? initialPeriod;
  final String?       initialCatId;
  final bool          isEdit;
  final void Function(int amount, BudgetPeriod period, String? catId) onSave;

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
  late BudgetPeriod _period;
  String? _catId;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.initialAmount?.toString() ?? '');
    _period = widget.initialPeriod ?? BudgetPeriod.day;
    _catId  = widget.initialCatId;
  }

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding:    const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize:      MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),
              Text(widget.isEdit ? 'Sửa ngân sách' : 'Thêm ngân sách',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),

              // Amount
              const Text('Số tiền ngân sách',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller:     _amountCtrl,
                keyboardType:   TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText:   '500000',
                  prefixIcon: Icon(Icons.wallet_outlined, color: AppColors.primary),
                  suffixText: 'đ',
                ),
              ),

              if (!widget.isEdit) ...[
                const SizedBox(height: 16),

                // Period
                const Text('Chu kỳ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                SegmentedButton<BudgetPeriod>(
                  segments: const [
                    ButtonSegment(value: BudgetPeriod.day,   label: Text('Ngày')),
                    ButtonSegment(value: BudgetPeriod.week,  label: Text('Tuần')),
                    ButtonSegment(value: BudgetPeriod.month, label: Text('Tháng')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),

                const SizedBox(height: 16),

                // Category
                const Text('Danh mục (tuỳ chọn)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value:     _catId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary),
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

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = int.tryParse(_amountCtrl.text.trim());
                    if (amount == null || amount <= 0) return;
                    widget.onSave(amount, _period, _catId);
                    Navigator.pop(context);
                  },
                  child: Text(widget.isEdit ? 'Cập nhật' : 'Tạo ngân sách'),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBudget extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBudget({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💰', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Chưa có ngân sách nào',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tạo ngân sách để theo dõi chi tiêu',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon:  const Icon(Icons.add),
            label: const Text('Thêm ngân sách đầu tiên'),
          ),
        ]),
      );
}
