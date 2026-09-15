import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/snap_colors.dart';

/// Mini sparkline lịch sử giá (F-#6 AC 6.9) — tự vẽ bằng CustomPaint, KHÔNG
/// thêm package (fl_chart chỉ cần cho chart đầy đủ ở màn PriceHistory).
///
/// [prices] xếp theo thời gian TĂNG dần. 1 điểm → chấm tròn; ≥ 2 điểm →
/// polyline + fill gradient nhẹ + chấm tại giá mới nhất.
class PriceSparkline extends StatelessWidget {
  final List<int> prices;

  final double width;
  final double height;

  const PriceSparkline({
    super.key,
    required this.prices,
    this.width = double.infinity,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final snap = context.snap;
    return CustomPaint(
      key: const Key('priceSparkline'),
      size: Size(width, height),
      painter: _SparklinePainter(
        prices: prices,
        lineColor: snap.success,
        fillColor: snap.successDim,
        dotColor: snap.textPrimary,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> prices;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;

  static const double _padding = 4;

  const _SparklinePainter({
    required this.prices,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty) return;

    final rect = rectDeflate(size);
    if (prices.length == 1) {
      canvas.drawCircle(rect.center, 2.5, Paint()..color = lineColor);
      return;
    }

    final points = mappedPoints(rect);
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(Path()..addPolygon(points, false), line);

    // Fill nhẹ dưới đường giá — giúp "đọc" độ sâu mức thấp.
    final fill = Path()
      ..addPolygon(points, false)
      ..lineTo(points.last.dx, rect.bottom)
      ..lineTo(points.first.dx, rect.bottom)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);

    // Chấm giá mới nhất.
    canvas.drawCircle(points.last, 3, Paint()..color = dotColor);
    canvas.drawCircle(
      points.last,
      3,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  Rect rectDeflate(Size size) => Rect.fromLTWH(
        _padding,
        _padding,
        math.max(0, size.width - _padding * 2),
        math.max(0, size.height - _padding * 2),
      );

  List<Offset> mappedPoints(Rect rect) {
    final minP = prices.reduce(math.min);
    final maxP = prices.reduce(math.max);
    final span = (maxP - minP).toDouble();
    final stepX = rect.width / (prices.length - 1);

    return List.generate(prices.length, (i) {
      final x = rect.left + stepX * i;
      final y = span == 0
          ? rect.center.dy
          : rect.bottom - ((prices[i] - minP) / span) * rect.height;
      return Offset(x, y);
    });
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      !_listEquals(old.prices, prices) ||
      old.lineColor != lineColor ||
      old.fillColor != fillColor ||
      old.dotColor != dotColor;
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
