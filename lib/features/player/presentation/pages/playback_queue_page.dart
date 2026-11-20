import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/player_bloc.dart';
import '../bloc/player_event.dart';
import '../bloc/player_state.dart';

class PlaybackQueuePage extends StatelessWidget {
  const PlaybackQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Playback Queue', style: AppTypography.headlineSm(fontSize: 20)),
                    BlocBuilder<PlayerBloc, PlayerState>(
                      builder: (context, state) {
                        return Text(
                          '${state.queue.length} Tracks In Queue',
                          style: AppTypography.bodySm(color: AppColors.textSecondary),
                        );
                      },
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    context.read<PlayerBloc>().add(ClearQueue());
                  },
                  child: Text('Clear', style: AppTypography.labelLg(color: AppColors.error)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Queue List & Controls
          Expanded(
            child: BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, state) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    // Now Playing Card
                    Text('NOW PLAYING', style: AppTypography.labelSm(color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 1.2),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              state.currentEpisode.artworkUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.currentEpisode.title,
                                  style: AppTypography.titleMd(fontSize: 13.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  state.currentEpisode.showTitle,
                                  style: AppTypography.bodySm(color: AppColors.textSecondary, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Up Next Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('UP NEXT', style: AppTypography.labelSm(color: AppColors.textSecondary)),
                        Text('Drag to reorder', style: AppTypography.bodySm(color: AppColors.textTertiary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (state.queue.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          'Your queue is empty',
                          style: AppTypography.bodyMd(color: AppColors.textTertiary),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.queue.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          context.read<PlayerBloc>().add(ReorderQueue(oldIndex, newIndex));
                        },
                        itemBuilder: (context, index) {
                          final ep = state.queue[index];
                          return Container(
                            key: ValueKey(ep.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.drag_indicator_rounded, color: AppColors.textTertiary, size: 20),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    ep.artworkUrl,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ep.title,
                                        style: AppTypography.titleMd(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${ep.showTitle} • ${ep.durationString}',
                                        style: AppTypography.bodySm(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                                  onPressed: () {
                                    context.read<PlayerBloc>().add(RemoveFromQueue(ep));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),

          // Bottom Close Action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close Queue', style: AppTypography.labelLg(color: Colors.white, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
