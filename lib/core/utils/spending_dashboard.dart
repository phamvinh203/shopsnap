/// F-#2 Spending Intelligence Dashboard — pure logic (không Flutter).
///
/// Gồm 3 mảng:
/// 1. MoM (Month-over-Month): % tổng chi tháng này vs tháng trước, xử lý edge
///    "tháng trước = 0" KHÔNG chia 0 (AC 2.1, 2.2).
/// 2. Breakdown danh mục: sắp xếp GIẢM DẦN theo số tiền + % trên tổng (AC 2.3).
/// 3. Heuristic insight (fallback khi AI lỗi — AC 2.5): sinh từ structured
///    aggregates; 1 category thì KHÔNG so sánh xếp hạng (AC 2.8).
library;

import '../../models/summary_model.dart';

/// Hướng biến động so với kỳ trước.
enum MomDirection { up, down, flat, newStart }

/// Kết quả so sánh MoM của một kỳ.
class MomChange {
  final MomDirection direction;

  /// % lệch (có dấu) so với kỳ trước — `null` khi kỳ trước = 0 (AC 2.2:
  /// không chia 0) hoặc không có dữ liệu kỳ trước.
  final double? percent;

  /// Nhãn kỳ so sánh ("tháng trước" cho MoM, "kỳ trước" cho day/week/year).
  final String comparisonLabel;

  const MomChange({
    required this.direction,
    required this.percent,
    this.comparisonLabel = 'tháng trước',
  });

  /// AC 2.2 — tháng trước chi 0đ → nhãn "Tháng mới bắt đầu" thay cho %.
  bool get isNewStart => direction == MomDirection.newStart;

  /// Nhãn hiển thị trên header (mũi tên/màu do UI map theo [direction]).
  String get label {
    final pct = percent;
    return switch (direction) {
      MomDirection.newStart => 'Tháng mới bắt đầu',
      MomDirection.up => '+${pct!.toStringAsFixed(0)}% so với $comparisonLabel',
      MomDirection.down => '${pct!.toStringAsFixed(0)}% so với $comparisonLabel',
      MomDirection.flat => 'Ngang bằng $comparisonLabel',
    };
  }
}

/// Tính MoM từ tổng hiện tại + tổng kỳ trước.
///
/// [serverTrend] là trend BE tính sẵn ('up'|'down'|'flat') — dùng khi có để
/// đồng nhất với server; thiếu thì suy từ dấu % (AC 2.1). previous == 0 →
/// newStart (AC 2.2).
MomChange computeMomChange({
  required int current,
  int? previous,
  String? serverTrend,
  String comparisonLabel = 'tháng trước',
}) {
  if (previous == null) {
    return MomChange(
        direction: MomDirection.flat, percent: null,
        comparisonLabel: comparisonLabel);
  }
  if (previous <= 0) {
    return MomChange(
        direction: MomDirection.newStart, percent: null,
        comparisonLabel: comparisonLabel);
  }

  final percent = ((current - previous) / previous) * 100;
  final direction = switch (serverTrend) {
    'up' => MomDirection.up,
    'down' => MomDirection.down,
    'flat' => MomDirection.flat,
    _ => percent > 0
        ? MomDirection.up
        : percent < 0
            ? MomDirection.down
            : MomDirection.flat,
  };
  return MomChange(
    direction: percent == 0 ? MomDirection.flat : direction,
    percent: percent,
    comparisonLabel: comparisonLabel,
  );
}

/// Breakdown danh mục xếp GIẢM DẦN theo số tiền (AC 2.3) — không mutate list
/// gốc; amount bằng nhau giữ thứ tự ổn định (Dart sort là stable).
List<CategorySummary> sortCategoriesDesc(List<CategorySummary> categories) {
  final sorted = [...categories];
  sorted.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
  return sorted;
}

/// % của một danh mục trên tổng — tổng 0 → 0 (không chia 0).
double shareOfTotal({required int part, required int total}) =>
    total > 0 ? (part / total) * 100 : 0.0;

/// Tỉ lệ vẽ progress bar 0..1 (clamp, không âm).
double barRatio({required int part, required int total}) {
  if (total <= 0) return 0;
  return (part / total).clamp(0.0, 1.0);
}

/// Heuristic insight tiếng Việt từ aggregates — fallback khi AI lỗi/quá
/// timeout (AC 2.5), KHÔNG dùng raw transaction.
///
/// [mom] `null` = không có dữ liệu kỳ trước → câu chỉ mô tả cơ cấu chi.
/// AC 2.8: chỉ có 1 category → không đả động "cao nhất/xếp hạng" (câu vô
/// nghĩa); AC 2.7: không có chi tiêu → câu mời nhập dữ liệu.
String heuristicSpendingInsight({
  required List<CategorySummary> categoriesSortedDesc,
  required int totalSpent,
  required MomChange? mom,
}) {
  if (totalSpent <= 0 || categoriesSortedDesc.isEmpty) {
    return 'Chưa đủ dữ liệu để đưa gợi ý — thêm khoản chi đầu tiên nhé!';
  }

  final top = categoriesSortedDesc.first;
  final share = shareOfTotal(part: top.totalSpent, total: totalSpent);
  final head =
      '${top.categoryName} chiếm ${share.toStringAsFixed(0)}% chi tiêu';

  // AC 2.8: 1 category → bỏ mệnh đề xếp hạng.
  final rank = categoriesSortedDesc.length > 1 ? ', cao nhất tháng này' : '';

  final tail = mom == null
      ? ''
      : switch (mom.direction) {
          MomDirection.up =>
            ', tổng chi tăng ${mom.percent!.abs().toStringAsFixed(0)}% so với ${mom.comparisonLabel}',
          MomDirection.down =>
            ', tổng chi giảm ${mom.percent!.abs().toStringAsFixed(0)}% so với ${mom.comparisonLabel}',
          MomDirection.flat => ', tổng chi ngang bằng ${mom.comparisonLabel}',
          MomDirection.newStart => ', tháng này bắt đầu ghi chép',
        };
  return '$head$rank$tail';
}
