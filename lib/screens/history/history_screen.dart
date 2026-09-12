import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../database/daos/item_dao.dart';
import '../../models/item_model.dart';
import '../../providers/database_provider.dart';

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
    final key      = _MonthKey(_month.year, _month.month);
    final async    = ref.watch(_monthProvider(key));

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor:  Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Lịch sử chi tiêu',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Month navigator ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                Expanded(
                  child: Center(
                    child: Text(
                      DateHelper.formatMonthYear(_month),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon:      const Icon(Icons.chevron_right),
                  onPressed: _isCurrentMonth ? null : _nextMonth,
                  color:     _isCurrentMonth ? AppColors.divider : null,
                ),
              ]),
            ),
          ),

          async.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Lỗi: $e')),
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
        // ── Monthly total ────────────────────────────────────────────────
        Container(
          margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month, color: Colors.white70, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tổng tháng',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(
                CurrencyFormatter.format(data.monthTotal),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
              ),
            ]),
            const Spacer(),
            Text(
              '${data.dailyTotals.length} ngày có chi tiêu',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ]),
        ),

        // ── Bar chart ────────────────────────────────────────────────────
        if (data.dailyTotals.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Chi tiêu theo ngày',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          Card(
            margin:    const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
            color:     Colors.white,
            shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY:       (data.dailyTotals.map((d) => d.total).reduce((a, b) => a > b ? a : b) * 1.2),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          'Ngày ${group.x}\n${CurrencyFormatter.formatShort(rod.toY.toInt())}',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
                          color:        isSelected ? AppColors.accent : AppColors.primary,
                          width:        10,
                          borderRadius: BorderRadius.circular(4),
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
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textSecondary),
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
            ),
          ),
        ],

        // ── Selected day items ───────────────────────────────────────────
        if (selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Ngày $selectedDay tháng ${month.month}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          _DayItemList(
            date: DateTime(month.year, month.month, selectedDay!),
            ref:  ref,
          ),
        ],

        if (data.totalSpent == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('📭', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Tháng này chưa có chi tiêu',
                    style: TextStyle(color: AppColors.textSecondary)),
              ]),
            ),
          ),

        const SizedBox(height: 32),
      ]),
    );
  }
}

extension on _MonthData {
  int get totalSpent => monthTotal;
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
        padding: EdgeInsets.all(24),
        child:   Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Lỗi: $e'),
      data: (items) => Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            elevation: 0,
            color:     Colors.white,
            shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Text(item.categoryIcon,
                    style: const TextStyle(fontSize: 18)),
              ),
              title:    Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(DateHelper.formatTime(item.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: Text(
                CurrencyFormatter.format(item.price),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color:      AppColors.primary),
              ),
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
