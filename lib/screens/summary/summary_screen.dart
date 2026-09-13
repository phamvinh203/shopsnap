import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/ai_assistant_model.dart';
import '../../models/summary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/summary_provider.dart';
import '../../services/summary_api_service.dart';
import 'widgets/ai_assistant_card.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  DateTime _date = DateTime.now();
  String   _period = 'day'; // day | week | month | year
  int?     _touchedIndex;
  bool     _exporting = false;

  DateTime get _today => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  void _prevPeriod() => setState(() {
        _date = shiftDateByPeriod(_date, _period, -1);
        _touchedIndex = null;
      });

  void _nextPeriod() {
    final next = shiftDateByPeriod(_date, _period, 1);
    if (!next.isAfter(_today)) {
      setState(() { _date = next; _touchedIndex = null; });
    }
  }

  void _selectPeriod(String period) => setState(() {
        _period = period;
        _touchedIndex = null;
      });

  @override
  Widget build(BuildContext context) {
    final params       = SummaryParams(date: _date, period: _period);
    final summaryAsync = ref.watch(summaryProvider(params));
    // Response server thô → comparison/trend (summaryProvider đã merge số chính)
    final comparison   = ref.watch(serverSummaryProvider(params)).valueOrNull?.comparison;
    final insights     = ref.watch(summaryInsightsProvider(params)).valueOrNull ?? const <SpendingInsight>[];
    final aiAssistant  = ref.watch(aiAssistantProvider(SummaryParams.fmt(_date))).valueOrNull;
    final authenticated = ref.watch(authStateProvider).value?.isAuthenticated == true;

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
            // Xuất CSV cho kỳ đang xem — chỉ khi đã đăng nhập (API cần Bearer)
            actions: [
              if (authenticated)
                _exporting
                    ? const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton(
                        icon:     const Icon(Icons.download_outlined),
                        tooltip:  'Xuất CSV',
                        onPressed: _exportCsv,
                      ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(94),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _DateNavBar(
                  date:    _date,
                  isToday: DateHelper.isSameDay(_date, DateTime.now()),
                  onPrev:  _prevPeriod,
                  onNext:  _nextPeriod,
                  onPick:  _pickDate,
                ),
                _PeriodTabs(period: _period, onSelected: _selectPeriod),
              ]),
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
                ? SliverFillRemaining(child: _EmptyState(date: _date, period: _period))
                : _SummaryBody(
                    summary:      summary,
                    comparison:   comparison,
                    insights:     insights,
                    aiAssistant:  aiAssistant,
                    showItems:    _period == 'day', // API /summary không trả items
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

  /// Xuất CSV của kỳ đang xem (khoảng ngày server-căn qua SummaryParams) vào
  /// thư mục Documents rồi báo path qua snackbar. Lỗi API → thông điệp VN.
  Future<void> _exportCsv() async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);

    try {
      final range = SummaryParams(date: _date, period: _period).localRange;
      final csv = await ref.read(summaryApiServiceProvider).exportCsv(
        dateFrom: SummaryParams.fmt(range.$1),
        dateTo:   SummaryParams.fmt(range.$2),
      );

      final dir  = await getApplicationDocumentsDirectory();
      // Cùng quy ước tên file với Content-Disposition của backend (YYYY-MM)
      final path = '${dir.path}/shopsnap-export-${SummaryParams.fmt(range.$1).substring(0, 7)}.csv';
      await File(path).writeAsString(csv); // UTF-8 mặc định — giữ nguyên BOM \uFEFF

      messenger.showSnackBar(SnackBar(content: Text('Đã xuất CSV: $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content:         Text('Không xuất được CSV: ${apiErrorMessage(e)}'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ── Period tabs ───────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final String period;
  final ValueChanged<String> onSelected;

  const _PeriodTabs({required this.period, required this.onSelected});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          height: 36,
          child: SegmentedButton<String>(
            selected:          {period},
            showSelectedIcon:  false,
            onSelectionChanged: (s) => onSelected(s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -3, vertical: -2),
              textStyle: WidgetStatePropertyAll(TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ),
            segments: const [
              ButtonSegment(value: 'day',   label: Text('Ngày')),
              ButtonSegment(value: 'week',  label: Text('Tuần')),
              ButtonSegment(value: 'month', label: Text('Tháng')),
              ButtonSegment(value: 'year',  label: Text('Năm')),
            ],
          ),
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
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
  final SummaryComparison? comparison;
  final List<SpendingInsight> insights;
  final AiAssistantResponse? aiAssistant;
  final bool showItems;
  final int?         touchedIndex;
  final ValueChanged<int?> onTouch;

  const _SummaryBody({
    required this.summary,
    required this.comparison,
    required this.insights,
    this.aiAssistant,
    required this.showItems,
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
              gradient: const LinearGradient(
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  // So sánh với kỳ liền trước — chỉ có khi lấy được từ server
                  if (comparison != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(_trendIcon(comparison!.trend),
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _trendText(comparison!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),

          // ── AI Smart Shopping Assistant Card ────────────────────────────
          if (aiAssistant != null)
            AiAssistantCard(data: aiAssistant!),

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

          // ── Insights (server rule-based, đã là tiếng Việt) ──────────────
          if (insights.isNotEmpty) _InsightsSection(insights: insights),

          // ── Item list (chỉ kỳ ngày — API /summary không trả items) ──────
          if (showItems && summary.items.isNotEmpty) ...[
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
          ],

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

  static IconData _trendIcon(String trend) {
    switch (trend) {
      case 'up':   return Icons.trending_up;
      case 'down': return Icons.trending_down;
      default:     return Icons.trending_flat;
    }
  }

  static String _trendText(SummaryComparison c) {
    switch (c.trend) {
      case 'up':
        return c.changePercentage != null
            ? '+${c.changePercentage!.toStringAsFixed(0)}% so với kỳ trước'
            : 'Tăng so với kỳ trước';
      case 'down':
        return c.changePercentage != null
            ? '${c.changePercentage!.toStringAsFixed(0)}% so với kỳ trước'
            : 'Giảm so với kỳ trước';
      default:
        return 'Ngang bằng kỳ trước';
    }
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

// ── Insights section ──────────────────────────────────────────────────────────

class _InsightsSection extends StatelessWidget {
  final List<SpendingInsight> insights;
  const _InsightsSection({required this.insights});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Gợi ý cho bạn',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                elevation:   0,
                color:       Colors.white,
                shape:       RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: _severityColor(insight.severity).withOpacity(0.12),
                    child: Icon(_typeIcon(insight.type),
                        color: _severityColor(insight.severity), size: 20),
                  ),
                  title: Text(insight.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(insight.message,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ),
            ),
        ],
      );

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'budget_warning': return Icons.warning_amber_rounded;
      case 'over_budget':    return Icons.error_outline;
      case 'category_spike': return Icons.trending_up;
      case 'best_day':       return Icons.savings_outlined;
      default:               return Icons.lightbulb_outline;
    }
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case 'warning':  return AppColors.warning;
      case 'positive': return AppColors.success;
      default:         return AppColors.primary; // info
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DateTime date;
  final String   period;
  const _EmptyState({required this.date, required this.period});

  String get _message {
    switch (period) {
      case 'week':  return 'Tuần này chưa có chi tiêu';
      case 'month': return 'Tháng này chưa có chi tiêu';
      case 'year':  return 'Năm nay chưa có chi tiêu';
      default:
        return DateHelper.isSameDay(date, DateTime.now())
            ? 'Hôm nay chưa có chi tiêu'
            : 'Không có chi tiêu ngày này';
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🧾', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            _message,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color:      AppColors.textSecondary),
          ),
        ]),
      );
}
