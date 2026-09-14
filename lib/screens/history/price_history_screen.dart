import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/price_history_model.dart';
import '../../providers/price_history_provider.dart';
import '../../widgets/ui/ui.dart';
import '../scan/scan_screen.dart';

class PriceHistoryScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialBarcode;

  const PriceHistoryScreen({
    super.key,
    this.initialQuery,
    this.initialBarcode,
  });

  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null || widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedPriceQueryProvider.notifier).state = PriceHistoryQuery(
          name: widget.initialQuery,
          barcode: widget.initialBarcode,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    final query = value.trim();
    if (query.isNotEmpty) {
      ref.read(selectedPriceQueryProvider.notifier).state = PriceHistoryQuery(name: query);
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && result['barcode'] != null) {
      final code = result['barcode'] as String;
      _searchCtrl.text = code;
      ref.read(selectedPriceQueryProvider.notifier).state = PriceHistoryQuery(barcode: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuery = ref.watch(selectedPriceQueryProvider);
    final frequentItemsAsync = ref.watch(frequentTrackedItemsProvider);

    return Scaffold(
      // Nền/appbar lấy từ theme (bỏ Colors.white + AppColors.bgMain hardcode).
      appBar: AppBar(
        title: const Text('Biến động giá sản phẩm'),
      ),
      body: Column(
        children: [
          // ── Khung tìm kiếm & nút quét barcode ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm + 4),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: _onSearch,
                    onChanged: (_) => setState(() {}),
                    prefixIcon: Icons.search,
                    suffix: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            key: const Key('priceHistory_clearSearch'),
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(selectedPriceQueryProvider.notifier).state = null;
                              setState(() {});
                            },
                          )
                        : null,
                    hint: 'Nhập tên hoặc mã vạch sản phẩm...',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Nút quét mã — nền tint pine, icon onTintPrimary (token),
                // touch target chuẩn ≥ 48dp.
                Material(
                  color: context.snap.tintPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    key: const Key('priceHistory_scanButton'),
                    onTap: _scanBarcode,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: AppSizes.touchTarget,
                      height: AppSizes.touchTarget,
                      child: Icon(Icons.qr_code_scanner,
                          size: 24, color: context.snap.onTintPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Danh sách gợi ý mặt hàng hay mua ─────────────────────────────
          frequentItemsAsync.when(
            data: (frequent) {
              if (frequent.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 34,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  scrollDirection: Axis.horizontal,
                  itemCount: frequent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (ctx, idx) {
                    final item = frequent[idx];
                    final isSelected = currentQuery?.name == item.itemName ||
                        (currentQuery?.barcode != null && currentQuery?.barcode == item.barcode);
                    // Chip gợi ý — selected = lime bút dạ + chữ ink (cùng
                    // ngôn ngữ CategoryChip; chỉ đổi màu, không đụng logic).
                    return ChoiceChip(
                      label: Text(
                        item.itemName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? context.snap.onAccent
                              : context.cs.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: context.snap.accent,
                      backgroundColor: context.cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : context.snap.hairline,
                      ),
                      onSelected: (_) {
                        _searchCtrl.text = item.itemName;
                        ref.read(selectedPriceQueryProvider.notifier).state = PriceHistoryQuery(
                          name: item.itemName,
                          barcode: item.barcode,
                        );
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            // Gợi ý là affordance phụ (data local + server tuỳ chọn) — khi lỗi
            // vẫn hiện hàng mảnh có nút thử lại thay vì biến mất lặng lẽ.
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Row(children: [
                Icon(Icons.cloud_off_outlined,
                    size: 16, color: context.cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text('Chưa tải được gợi ý', style: context.text.bodySmall),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  key: const Key('priceHistory_retrySuggestions'),
                  onTap: () => ref.invalidate(frequentTrackedItemsProvider),
                  child: Text(
                    'Thử lại',
                    style: context.text.labelLarge
                        ?.copyWith(color: context.cs.primary, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),

          // ── Nội dung chính: Biểu đồ và Lịch sử giá ───────────────────────
          Expanded(
            child: currentQuery == null
                ? _buildEmptyPrompt(context)
                : ref.watch(priceHistorySummaryProvider(currentQuery)).when(
                    data: (summary) {
                      if (summary == null || summary.points.isEmpty) {
                        return _buildNotFound(context, currentQuery);
                      }
                      return _buildSummaryContent(context, summary);
                    },
                    // Skeleton thay spinner trần (memo S3).
                    loading: () => const SingleChildScrollView(
                      // Cuộn được để không tràn trên màn hình thấp.
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: SkeletonList(itemCount: 3, itemHeight: 120),
                    ),
                    // Không còn 'Lỗi tải dữ liệu: $err' — ErrorState + Thử lại.
                    error: (_, __) => ErrorState(
                      onRetry: () => ref.invalidate(
                          priceHistorySummaryProvider(currentQuery)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrompt(BuildContext context) {
    return const EmptyState(
      icon: Icons.show_chart,
      title: 'Theo dõi biến động giá',
      message:
          'Chọn sản phẩm ở danh sách gợi ý phía trên hoặc quét mã vạch để xem xu hướng giá qua các lần mua sắm.',
    );
  }

  Widget _buildNotFound(BuildContext context, PriceHistoryQuery query) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'Chưa có lịch sử giá',
      message: 'Không tìm thấy dữ liệu giá cho "${query.name ?? query.barcode}"',
    );
  }

  Widget _buildSummaryContent(BuildContext context, PriceHistorySummary summary) {
    final hasMultiplePoints = summary.points.length >= 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card ────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.itemName.toUpperCase(),
                            style: context.text.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (summary.barcode != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Mã vạch: ${summary.barcode}',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildTrendBadge(context, summary),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Giá mua gần nhất', style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                MoneyText(
                  key: const Key('priceHistory_latestPrice'),
                  amount: summary.latestPrice,
                  colored: true,
                  style: (context.text.titleMedium ?? const TextStyle())
                      .copyWith(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md + 2),

                // 3 Mini stats: Thấp nhất, Cao nhất, Trung bình
                Row(
                  children: [
                    _MiniStat(
                      label: 'Thấp nhất',
                      value: summary.minPrice,
                      color: context.snap.success,
                    ),
                    _MiniStat(
                      label: 'Cao nhất',
                      value: summary.maxPrice,
                      color: context.snap.danger,
                    ),
                    _MiniStat(
                      label: 'Trung bình',
                      value: summary.avgPrice,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Biểu đồ đường biến động giá (LineChart) ────────────────────
          Text('Xu hướng giá theo thời gian', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.md - 2),

          AppCard(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
            child: SizedBox(
              height: 200,
              child: hasMultiplePoints
                  ? _buildLineChart(context, summary)
                  : Center(
                      child: Text(
                        'Cần ít nhất 2 lần mua để vẽ biểu đồ biến động giá.',
                        style: context.text.bodySmall,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Danh sách lịch sử các lần mua ──────────────────────────────
          SectionHeader(
            title: 'Lịch sử các lần mua',
            trailing: Text(
              '${summary.totalRecords} lần',
              style: context.text.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md - 2),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.points.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (ctx, idx) {
              // Điểm trong summary.points đang xếp từ cũ đến mới → đảo ngược để hiện mới nhất ở trên
              final point = summary.points[summary.points.length - 1 - idx];
              final prevPoint = idx < summary.points.length - 1
                  ? summary.points[summary.points.length - 2 - idx]
                  : null;

              final diff = prevPoint != null ? point.price - prevPoint.price : null;

              return AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.snap.tintPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(Icons.shopping_bag_outlined,
                          color: context.snap.onTintPrimary, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateHelper.formatDate(point.purchasedAt),
                            style: context.text.titleSmall
                                ?.copyWith(fontSize: 13),
                          ),
                          Text(
                            point.storeName ?? 'Cửa hàng / Siêu thị',
                            style: context.text.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(
                          amount: point.price,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (diff != null && diff != 0)
                          Text(
                            diff > 0
                                ? '+${CurrencyFormatter.format(diff)} 🔺'
                                : '${CurrencyFormatter.format(diff)} 🟢',
                            style: context.text.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: diff > 0
                                  ? context.snap.danger
                                  : context.snap.success,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildTrendBadge(BuildContext context, PriceHistorySummary summary) {
    final colors = context.snap;
    if (summary.trend == PriceTrend.up) {
      final pct = summary.priceChangePercent != null ? '+${summary.priceChangePercent}%' : '';
      return _TrendBadge(
        color: colors.danger,
        icon: Icons.trending_up,
        label: 'Tăng $pct',
      );
    } else if (summary.trend == PriceTrend.down) {
      final pct = summary.priceChangePercent != null ? '${summary.priceChangePercent}%' : '';
      return _TrendBadge(
        color: colors.success,
        icon: Icons.trending_down,
        label: 'Giảm $pct',
      );
    } else {
      return _TrendBadge(
        color: context.cs.onSurfaceVariant,
        label: 'Giá ổn định',
      );
    }
  }

  Widget _buildLineChart(BuildContext context, PriceHistorySummary summary) {
    final spots = summary.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.price.toDouble());
    }).toList();

    final prices = summary.points.map((p) => p.price.toDouble()).toList();
    final minY = prices.reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY = prices.reduce((a, b) => a > b ? a : b) * 1.1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final point = summary.points[idx];
                final dateStr = '${point.purchasedAt.day}/${point.purchasedAt.month}';
                return LineTooltipItem(
                  '${CurrencyFormatter.format(point.price)}\n$dateStr',
                  TextStyle(
                      color: context.cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= summary.points.length) return const SizedBox.shrink();
                final point = summary.points[idx];
                return Text(
                  '${point.purchasedAt.day}/${point.purchasedAt.month}',
                  style: context.text.bodySmall?.copyWith(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: context.cs.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: context.cs.surface,
                  strokeWidth: 2.5,
                  strokeColor: context.cs.primary,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.cs.primary.withOpacity(0.25),
                  context.cs.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge xu hướng — pill radius, tint nền màu ngữ nghĩa.
class _TrendBadge extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;

  const _TrendBadge({
    required this.color,
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 2, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const _MiniStat({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: context.text.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          MoneyText(
            amount: value,
            style: context.text.titleSmall?.copyWith(
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
