import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/ai_assistant_model.dart';
import '../../models/summary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/summary_provider.dart';
import '../../services/summary_api_service.dart';
import '../../widgets/ui/ui.dart';
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

    return Scaffold(
      // Nền + appbar lấy từ theme (không còn Colors.white hardcode).
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            floating:         true,
            surfaceTintColor: Colors.transparent,
            title: Text('Tổng kết chi tiêu',
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            // Xuất CSV cho kỳ đang xem — offline-first: chưa đăng nhập thì bấm
            // vẫn được, app mời đăng nhập (auth gate mềm như MainShell).
            actions: [
              if (_exporting)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  key: const Key('summaryScreen_exportButton'),
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

          // ── 4 state chuẩn: loading / error / empty / data ────────────────
          summaryAsync.when(
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
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(summaryProvider(params)),
                ),
              ),
            ),
            data: (summary) => summary.totalSpent == 0
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: _emptyMessage(_date, _period),
                      message: 'Ghi nhanh món vừa mua để xem tổng kết nhé!',
                      actionLabel: 'Thêm mặt hàng',
                      onAction: () => context.push('/add'),
                    ),
                  )
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

  String _emptyMessage(DateTime date, String period) {
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

  /// Xuất CSV của kỳ đang xem (khoảng ngày server-căn qua SummaryParams) vào
  /// thư mục Documents.
  ///
  /// Auth gate mềm (PO chốt 2026-09-14): chưa đăng nhập → snackbar mời đăng
  /// nhập có action điều hướng /login, không chặn việc dùng màn hình.
  /// Lỗi API → thông điệp tiếng Việt, không leak path/exception.
  Future<void> _exportCsv() async {
    if (_exporting) return;

    final authenticated =
        ref.read(authStateProvider).value?.isAuthenticated == true;
    if (!authenticated) {
      AppSnackBar.show(
        context: context,
        message: 'Đăng nhập để xuất dữ liệu chi tiêu ra file CSV',
        actionLabel: 'Đăng nhập',
        onAction: () => context.push('/login'),
      );
      return;
    }

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

      if (mounted) {
        // Không hiện path thô (dev-speak) — chỉ báo đã lưu ở thư mục tài liệu.
        AppSnackBar.show(
          context: context,
          message: 'Đã lưu file CSV trong thư mục tài liệu của thiết bị',
          tone: AppSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: 'Không xuất được CSV: ${apiErrorMessage(e)}',
          tone: AppSnackBarTone.danger,
        );
      }
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
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        child: SizedBox(
          height: 36,
          child: SegmentedButton<String>(
            selected:          {period},
            showSelectedIcon:  false,
            onSelectionChanged: (s) => onSelected(s.first),
            style: ButtonStyle(
              visualDensity: const VisualDensity(horizontal: -3, vertical: -2),
              textStyle: WidgetStatePropertyAll(
                context.text.labelSmall?.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    isToday ? 'Hôm nay' : DateHelper.formatDate(date),
                    style: context.text.titleSmall,
                  ),
                  if (!isToday)
                    Text(
                      DateHelper.formatDate(date),
                      style: context.text.bodySmall,
                    ),
                ]),
              ),
            ),
          ),
          IconButton(
            icon:      const Icon(Icons.chevron_right),
            onPressed: isToday ? null : onNext,
            disabledColor: context.snap.hairline,
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
          // ── Hero total card (duy nhất 1 gradient mỗi màn) ───────────────
          Container(
            key: const Key('summaryScreen_heroCard'),
            margin:  const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? AppShadows.cardDark
                  : AppShadows.glowPrimary,
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tổng chi tiêu',
                      style: context.text.bodySmall
                          ?.copyWith(color: Colors.white70)),
                  // Hero number 28sp/w800 tabular figures (memo mục 1.3).
                  MoneyText(
                    key: const Key('summaryScreen_heroTotal'),
                    amount: summary.totalSpent,
                    style: AppTypography.moneyOf(context.text,
                            size: 28, color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${summary.itemCount} vật phẩm',
                    style: context.text.bodySmall
                        ?.copyWith(color: Colors.white60),
                  ),
                  // So sánh với kỳ liền trước — chỉ có khi lấy được từ server
                  if (comparison != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Icon(_trendIcon(comparison!.trend),
                          color: Colors.white70, size: 14),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          _trendText(comparison!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall
                              ?.copyWith(color: Colors.white70),
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
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
              child: SectionHeader(title: 'Theo danh mục'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppCard(
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
                        sections:          _buildSections(context, summary),
                        centerSpaceRadius: 44,
                        sectionsSpace:     2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
              child: SectionHeader(title: 'Danh sách vật phẩm'),
            ),
            ...summary.items.map((item) => Padding(
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
                      title: Text(item.name, style: context.text.titleSmall),
                      subtitle: Text(DateHelper.formatTime(item.createdAt),
                          style: context.text.bodySmall),
                      trailing: MoneyText(
                        amount: item.price,
                        colored: true,
                      ),
                    ),
                  ),
                )),
          ],

          const SizedBox(height: AppSpacing.xxxl),
        ]),
      );

  List<PieChartSectionData> _buildSections(BuildContext context, SummaryModel summary) {
    final total = summary.totalSpent;
    return List.generate(summary.categories.length, (i) {
      final cat     = summary.categories[i];
      final isTouched = i == touchedIndex;
      final pct     = total > 0 ? cat.totalSpent / total * 100 : 0;
      Color color;
      try {
        color = Color(int.parse(cat.categoryColor.replaceFirst('#', '0xFF')));
      } catch (_) {
        color = context.cs.primary;
      }
      return PieChartSectionData(
        value:       cat.totalSpent.toDouble(),
        title:       isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        color:       color,
        radius:      isTouched ? 92 : 80,
        titleStyle:  TextStyle(
            color: context.cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 13),
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
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: List.generate(summary.categories.length, (i) {
          final cat = summary.categories[i];
          Color color;
          try {
            color = Color(int.parse(cat.categoryColor.replaceFirst('#', '0xFF')));
          } catch (_) {
            color = context.cs.primary;
          }
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${cat.categoryIcon} ${cat.categoryName}  ${CurrencyFormatter.formatShort(cat.totalSpent)}',
              style: (context.text.bodySmall ?? const TextStyle()).copyWith(
                fontWeight: i == touchedIndex ? FontWeight.w700 : FontWeight.w400,
                color: i == touchedIndex
                    ? context.cs.onSurface
                    : context.cs.onSurfaceVariant,
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
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
            child: SectionHeader(title: 'Gợi ý cho bạn'),
          ),
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _severityColor(context, insight.severity)
                          .withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_typeIcon(insight.type),
                        color: _severityColor(context, insight.severity),
                        size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(insight.title, style: context.text.titleSmall),
                          const SizedBox(height: 2),
                          Text(insight.message,
                              style: context.text.bodySmall),
                        ]),
                  ),
                ]),
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

  static Color _severityColor(BuildContext context, String severity) {
    switch (severity) {
      case 'warning':  return context.snap.warning;
      case 'positive': return context.snap.success;
      default:         return context.cs.primary; // info
    }
  }
}
