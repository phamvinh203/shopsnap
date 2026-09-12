import 'package:flutter/material.dart';

class PriceStickerWidget extends StatelessWidget {
  final String label;
  final Color  color;
  final double scale;

  const PriceStickerWidget({
    super.key,
    required this.label,
    required this.color,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isLight   = color.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:       color.withOpacity(0.55),
              blurRadius:  14,
              offset:      const Offset(0, 5),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_offer_rounded,
              color: textColor.withOpacity(0.8), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:       textColor,
              fontWeight:  FontWeight.w700,
              fontSize:    15,
              letterSpacing: 0.3,
            ),
          ),
        ]),
      ),
    );
  }
}
