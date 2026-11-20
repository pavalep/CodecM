import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../bloc/player_bloc.dart';
import '../bloc/player_event.dart';
import '../bloc/player_state.dart';
import '../pages/full_screen_player_page.dart';
import '../pages/video_player_page.dart';
import '../../data/services/video_playback_manager.dart';

/// Unified persistent mini player supporting both Audio and Video playback across all pages
class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VideoPlaybackManager.instance.hasActiveVideoNotifier,
      builder: (context, hasVideo, _) {
        if (hasVideo) {
          return _buildVideoMiniPlayer(context);
        }
        return _buildAudioMiniPlayer(context);
      },
    );
  }

  // 1. VIDEO MINI PLAYER
  Widget _buildVideoMiniPlayer(BuildContext context) {
    final item = VideoPlaybackManager.instance.currentItem;
    final ctrl = VideoPlaybackManager.instance.controller;
    if (item == null || ctrl == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VideoPlayerPage(item: item)),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Video Preview Frame
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 58,
                        height: 42,
                        color: Colors.black,
                        child: ctrl.value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: ctrl.value.size.width > 0 ? ctrl.value.size.width : 16,
                                  height: ctrl.value.size.height > 0 ? ctrl.value.size.height : 9,
                                  child: VideoPlayer(ctrl),
                                ),
                              )
                            : item.artworkUrl.isNotEmpty
                                ? Image.network(item.artworkUrl, fit: BoxFit.cover)
                                : const Center(child: Icon(Icons.movie_rounded, color: Colors.white70, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & Channel
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VIDEO',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  item.creator,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Seek -10s
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      icon: const Icon(Icons.replay_10_rounded, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        VideoPlaybackManager.instance.seekRelative(const Duration(seconds: -10));
                      },
                    ),
                    const SizedBox(width: 2),

                    // Play / Pause
                    ValueListenableBuilder<bool>(
                      valueListenable: VideoPlaybackManager.instance.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return GestureDetector(
                          onTap: () {
                            VideoPlaybackManager.instance.togglePlayPause();
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),

                    // Close / Stop Video
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        VideoPlaybackManager.instance.stop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Progress Scrubber
              ValueListenableBuilder<Duration>(
                valueListenable: VideoPlaybackManager.instance.positionNotifier,
                builder: (context, pos, _) {
                  final dur = VideoPlaybackManager.instance.durationNotifier.value;
                  final progress = dur.inMilliseconds > 0
                      ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.borderSubtle,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 2.5,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. AUDIO MINI PLAYER
  Widget _buildAudioMiniPlayer(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final ep = state.currentEpisode;

        if (state.status == PlaybackStatus.initial ||
            state.status == PlaybackStatus.stopped ||
            ep.title.isEmpty) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, anim, _) => const FullScreenPlayerPage(),
                transitionsBuilder: (context, anim, _, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Album Thumbnail with shimmer placeholder
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: AppColors.surfaceSubtle,
                            child: ep.artworkUrl.isNotEmpty
                                ? Image.network(
                                    ep.artworkUrl,
                                    fit: BoxFit.cover,
                                    frameBuilder: (ctx, child, frame, wasSync) {
                                      if (wasSync || frame != null) return child;
                                      return const ShimmerLoading(
                                        child: ShimmerBox(width: 44, height: 44, borderRadius: 8),
                                      );
                                    },
                                    errorBuilder: (ctx, err, stack) => const Icon(
                                      Icons.podcasts_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  )
                                : const Icon(
                                    Icons.podcasts_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ep.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                ep.showTitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Replay 10s
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.replay_10_rounded, color: AppColors.textSecondary, size: 20),
                          onPressed: () {
                            context.read<PlayerBloc>().add(const SeekRelative(Duration(seconds: -10)));
                          },
                        ),
                        const SizedBox(width: 4),

                        // Forest Green Play/Pause Action
                        GestureDetector(
                          onTap: () {
                            context.read<PlayerBloc>().add(TogglePlayPause());
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Dismiss / Close Mini Player Action
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            context.read<PlayerBloc>().add(StopPlayback());
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Micro Scrubber with Buffered Progress
                  Stack(
                    children: [
                      LinearProgressIndicator(
                        value: state.bufferedProgress,
                        backgroundColor: AppColors.borderSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                        minHeight: 2.5,
                      ),
                      LinearProgressIndicator(
                        value: state.progress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 2.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
