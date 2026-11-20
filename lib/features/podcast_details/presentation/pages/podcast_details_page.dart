import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/features/podcasts/data/repositories/podcast_repository.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';
import 'package:codecm/features/player/domain/models/episode.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/player/presentation/pages/full_screen_player_page.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/core/utils/html_utils.dart';
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';

class PodcastDetailsPage extends StatefulWidget {
  final Podcast podcast;

  const PodcastDetailsPage({
    super.key,
    required this.podcast,
  });

  @override
  State<PodcastDetailsPage> createState() => _PodcastDetailsPageState();
}

class _PodcastDetailsPageState extends State<PodcastDetailsPage> {
  final PodcastRepository _repository = PodcastRepository();
  int _activeTabIndex = 0;
  bool _isDescriptionExpanded = false;
  late bool _isFollowing;
  List<Episode> _episodes = [];
  bool _isLoadingEpisodes = false;

  final List<String> _tabs = ['Overview', 'Episodes', 'Notes', 'Reviews'];

  @override
  void initState() {
    super.initState();
    _isFollowing = _repository.isFollowing(widget.podcast.id);
    _episodes = PodcastRepository.seedCuratedEpisodes
        .where((e) =>
            e.showTitle.toLowerCase().contains(widget.podcast.title.toLowerCase()) ||
            widget.podcast.title.toLowerCase().contains(e.showTitle.toLowerCase()))
        .toList();
    if (_episodes.isEmpty) {
      _episodes = [
        Episode(
          id: 'ep-${widget.podcast.id}-1',
          title: '${widget.podcast.title}: State of the Art & New Frontiers',
          showTitle: widget.podcast.title,
          host: widget.podcast.hosts,
          durationString: '48m',
          totalDuration: const Duration(minutes: 48),
          artworkUrl: widget.podcast.artworkUrl,
          description: 'Comprehensive breakdown and expert analysis of key industry developments.',
          publishedDate: '2 days ago',
          audioUrl: 'https://traffic.libsyn.com/acquired/acquired-nvidia-preview.mp3',
          semanticMatchScore: 0.97,
        ),
        Episode(
          id: 'ep-${widget.podcast.id}-2',
          title: '${widget.podcast.title}: Foundation Systems and Scaling',
          showTitle: widget.podcast.title,
          host: widget.podcast.hosts,
          durationString: '1h 05m',
          totalDuration: const Duration(hours: 1, minutes: 5),
          artworkUrl: widget.podcast.artworkUrl,
          description: 'A deep exploration into system architecture, design decisions, and tradeoffs.',
          publishedDate: '1 week ago',
          audioUrl: 'https://traffic.libsyn.com/dwarkesh/dwarkesh-sholto.mp3',
          semanticMatchScore: 0.94,
        ),
      ];
    }
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoadingEpisodes = true);
    final list = await _repository.getEpisodesForPodcast(widget.podcast);
    if (mounted) {
      setState(() {
        if (list.isNotEmpty) _episodes = list;
        _isLoadingEpisodes = false;
      });
    }
  }

  void _toggleFollow() {
    PersistentStorage.instance.toggleFollowPodcast(widget.podcast);
    PersistentStorage.instance.toggleBookmark(MediaRepository.podcastToMediaItem(widget.podcast));
    setState(() {
      _isFollowing = PersistentStorage.instance.isFollowingPodcast(widget.podcast.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 74),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Photo (Matching Reference Phone 3)
                _buildHeroImage(context),

                // Main Details Card
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.podcast.title,
                        style: AppTypography.displayEditorial(
                          fontSize: 28,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Location/Host & Duration
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.podcast.hosts,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: AppColors.textTertiary)),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.podcast.episodeCount} episodes',
                            style: AppTypography.bodySm(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rating Row
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.podcast.rating.toStringAsFixed(1)} (${widget.podcast.reviewCount} reviews)',
                            style: AppTypography.monoMetric(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Clean Tab Strip: Overview, Episodes, Notes, Reviews
                      _buildTabStrip(),

                      const SizedBox(height: 20),

                      // 4 Quick Metric Feature Cards
                      _buildQuickMetricsGrid(),

                      const SizedBox(height: 24),

                      // About this show section
                      Text('About this show', style: AppTypography.headlineSm(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(
                        HtmlUtils.clean(widget.podcast.description).isNotEmpty
                            ? HtmlUtils.clean(widget.podcast.description)
                            : 'High-fidelity audio stream from verified source catalog.',
                        style: AppTypography.bodyLg(color: AppColors.textSecondary, fontSize: 14),
                        maxLines: _isDescriptionExpanded ? null : 3,
                        overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isDescriptionExpanded = !_isDescriptionExpanded;
                          });
                        },
                        child: Row(
                          children: [
                            Text(
                              _isDescriptionExpanded ? 'Read less ↑' : 'Read more ↓',
                              style: AppTypography.labelLg(color: AppColors.primary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Episodes Section (or when Episodes tab is selected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Episodes (${_episodes.length})', style: AppTypography.headlineSm(fontSize: 18)),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoadingEpisodes
                      ? const ShimmerListSkeleton(count: 4)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _episodes.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final ep = _episodes[index];
                            return _buildEpisodeItem(context, ep);
                          },
                        ),
                ),
              ],
            ),
          ),

          // 2. Sticky Bottom Bar: Free Stream + "Start listening →"
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return SizedBox(
      height: 310,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero Cover
          Image.network(
            widget.podcast.artworkUrl,
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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.podcasts_rounded, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.podcast.title,
                      style: AppTypography.displayEditorial(fontSize: 22, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Action Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        shape: BoxShape.circle,
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            shape: BoxShape.circle,
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Icon(
                            _isFollowing ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _isFollowing ? AppColors.error : AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: const Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_tabs.length, (index) {
          final isSelected = _activeTabIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeTabIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2.2,
                  ),
                ),
              ),
              child: Text(
                _tabs[index],
                style: AppTypography.labelLg(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuickMetricsGrid() {
    return Row(
      children: [
        _buildMetricCard(Icons.podcasts_rounded, 'Episodes', '${widget.podcast.episodeCount} total'),
        const SizedBox(width: 8),
        _buildMetricCard(Icons.schedule_rounded, 'Cadence', 'Weekly'),
        const SizedBox(width: 8),
        _buildMetricCard(Icons.graphic_eq_rounded, 'Audio', '320k Lossless'),
        const SizedBox(width: 8),
        _buildMetricCard(Icons.auto_awesome_rounded, 'Engine', 'LiteRT AI'),
      ],
    );
  }

  Widget _buildMetricCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textPrimary),
              maxLines: 1,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(BuildContext context, Episode episode) {
    return GestureDetector(
      onTap: () {
        context.read<PlayerBloc>().add(PlayEpisode(episode));
      },
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
                episode.artworkUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 46,
                  height: 46,
                  color: AppColors.primaryContainer,
                  child: const Icon(Icons.podcasts, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${episode.publishedDate} • ${episode.durationString}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context) {
    final firstEpisode = _episodes.isNotEmpty
        ? _episodes.first
        : Episode(
            id: 'default-${widget.podcast.id}',
            title: '${widget.podcast.title} Latest',
            showTitle: widget.podcast.title,
            host: widget.podcast.hosts,
            durationString: '48m',
            totalDuration: const Duration(minutes: 48),
            artworkUrl: widget.podcast.artworkUrl,
            description: widget.podcast.description,
            publishedDate: 'Today',
            audioUrl: 'https://traffic.libsyn.com/acquired/acquired-nvidia-preview.mp3',
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lossless Audio',
                  style: AppTypography.displayEditorial(fontSize: 16, color: AppColors.textPrimary),
                ),
                const Text(
                  'Open RSS Stream',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                context.read<PlayerBloc>().add(PlayEpisode(firstEpisode));
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FullScreenPlayerPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Start listening',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
