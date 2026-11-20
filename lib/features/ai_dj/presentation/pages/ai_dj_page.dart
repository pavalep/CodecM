import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/services/on_device_ai_engine.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';

class AiDjPage extends StatelessWidget {
  const AiDjPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Engine Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EmbeddingGemma • 0ms Latency',
                        style: AppTypography.monoMetric(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
                ],
              ),
              const SizedBox(height: 6),

              Text('CodecM AI DJ Studio', style: AppTypography.displayEditorial(fontSize: 28)),

              const SizedBox(height: 16),

              // Hero Neural Synthesis Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 0.8),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'LITERT NEURAL AUDIO SYNTHESIS',
                        style: AppTypography.labelSm(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your Daily Neural Audio Blend',
                      style: AppTypography.headlineSm(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Synthesized locally on your device: 42% Transformer Architectures, 35% Venture Scaling, 23% Quantum Physics based on your recent listening sessions.',
                      style: AppTypography.bodyMd(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        context.read<PlayerBloc>().add(
                              PlayEpisode(OnDeviceAiEngine.predictedSmartAutoplay),
                            );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: AppColors.primaryGlow(blur: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Play Today\'s Mix (48m • 4 Tracks)',
                              style: AppTypography.labelLg(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text('Smart Playlists (On-Device)', style: AppTypography.headlineSm(fontSize: 18)),
              const SizedBox(height: 12),

              _buildSmartPlaylistTile(
                title: 'Beyond Artificial Intelligence',
                hosts: 'Ilya Sutskever, Demis Hassabis, Yann LeCun',
                meta: '6 episodes • 3h 15m',
                affinity: '98% Match',
              ),
              const SizedBox(height: 10),
              _buildSmartPlaylistTile(
                title: 'Founder War Stories & Moats',
                hosts: 'Jensen Huang, Brian Chesky, Patrick Collison',
                meta: '5 episodes • 4h 20m',
                affinity: '94% Match',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartPlaylistTile({
    required String title,
    required String hosts,
    required String meta,
    required String affinity,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.queue_music_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.titleMd(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      affinity,
                      style: AppTypography.labelSm(color: AppColors.primary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hosts,
                  style: AppTypography.bodySm(color: AppColors.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppTypography.bodySm(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
