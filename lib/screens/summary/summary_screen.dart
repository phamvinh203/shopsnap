import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/summary_model.dart';
import '../../providers/summary_provider.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  DateTime _date = DateTime.now();
  int?     _touchedIndex;

  void _prevDay() => setState(() { _date = _date.subtract(const Duration(days: 1)); _touchedIndex = null; });
  void _nextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_date.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      setState(() { _date = _date.add(const Duration(days: 1)); _touchedIndex = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(summaryProvider(_date));
    final isToday = DateHelper.isSameDay(_date, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            floating:         true,
            backgroundColor:  Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('Tổng kết chi tiêu',
                style: TextStyle(fontWeight: FontWeight.w700)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _DateNavBar(
                date:    _date,
                isToday: isToday,
                onPrev:  _prevDay,
                onNext:  _nextDay,
                onPick:  _pickDate,
              ),
            ),
          ),

          summaryAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Lỗi: $e')),
            ),
            data: (summary) => summary.totalSpent == 0
                ? SliverFillRemaining(child: _EmptyState(date: _date))
                : _SummaryBody(
                    summary:      summary,
                    touchedIndex: _touchedIndex,
                    onTouch:      (i) => setState(() => _touchedIndex = i),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  _date,
      firstDate:    DateTime(2020),
      lastDate:     DateTime.now(),
    );
    if (picked != null) setState(() { _date = picked; _touchedIndex = null; });
  }
}

// ── Date nav bar ──────────────────────────────────────────────────────────────

class _DateNavBar extends StatelessWidget {
  final DateTime date;
  final bool     isToday;
  final VoidCallback onPrev, onNext, onPick;

  const _DateNavBar({
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    isToday ? 'Hôm nay' : DateHelper.formatDate(date),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (!isToday)
                    Text(
                      DateHelper.formatDate(date),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                ]),
              ),
            ),
          ),
          IconButton(
            icon:     const Icon(Icons.chevron_right),
            onPressed: isToday ? null : onNext,
            color:    isToday ? AppColors.divider : null,
          ),
        ]),
      );
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _SummaryBody extends StatelessWidget {
  final SummaryModel summary;
  final int?         touchedIndex;
  final ValueChanged<int?> onTouch;

  const _SummaryBody({
    required this.summary,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) => SliverList(
        delegate: SliverChildListDelegate([
          // ── Hero total card ─────────────────────────────────────────────
          Container(
            margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset:     const Offset(0, 6),
                ),
              ],
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white70, size: 36),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tổng chi tiêu',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  CurrencyFormatter.format(summary.totalSpent),
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${summary.itemCount} vật phẩm',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ]),
            ]),
          ),

          // ── Pie chart ───────────────────────────────────────────────────
          if (summary.categories.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('Theo danh mục',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Card(
              margin:      const EdgeInsets.symmetric(horizontal: 16),
              shape:       RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation:   0,
              color:       Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (_, response) {
                            onTouch(response?.touchedSection?.touchedSectionIndex);
                          },
                        ),
                        sections:          _buildSections(summary),
                        centerSpaceRadius: 44,
                        sectionsSpace:     2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Legend(summary: summary, touchedIndex: touchedIndex),
                ]),
              ),
            ),
          ],

          // ── Item list ───────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Danh sách vật phẩm',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          ...summary.items.map((item) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  elevation:   0,
                  color:       Colors.white,
                  shape:       RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(item.categoryIcon,
                          style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(DateHelper.formatTime(item.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: Text(
                      CurrencyFormatter.format(item.price),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   15,
                          color:      AppColors.primary),
                    ),
                  ),
                ),
              )),

          const SizedBox(height: 32),
        ]),
      );

  List<PieChartSectionData> _buildSections(SummaryModel summary) {
    final total = summary.totalSpent;
    return List.generate(summary.categories.length, (i) {
      final cat     = summary.categories[i];
      final isTouched = i == touchedIndex;
      final pct     = total > 0 ? cat.totalSpent / total * 100 : 0;
      Color color;
      try {
        color = Color(int.parse(cat.categoryColor.replaceFirst('#', '0xFF')));
      } catch (_) {
        color = AppColors.primary;
      }
      return PieChartSectionData(
        value:       cat.totalSpent.toDouble(),
        title:       isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        color:       color,
        radius:      isTouched ? 92 : 80,
        titleStyle:  const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
      );
    });
  }
}

class _Legend extends StatelessWidget {
  final SummaryModel summary;
  final int?         touchedIndex;
  const _Legend({required this.summary, this.touchedIndex});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 8,
        children: List.generate(summary.categories.length, (i) {
          final cat = summary.categories[i];
          Color color;
          try {
            color = Color(int.parse(cat.categoryColor.replaceFirst('#', '0xFF')));
          } catch (_) {
            color = AppColors.primary;
          }
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '${cat.categoryIcon} ${cat.categoryName}  ${CurrencyFormatter.formatShort(cat.totalSpent)}',
              style: TextStyle(
                fontSize:   11,
                fontWeight: i == touchedIndex ? FontWeight.w700 : FontWeight.w400,
                color:      i == touchedIndex ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ]);
        }),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DateTime date;
  const _EmptyState({required this.date});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🧾', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            DateHelper.isSameDay(date, DateTime.now())
                ? 'Hôm nay chưa có chi tiêu'
                : 'Không có chi tiêu ngày này',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color:      AppColors.textSecondary),
          ),
        ]),
      );
}
