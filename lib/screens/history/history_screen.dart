import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../database/daos/item_dao.dart';
import '../../models/item_model.dart';
import '../../providers/database_provider.dart';
import '../../widgets/ui/ui.dart';
import 'price_history_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

class _MonthKey {
  final int year, month;
  const _MonthKey(this.year, this.month);
  @override bool operator ==(Object o) => o is _MonthKey && o.year == year && o.month == month;
  @override int get hashCode => Object.hash(year, month);
}

final _monthProvider = FutureProvider.family<_MonthData, _MonthKey>((ref, key) async {
  final db  = await ref.watch(databaseProvider.future);
  return _MonthData.load(db, key.year, key.month);
});

class _DayTotal { final int day, total; const _DayTotal(this.day, this.total); }

class _MonthData {
  final List<_DayTotal> dailyTotals;
  final int             monthTotal;

  const _MonthData({required this.dailyTotals, required this.monthTotal});

  static Future<_MonthData> load(Database db, int year, int month) async {
    final from = DateTime(year, month, 1).millisecondsSinceEpoch;
    final to   = DateTime(year, month + 1, 1).millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT
        CAST((created_at - ?) / 86400000 AS INTEGER) + 1 AS day_of_month,
        SUM(price) AS total
      FROM items
      WHERE created_at >= ? AND created_at < ? AND is_deleted = 0
      GROUP BY day_of_month
      ORDER BY day_of_month
    ''', [from, from, to]);

    final dailyTotals = rows.map((r) => _DayTotal(
      r['day_of_month'] as int,
      (r['total'] as num).toInt(),
    )).toList();

    final monthTotal = dailyTotals.fold(0, (s, d) => s + d.total);
    return _MonthData(dailyTotals: dailyTotals, monthTotal: monthTotal);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _month     = DateTime.now();
  int?     _selectedDay;

  void _prevMonth() => setState(() {
        _month       = DateTime(_month.year, _month.month - 1);
        _selectedDay = null;
      });

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year < now.year || (_month.year == now.year && _month.month < now.month)) {
      setState(() {
        _month       = DateTime(_month.year, _month.month + 1);
        _selectedDay = null;
      });
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final key   = _MonthKey(_month.year, _month.month);
    final async = ref.watch(_monthProvider(key));

    return Scaffold(
      // Nền/appbar lấy từ theme (bỏ Colors.white + AppColors.bgMain hardcode).
      appBar: AppBar(
        title: const Text('Lịch sử chi tiêu'),
        actions: [
          TextButton.icon(
            onPressed: () {
              // Đáng lẽ là route go_router (memo R5) nhưng router ngoài phạm vi
              // phase này — giữ nguyên Navigator.push cũ.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PriceHistoryScreen()),
              );
            },
            icon: Icon(Icons.show_chart, size: 18, color: context.cs.primary),
            label: Text(
              'Biến động giá',
              style: context.text.labelLarge?.copyWith(
                color: context.cs.primary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Month navigator ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm + 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                Expanded(
                  child: Center(
                    child: Text(
                      DateHelper.formatMonthYear(_month),
                      style: context.text.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  icon:      const Icon(Icons.chevron_right),
                  onPressed: _isCurrentMonth ? null : _nextMonth,
                  disabledColor: context.snap.hairline,
                ),
              ]),
            ),
          ),

          // ── 4 state chuẩn: loading / error / data ────────────────────────
          async.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: SkeletonList(itemCount: 4, itemHeight: 120),
              ),
            ),
            // Không còn 'Lỗi: $e' — ErrorState + Thử lại invalidate đúng provider.
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ErrorState(
                  onRetry: () => ref.invalidate(_monthProvider(key)),
                ),
              ),
            ),
            data: (data) => _Body(
              month:        _month,
              data:         data,
              selectedDay:  _selectedDay,
              onDayTap:     (d) => setState(() =>
                  _selectedDay = _selectedDay == d ? null : d),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content body ──────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final DateTime  month;
  final _MonthData data;
  final int?      selectedDay;
  final ValueChanged<int> onDayTap;

  const _Body({
    required this.month,
    required this.data,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Monthly total — "thỏi mực" (đồng bộ ngôn ngữ hero summary):
        // light nền mực #1C1B17, dark #0E120D + hairline; KHÔNG gradient/glow.
        Builder(builder: (context) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final colors = context.snap;
          // #0E120D là hex proposal ghi rõ (3.6) cho hero dark — không có token.
          const Color heroBgDark = Color(0xFF0E120D);
          final Color heroBg = dark ? heroBgDark : AppColors.textPrimary;
          const Color cream = AppColors.bgMain;
          final Color creamDim = cream.withOpacity(0.7);
          return Container(
            margin:  const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: heroBg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: dark ? Border.all(color: colors.hairline) : null,
              boxShadow: dark ? AppShadows.cardDark : AppShadows.card,
            ),
            child: Row(children: [
              Icon(Icons.calendar_month, color: creamDim, size: 28),
              const SizedBox(width: AppSpacing.md),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tổng tháng',
                    style: context.text.bodySmall
                        ?.copyWith(color: creamDim, fontSize: 11)),
                MoneyText(
                  key: const Key('historyScreen_monthTotal'),
                  amount: data.monthTotal,
                  style: (context.text.titleMedium ?? const TextStyle()).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cream,
                  ),
                ),
              ]),
              const Spacer(),
              Text(
                '${data.dailyTotals.length} ngày có chi tiêu',
                style: context.text.bodySmall
                    ?.copyWith(color: cream.withOpacity(0.6), fontSize: 11),
              ),
            ]),
          );
        }),

        // ── Bar chart ────────────────────────────────────────────────────
        if (data.dailyTotals.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
            child: SectionHeader(title: 'Chi tiêu theo ngày'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
              child: Column(children: [
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      maxY:       (data.dailyTotals.map((d) => d.total).reduce((a, b) => a > b ? a : b) * 1.2),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            'Ngày ${group.x}\n${CurrencyFormatter.formatShort(rod.toY.toInt())}',
                            TextStyle(
                                color: context.cs.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        touchCallback: (_, response) {
                          final idx = response?.spot?.touchedBarGroupIndex;
                          if (idx != null && idx < data.dailyTotals.length) {
                            onDayTap(data.dailyTotals[idx].day);
                          }
                        },
                      ),
                      barGroups: data.dailyTotals.asMap().entries.map((e) {
                        final isSelected = e.value.day == selectedDay;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [BarChartRodData(
                            toY:          e.value.total.toDouble(),
                            color:        isSelected
                                ? context.cs.primary.withOpacity(0.45)
                                : context.cs.primary,
                            width:        10,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          )],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= data.dailyTotals.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '${data.dailyTotals[idx].day}',
                                style: context.text.bodySmall
                                    ?.copyWith(fontSize: 9),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData:   const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Affordance cho tương tác ẩn (memo Y1): chạm cột → xem items.
                Text(
                  'Chạm vào cột để xem vật phẩm của ngày đó',
                  key: const Key('historyScreen_chartHint'),
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ],

        // ── Selected day items ───────────────────────────────────────────
        if (selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
            child: SectionHeader(
              title: 'Ngày $selectedDay tháng ${month.month}'),
          ),
          _DayItemList(
            date: DateTime(month.year, month.month, selectedDay!),
            ref:  ref,
          ),
        ],

        if (data.monthTotal == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Tháng này chưa có chi tiêu',
              message: 'Chuyển qua tháng khác hoặc ghi nhanh món mới nhé!',
            ),
          ),

        const SizedBox(height: AppSpacing.xxxl),
      ]),
    );
  }
}

// ── Day item list ─────────────────────────────────────────────────────────────

class _DayItemList extends ConsumerWidget {
  final DateTime date;
  final WidgetRef ref;
  const _DayItemList({required this.date, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dayItemsProvider(date));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: SkeletonList(itemCount: 2, itemHeight: 64),
      ),
      // Không còn 'Lỗi: $e' — ErrorState compact + Thử lại.
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ErrorState(
          onRetry: () => ref.invalidate(_dayItemsProvider(date)),
        ),
      ),
      data: (items) => Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: context.snap.tintPrimary,
                child: Text(item.categoryIcon,
                    style: const TextStyle(fontSize: 18)),
              ),
              title:    Text(item.name, style: context.text.titleSmall),
              subtitle: Text(DateHelper.formatTime(item.createdAt),
                  style: context.text.bodySmall),
              trailing: MoneyText(amount: item.price, colored: true),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

final _dayItemsProvider = FutureProvider.family<List<ItemModel>, DateTime>((ref, date) async {
  final db = await ref.watch(databaseProvider.future);
  return ItemDao(db).findByDay(date);
});
