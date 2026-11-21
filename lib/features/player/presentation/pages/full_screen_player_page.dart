import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../bloc/player_bloc.dart';
import '../bloc/player_event.dart';
import '../bloc/player_state.dart';
import '../widgets/waveform_painter.dart';
import 'playback_queue_page.dart';

class FullScreenPlayerPage extends StatelessWidget {
  const FullScreenPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            final ep = state.currentEpisode;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Top Bar: Down arrow, Show Title, Queue Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Column(
                        children: [
                          Text(
                            ep.showTitle.toUpperCase(),
                            style: AppTypography.labelSm(
                              letterSpacing: 0.08,
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Lossless Audio Stream',
                                style: AppTypography.bodySm(color: AppColors.primary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.queue_music_rounded, color: AppColors.textPrimary, size: 24),
                            tooltip: 'Queue',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const PlaybackQueuePage(),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 24),
                            tooltip: 'Stop & Close',
                            onPressed: () {
                              context.read<PlayerBloc>().add(StopPlayback());
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Large Album Artwork with Soft Shadow
                  Container(
                    width: MediaQuery.of(context).size.width * 0.78,
                    height: MediaQuery.of(context).size.width * 0.78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppColors.floatingShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        ep.artworkUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.podcasts_rounded, size: 64, color: Colors.white),
                                ),
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    ep.showTitle,
                                    style: AppTypography.displayEditorial(fontSize: 20, color: Colors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Track Metadata & Affinity Badge
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_outlined, color: AppColors.primary, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'Recommended For You',
                              style: AppTypography.labelSm(color: AppColors.primary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ep.title,
                        style: AppTypography.displayEditorial(
                          fontSize: 22,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ep.host,
                        style: AppTypography.bodyLg(color: AppColors.textSecondary, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 4. Waveform & Scrubber Slider
                  Column(
                    children: [
                      WaveformPainterWidget(
                        progress: state.progress,
                        isPlaying: state.isPlaying,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                      ),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.border,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: state.position.inSeconds.toDouble().clamp(
                                0.0,
                                state.duration.inSeconds.toDouble(),
                              ),
                          max: state.duration.inSeconds.toDouble(),
                          onChanged: (val) {
                            context.read<PlayerBloc>().add(
                                  SeekPosition(Duration(seconds: val.toInt())),
                                );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.formatDuration(state.position),
                              style: AppTypography.monoMetric(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            Text(
                              '-${state.formatDuration(state.duration - state.position)}',
                              style: AppTypography.monoMetric(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 5. Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 28, color: AppColors.textPrimary),
                        onPressed: () => context.read<PlayerBloc>().add(PlayPreviousTrack()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded, size: 30, color: AppColors.textPrimary),
                        onPressed: () => context.read<PlayerBloc>().add(
                              const SeekRelative(Duration(seconds: -10)),
                            ),
                      ),
                      GestureDetector(
                        onTap: () => context.read<PlayerBloc>().add(TogglePlayPause()),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.primaryGlow(blur: 20),
                          ),
                          child: Icon(
                            state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded, size: 30, color: AppColors.textPrimary),
                        onPressed: () => context.read<PlayerBloc>().add(
                              const SeekRelative(Duration(seconds: 10)),
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 28, color: AppColors.textPrimary),
                        onPressed: () => context.read<PlayerBloc>().add(PlayNextTrack()),
                      ),
                    ],
                  ),

                  // 6. Footer Utility Pills: Speed, Sleep Timer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterPill(
                          context,
                          label: '${state.speed}x',
                          onTap: () {
                            final nextSpeed = state.speed == 1.0
                                ? 1.2
                                : (state.speed == 1.2 ? 1.5 : (state.speed == 1.5 ? 2.0 : 1.0));
                            context.read<PlayerBloc>().add(ChangePlaybackSpeed(nextSpeed));
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildFooterPill(
                          context,
                          icon: Icons.nightlight_round,
                          label: '${state.sleepTimerMinutes}m',
                          onTap: () {
                            final nextTimer = state.sleepTimerMinutes == 15
                                ? 30
                                : (state.sleepTimerMinutes == 30 ? 60 : 15);
                            context.read<PlayerBloc>().add(SetSleepTimer(nextTimer));
                          },
                        ),
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

  Widget _buildFooterPill(
    BuildContext context, {
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border, width: 0.8),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTypography.labelSm(color: AppColors.textPrimary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
