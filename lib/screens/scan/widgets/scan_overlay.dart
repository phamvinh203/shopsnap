import 'package:flutter/material.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';

class ScanOverlay extends StatefulWidget {
  final bool isSuccess;

  const ScanOverlay({super.key, this.isSuccess = false});

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Màu qua token (context.snap có fallback cho bare MaterialApp test) —
    // overlay nằm TRÊN camera nên nền đen dim giữ nguyên (chức năng, không
    // phải surface theo theme).
    final colors = context.snap;
    final activeColor = widget.isSuccess ? colors.success : context.cs.primary;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      const cutW = 280.0;
      const cutH = 160.0;
      final left = (w - cutW) / 2;
      final top = (h - cutH) / 2;

      return Stack(children: [
        // Dimmed overlay với cutout
        ClipPath(
          clipper: _CutoutClipper(left: left, top: top, width: cutW, height: cutH),
          child: Container(color: Colors.black.withOpacity(0.60)),
        ),

        // Viền nhấp nháy phát sáng khi quét thành công
        if (widget.isSuccess)
          Positioned(
            left: left,
            top: top,
            width: cutW,
            height: cutH,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.success, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: colors.success.withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

        // 4 Corner reticles phát sáng
        Positioned(left: left, top: top, child: _Corner(flip: false, flipV: false, color: activeColor)),
        Positioned(right: left, top: top, child: _Corner(flip: true, flipV: false, color: activeColor)),
        Positioned(left: left, bottom: top, child: _Corner(flip: false, flipV: true, color: activeColor)),
        Positioned(right: left, bottom: top, child: _Corner(flip: true, flipV: true, color: activeColor)),

        // Animated laser sweep beam (chùm tia laser đa tầng)
        if (!widget.isSuccess)
          Positioned(
            left: left + 4,
            right: left + 4,
            top: top + 4 + (cutH - 34) * _anim.value,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Vệt sáng mờ quét phía trên
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          activeColor.withOpacity(0.0),
                          activeColor.withOpacity(0.20),
                        ],
                      ),
                    ),
                  ),
                  // Tia sáng laser trung tâm neon
                  Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: activeColor,
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        activeColor.withOpacity(0.8),
                        Colors.white,
                        activeColor.withOpacity(0.8),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ]);
    });
  }
}

class _Corner extends StatelessWidget {
  final bool flip, flipV;
  final Color color;

  const _Corner({required this.flip, required this.flipV, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      scaleY: flipV ? -1 : 1,
      child: CustomPaint(
        size: const Size(26, 26),
        painter: _CornerPainter(color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

class _CutoutClipper extends CustomClipper<Path> {
  final double left, top, width, height;

  const _CutoutClipper({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  @override
  Path getClip(Size size) => Path()
    ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(14),
    ))
    ..fillType = PathFillType.evenOdd;

  @override
  bool shouldReclip(_) => false;
}
