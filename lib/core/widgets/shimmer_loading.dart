import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';

/// Reusable animated luxury shimmer provider
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFE8ECE9),
                Color(0xFFF7FAF8),
                Color(0xFFE8ECE9),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Generic Shimmer Box Placeholder
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: shape != null
          ? ShapeDecoration(color: const Color(0xFFE5EAE7), shape: shape!)
          : BoxDecoration(
              color: const Color(0xFFE5EAE7),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
    );
  }
}

/// Shimmer Skeleton for 2-Column Grid (Movies, TV Shows, Audiobooks)
class ShimmerGridSkeleton extends StatelessWidget {
  final int count;
  final double childAspectRatio;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets padding;

  const ShimmerGridSkeleton({
    super.key,
    this.count = 6,
    this.childAspectRatio = 0.65,
    this.physics,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? const BouncingScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ShimmerBox(borderRadius: 0),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 110, height: 14, borderRadius: 6),
                      SizedBox(height: 6),
                      ShimmerBox(width: 70, height: 11, borderRadius: 6),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBox(width: 40, height: 10, borderRadius: 4),
                          ShimmerBox(width: 35, height: 10, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer Skeleton for List Rows ("Best for you", Music, Radio, History, Search)
class ShimmerListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const ShimmerListSkeleton({
    super.key,
    this.count = 5,
    this.padding = EdgeInsets.zero,
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: count,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 70, height: 70, borderRadius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 150, height: 14, borderRadius: 6),
                      SizedBox(height: 6),
                      ShimmerBox(width: 90, height: 11, borderRadius: 6),
                      SizedBox(height: 10),
                      ShimmerBox(width: 60, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const ShimmerBox(width: 36, height: 36, borderRadius: 18),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer Skeleton for Horizontal Carousel (Home Popular Shows)
class ShimmerCarouselSkeleton extends StatelessWidget {
  final int count;

  const ShimmerCarouselSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: count,
          separatorBuilder: (ctx, i) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            return Container(
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    child: SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: ShimmerBox(borderRadius: 0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(width: 100, height: 12, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 60, height: 10, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shimmer Skeleton for Discover Top Showcase Card
class ShimmerShowcaseSkeleton extends StatelessWidget {
  const ShimmerShowcaseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            const ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 24),
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 180, height: 22, borderRadius: 6),
                  SizedBox(height: 8),
                  ShimmerBox(width: 120, height: 12, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(width: 80, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer Skeleton for Video Player surface
class ShimmerVideoSkeleton extends StatelessWidget {
  const ShimmerVideoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_outline_rounded, size: 64, color: Colors.white24),
          ),
        ),
      ),
    );
  }
}
