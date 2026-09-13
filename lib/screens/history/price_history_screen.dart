import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/price_history_model.dart';
import '../../providers/price_history_provider.dart';
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
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Biến động giá sản phẩm',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // ── Khung tìm kiếm & nút quét barcode ───────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgMain,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearch,
                      decoration: InputDecoration(
                        hintText: 'Nhập tên hoặc mã vạch sản phẩm...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref.read(selectedPriceQueryProvider.notifier).state = null;
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _scanBarcode,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // ── Danh sách gợi ý mặt hàng hay mua ─────────────────────────────
          frequentItemsAsync.when(
            data: (frequent) {
              if (frequent.isEmpty) return const SizedBox.shrink();
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: frequent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final item = frequent[idx];
                      final isSelected = currentQuery?.name == item.itemName ||
                          (currentQuery?.barcode != null && currentQuery?.barcode == item.barcode);
                      return ChoiceChip(
                        label: Text(
                          item.itemName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.bgMain,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.divider,
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
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Nội dung chính: Biểu đồ và Lịch sử giá ───────────────────────
          Expanded(
            child: currentQuery == null
                ? _buildEmptyPrompt()
                : ref.watch(priceHistorySummaryProvider(currentQuery)).when(
                    data: (summary) {
                      if (summary == null || summary.points.isEmpty) {
                        return _buildNotFound(currentQuery);
                      }
                      return _buildSummaryContent(summary);
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Theo dõi biến động giá',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Chọn sản phẩm ở danh sách gợi ý phía trên hoặc quét mã vạch để xem xu hướng giá qua các lần mua sắm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound(PriceHistoryQuery query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 54, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Chưa có lịch sử giá', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'Không tìm thấy dữ liệu giá cho "${query.name ?? query.barcode}"',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(PriceHistorySummary summary) {
    final hasMultiplePoints = summary.points.length >= 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (summary.barcode != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Mã vạch: ${summary.barcode}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildTrendBadge(summary),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Giá mua gần nhất', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(summary.latestPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 14),

                // 3 Mini stats: Thấp nhất, Cao nhất, Trung bình
                Row(
                  children: [
                    _MiniStat(
                      label: 'Thấp nhất',
                      value: CurrencyFormatter.format(summary.minPrice),
                      color: AppColors.success,
                    ),
                    _MiniStat(
                      label: 'Cao nhất',
                      value: CurrencyFormatter.format(summary.maxPrice),
                      color: AppColors.danger,
                    ),
                    _MiniStat(
                      label: 'Trung bình',
                      value: CurrencyFormatter.format(summary.avgPrice),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Biểu đồ đường biến động giá (LineChart) ────────────────────
          const Text(
            'Xu hướng giá theo thời gian',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              height: 200,
              child: hasMultiplePoints
                  ? _buildLineChart(summary)
                  : const Center(
                      child: Text(
                        'Cần ít nhất 2 lần mua để vẽ biểu đồ biến động giá.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Danh sách lịch sử các lần mua ──────────────────────────────
          Text(
            'Lịch sử các lần mua (${summary.totalRecords} lần)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.points.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              // Điểm trong summary.points đang xếp từ cũ đến mới → đảo ngược để hiện mới nhất ở trên
              final point = summary.points[summary.points.length - 1 - idx];
              final prevPoint = idx < summary.points.length - 1
                  ? summary.points[summary.points.length - 2 - idx]
                  : null;

              final diff = prevPoint != null ? point.price - prevPoint.price : null;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateHelper.formatDate(point.purchasedAt),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            point.storeName ?? 'Cửa hàng / Siêu thị',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(point.price),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        if (diff != null && diff != 0)
                          Text(
                            diff > 0 ? '+${CurrencyFormatter.format(diff)} 🔺' : '${CurrencyFormatter.format(diff)} 🟢',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: diff > 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrendBadge(PriceHistorySummary summary) {
    if (summary.trend == PriceTrend.up) {
      final pct = summary.priceChangePercent != null ? '+${summary.priceChangePercent}%' : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up, color: AppColors.danger, size: 16),
            const SizedBox(width: 4),
            Text(
              'Tăng $pct',
              style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    } else if (summary.trend == PriceTrend.down) {
      final pct = summary.priceChangePercent != null ? '${summary.priceChangePercent}%' : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_down, color: AppColors.success, size: 16),
            const SizedBox(width: 4),
            Text(
              'Giảm $pct',
              style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.divider.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Giá ổn định',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  Widget _buildLineChart(PriceHistorySummary summary) {
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
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: AppColors.primary,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withOpacity(0.25),
                  AppColors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}
