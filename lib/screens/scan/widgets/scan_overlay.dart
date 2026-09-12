import 'package:flutter/material.dart';
import 'package:shopsnap/core/theme/app_colors.dart';

class ScanOverlay extends StatefulWidget {
  const ScanOverlay({super.key});
  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      const cutW = 280.0;
      const cutH = 160.0;
      final left = (w - cutW) / 2;
      final top  = (h - cutH) / 2;

      return Stack(children: [
        // Dimmed overlay với cutout
        ClipPath(
          clipper: _CutoutClipper(left: left, top: top, width: cutW, height: cutH),
          child: Container(color: Colors.black.withOpacity(0.55)),
        ),
        // Corner decorations
        Positioned(left: left, top: top, child: _Corner(flip: false, flipV: false)),
        Positioned(right: left, top: top, child: _Corner(flip: true, flipV: false)),
        Positioned(left: left, bottom: top, child: _Corner(flip: false, flipV: true)),
        Positioned(right: left, bottom: top, child: _Corner(flip: true, flipV: true)),
        // Animated scan line
        Positioned(
          left: left + 2, right: left + 2,
          top: top + 2 + (cutH - 4) * _anim.value,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.primary,
                  AppColors.primary,
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _Corner extends StatelessWidget {
  final bool flip, flipV;
  const _Corner({required this.flip, required this.flipV});
  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1, scaleY: flipV ? -1 : 1,
      child: CustomPaint(size: const Size(24, 24), painter: _CornerPainter()),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _CutoutClipper extends CustomClipper<Path> {
  final double left, top, width, height;
  const _CutoutClipper({required this.left, required this.top, required this.width, required this.height});

  @override
  Path getClip(Size size) => Path()
    ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height), const Radius.circular(12),
    ))
    ..fillType = PathFillType.evenOdd;

  @override
  bool shouldReclip(_) => false;
}
