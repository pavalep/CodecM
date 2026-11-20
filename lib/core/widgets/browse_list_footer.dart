import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';

/// In-flow footer for paged browse lists matching MD specification
/// (buildathon/22-SCREENS-HOME-LIBRARY-QUEUE.md §1.11).
/// Four canonical branches:
/// 1. isLoadingMore -> Spinner + "Loading more…"
/// 2. error != null -> Tappable retry pill: "Couldn't load more — tap to retry"
/// 3. reachedEnd && shown > 0 -> "You're all caught up."
/// 4. idle spacer (height 28)
class BrowseListFooter extends StatelessWidget {
  final bool isLoadingMore;
  final String? error;
  final bool reachedEnd;
  final int shown;
  final VoidCallback? onLoadMore;
  final String? endLabel;

  const BrowseListFooter({
    super.key,
    this.isLoadingMore = false,
    this.error,
    this.reachedEnd = false,
    this.shown = 0,
    this.onLoadMore,
    this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Loading More branch
    if (isLoadingMore) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Loading more…',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Error branch (tappable retry pill)
    if (error != null && error!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: onLoadMore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  "Couldn't load more — tap to retry",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Caught up / Terminal branch
    if (reachedEnd && shown > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                endLabel ?? "You're all caught up.",
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            Container(width: 24, height: 1, color: AppColors.border),
          ],
        ),
      );
    }

    // 4. Idle spacer
    return const SizedBox(height: 16);
  }
}
