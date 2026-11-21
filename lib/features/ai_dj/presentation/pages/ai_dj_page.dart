import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/services/on_device_ai_engine.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/player/presentation/pages/full_screen_player_page.dart';

class AiDjPage extends StatefulWidget {
  const AiDjPage({super.key});

  @override
  State<AiDjPage> createState() => _AiDjPageState();
}

class _AiDjPageState extends State<AiDjPage> {
  final MediaRepository _repository = MediaRepository();
  final OnDeviceAiEngine _aiEngine = OnDeviceAiEngine.instance;

  bool _isLoading = true;
  List<MediaItem> _dailyMix = [];
  List<MediaItem> _podcastBlend = [];
  List<MediaItem> _musicBlend = [];

  final List<String> _availableTopics = const [
    'Technology & AI',
    'Indie Music',
    'Classic Cinema',
    'World Radio',
    'Literature & Audiobooks',
    'Science & Culture',
  ];
  final Set<String> _selectedTopics = {
    'Technology & AI',
    'Indie Music',
    'Classic Cinema',
  };

  @override
  void initState() {
    super.initState();
    _synthesizeLiveMix();
  }

  Future<void> _synthesizeLiveMix() async {
    setState(() => _isLoading = true);

    await _aiEngine.initialize();

    final results = await Future.wait([
      _repository.getTrendingPodcasts(),
      _repository.getPopularMusic(),
      _repository.getPopularRadio(),
      _repository.getPopularAudiobooks(),
    ]);

    final podcasts = (results[0] as List)
        .map((p) => MediaRepository.podcastToMediaItem(p))
        .toList();
    final music = results[1] as List<MediaItem>;
    final radio = results[2] as List<MediaItem>;
    final audiobooks = results[3] as List<MediaItem>;

    final allAudioCandidates = <MediaItem>[
      ...music.take(6),
      ...radio.take(4),
      ...podcasts.take(4),
      ...audiobooks.take(3),
    ];

    final queryContext = _aiEngine.buildUserTasteContext(
      customTopics: _selectedTopics.toList(),
    );

    final rankedAll = await _aiEngine.rankMediaItems(
      allAudioCandidates,
      queryContext: queryContext,
    );
    final rankedPodcasts = await _aiEngine.rankMediaItems(
      podcasts,
      queryContext: queryContext,
    );
    final rankedMusic = await _aiEngine.rankMediaItems(
      [...music, ...radio],
      queryContext: queryContext,
    );

    await _aiEngine.generateDjSynthesis(
      userTopics: _selectedTopics.toList(),
      liveCatalog: rankedAll,
    );
    await _aiEngine.refreshStatus();

    if (mounted) {
      setState(() {
        _dailyMix = rankedAll.take(6).toList();
        _podcastBlend = rankedPodcasts.take(5).toList();
        _musicBlend = rankedMusic.take(5).toList();
        _isLoading = false;
      });
    }
  }

  void _playBlendQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    final episodes = items.map((m) => MediaRepository.mediaItemToEpisode(m)).toList();
    final bloc = context.read<PlayerBloc>();
    bloc.add(ClearQueue());
    bloc.add(PlayEpisode(episodes.first));
    for (int i = 1; i < episodes.length; i++) {
      bloc.add(AddToQueue(episodes[i]));
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FullScreenPlayerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Curated For You',
          style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Mixes',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _isLoading ? null : _synthesizeLiveMix,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Mood & Topic Filter Chips
              Text(
                'PERSONALIZE YOUR MIX',
                style: AppTypography.labelSm(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTopics.map((topic) {
                  final isSelected = _selectedTopics.contains(topic);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected && _selectedTopics.length > 1) {
                          _selectedTopics.remove(topic);
                        } else {
                          _selectedTopics.add(topic);
                        }
                      });
                      _synthesizeLiveMix();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        topic,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // 3. Hero Handpicked Mix Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'DAILY MIX',
                            style: AppTypography.labelSm(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${_dailyMix.length} titles',
                          style: AppTypography.bodySm(
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Afternoon Cadence',
                      style: AppTypography.headlineSm(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Steady rhythms, thoughtful stories, and cinema explorations tailored to your listening taste.',
                      style: AppTypography.bodyMd(color: AppColors.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _dailyMix.isEmpty ? null : () => _playBlendQueue(_dailyMix),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _dailyMix.isEmpty ? AppColors.textTertiary : AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              _isLoading
                                  ? 'Preparing Your Mix...'
                                  : 'Play Handpicked Mix (${_dailyMix.length} Titles)',
                              style: AppTypography.labelLg(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 4. Curated Playlists built from Live API Results
              Text('Handpicked Mixes', style: AppTypography.headlineSm(fontSize: 17)),
              const SizedBox(height: 10),

              if (_isLoading)
                const ShimmerListSkeleton(count: 3)
              else ...[
                _buildSmartPlaylistTile(
                  title: 'Live Music & Global Radio',
                  hosts: _musicBlend.map((m) => m.creator).take(3).join(', '),
                  meta: '${_musicBlend.length} titles • Handpicked mix',
                  affinity: 'For You',
                  items: _musicBlend,
                ),
                const SizedBox(height: 10),
                _buildSmartPlaylistTile(
                  title: 'Evening Conversations & Stories',
                  hosts: _podcastBlend.map((m) => m.title).take(3).join(', '),
                  meta: '${_podcastBlend.length} titles • Handpicked mix',
                  affinity: 'For You',
                  items: _podcastBlend,
                ),
              ],

              const SizedBox(height: 22),

              // 5. Ranked Track Queue Preview
              if (_dailyMix.isNotEmpty) ...[
                Text('Recommended For You', style: AppTypography.headlineSm(fontSize: 17)),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dailyMix.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _dailyMix[index];
                    return GestureDetector(
                      onTap: () => _playBlendQueue([item, ..._dailyMix.where((m) => m.id != item.id)]),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.artworkUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 48,
                                  height: 48,
                                  color: AppColors.primaryContainer,
                                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.creator} • ${item.kind.displayName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 30),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
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
    required List<MediaItem> items,
  }) {
    return GestureDetector(
      onTap: items.isEmpty ? null : () => _playBlendQueue(items),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
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
                    hosts.isNotEmpty ? hosts : 'Live open catalogs',
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
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
