import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';

/// Khối shimmer đơn lẻ (width/height/radius tuỳ ý).
///
/// Shimmer tự viết bằng AnimationController — KHÔNG thêm package.
/// Tôn trọng `MediaQuery.disableAnimationsOf` (test/accessibility).
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDurations.medium * 3)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.snap.skeleton;
    final radius = BorderRadius.circular(widget.radius);

    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        key: const Key('loadingSkeleton'),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    final highlight = Color.lerp(base, context.cs.surface, 0.6)!;
    return Container(
      key: const Key('loadingSkeleton'),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(borderRadius: radius),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _controller.value),
            borderRadius: radius,
          ),
        ),
      ),
    );
  }
}

/// Danh sách skeleton card — thay `_SkeletonCard` lặp trong home.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('skeletonList'),
      children: [
        for (var i = 0; i < itemCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: LoadingSkeleton(
              key: Key('skeletonList_item_$i'),
              width: double.infinity,
              height: itemHeight,
              radius: AppRadius.lg,
            ),
          ),
      ],
    );
  }
}
