import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';

class WaveformVisualizer extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final int barCount;

  const WaveformVisualizer({
    super.key,
    this.isPlaying = true,
    this.progress = 0.33,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.border,
    this.height = 36,
    this.barCount = 38,
  });

  @override
  Widget build(BuildContext context) {
    // Generate pseudo-deterministic wave heights
    final heights = List.generate(barCount, (index) {
      final v = (index * 7) % 19 + 5;
      final factor = (index < 12 || index > 26) ? 0.6 : 1.0;
      return (v * factor).clamp(4.0, height);
    });

    final activeCutoff = (barCount * progress).round();

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (index) {
          final isBarActive = index <= activeCutoff;
          final barH = heights[index];
          return Container(
            width: 3.0,
            height: barH,
            decoration: BoxDecoration(
              color: isBarActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isBarActive && isPlaying
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

typedef WaveformPainterWidget = WaveformVisualizer;
