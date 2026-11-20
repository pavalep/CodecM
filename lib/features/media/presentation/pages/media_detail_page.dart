import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/utils/html_utils.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/player/domain/models/episode.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/player/presentation/pages/full_screen_player_page.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';

class MediaDetailPage extends StatefulWidget {
  final MediaItem item;

  const MediaDetailPage({
    super.key,
    required this.item,
  });

  @override
  State<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends State<MediaDetailPage> {
  final MediaRepository _repository = MediaRepository();
  bool _isScrolled = false;
  int _activeTabIndex = 0;
  bool _isDescriptionExpanded = false;
  late bool _isFavorite;
  List<Episode> _episodes = [];
  bool _isLoading = false;

  final List<String> _tabs = ['Overview', 'Content', 'Notes', 'Reviews'];

  bool get _isVideo =>
      widget.item.lane == MediaLane.video ||
      widget.item.kind == MediaKind.show ||
      widget.item.kind == MediaKind.movie;

  @override
  void initState() {
    super.initState();
    _isFavorite = _repository.isBookmarked(widget.item.id);
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    if (widget.item.kind == MediaKind.podcast) {
      final podcast = Podcast(
        id: widget.item.id,
        title: widget.item.title,
        subtitle: widget.item.subtitle ?? widget.item.creator,
        hosts: widget.item.creator,
        artworkUrl: widget.item.artworkUrl,
        description: widget.item.description,
        rating: widget.item.rating,
        reviewCount: widget.item.reviewCount,
        episodeCount: widget.item.episodesCount,
      );
      final eps = await _repository.getEpisodesForPodcast(podcast);
      if (mounted) {
        setState(() {
          _episodes = eps;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _episodes = [
          Episode(
            id: widget.item.id,
            title: widget.item.title,
            showTitle: widget.item.creator,
            host: widget.item.creator,
            durationString: widget.item.durationString,
            totalDuration: Duration(seconds: widget.item.durationSeconds > 0 ? widget.item.durationSeconds : 180),
            artworkUrl: widget.item.artworkUrl,
            description: widget.item.description,
            publishedDate: widget.item.publishedDate ?? 'Now Live',
            audioUrl: widget.item.streamUrl,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  void _toggleFavorite() {
    setState(() {
      _repository.toggleBookmarkItem(widget.item);
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _playVideoContent() async {
    _repository.addToRecentlyPlayed(widget.item);
    MediaItem itemToPlay = widget.item;
    if (itemToPlay.kind == MediaKind.movie && itemToPlay.id.startsWith('ia-')) {
      final rawId = itemToPlay.id.substring(3);
      final resolved = await _repository.resolveMovieStreamUrl(rawId);
      if (resolved.isNotEmpty) {
        itemToPlay = itemToPlay.copyWith(streamUrl: resolved);
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(item: itemToPlay),
      ),
    );
  }

  void _playContent(Episode ep) {
    _repository.addToRecentlyPlayed(widget.item);

    if (_isVideo) {
      _playVideoContent();
      return;
    }

    context.read<PlayerBloc>().add(PlayEpisode(ep));
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const FullScreenPlayerPage(),
        transitionsBuilder: (context, anim, secAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Scrollable Content Body with Scroll Notification
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final scrolled = notification.metrics.pixels > 80;
              if (scrolled != _isScrolled) {
                setState(() => _isScrolled = scrolled);
              }
              return false;
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Hero Photo (Matching Reference Phone 3)
                  _buildHeroImage(context),

            // Main Details Card with Embedded Play Button
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.item.title,
                          style: AppTypography.displayEditorial(
                            fontSize: 24,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Location / Creator & Kind
                        Row(
                          children: [
                            Icon(
                              _isVideo ? Icons.tv_rounded : Icons.location_on_outlined,
                              color: AppColors.textSecondary,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${widget.item.creator} • ${widget.item.kind.displayName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Rating & Duration Row
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.item.rating.toStringAsFixed(1)} (${widget.item.reviewCount} reviews)',
                              style: AppTypography.labelLg(color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${widget.item.durationString}',
                              style: AppTypography.bodySm(color: AppColors.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Embedded Action Play Button
                  GestureDetector(
                    onTap: () {
                      if (_isVideo) {
                        _playVideoContent();
                      } else {
                        final ep = _episodes.isNotEmpty
                            ? _episodes.first
                            : MediaRepository.mediaItemToEpisode(widget.item);
                        _playContent(ep);
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isVideo ? Icons.videocam_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),

                const Divider(height: 1, color: AppColors.border),

                // 4-Tab Navigation Bar (Matching Reference Phone 3: Overview, Tracks, Notes, Reviews)
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_tabs.length, (index) {
                      final isSelected = _activeTabIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _activeTabIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            _tabs[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                // 4 Metric Pill Cards (Matching Reference Phone 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: _isVideo
                        ? [
                            _buildMetricCard(Icons.live_tv_rounded, 'Broadcast', 'HD Video'),
                            const SizedBox(width: 8),
                            _buildMetricCard(Icons.hd_rounded, 'Resolution', '1080p / 720p'),
                            const SizedBox(width: 8),
                            _buildMetricCard(Icons.volume_up_rounded, 'Audio', 'Stereo AAC'),
                            const SizedBox(width: 8),
                            _buildMetricCard(Icons.stream_rounded, 'Protocol', 'HLS Stream'),
                          ]
                        : [
                            _buildMetricCard(Icons.podcasts_rounded, widget.item.kind.displayName, '${widget.item.episodesCount} total'),
                            const SizedBox(width: 8),
                            _buildMetricCard(Icons.access_time_rounded, 'Duration', widget.item.durationString),
                            const SizedBox(width: 8),
                            _buildMetricCard(Icons.graphic_eq_rounded, 'Audio', 'Lossless'),
                            const SizedBox(width: 8),
                            _buildMetricCard(Icons.verified_rounded, 'Verified', 'Official RSS'),
                          ],
                  ),
                ),

                const SizedBox(height: 20),

                // About Section (Matching Reference Phone 3: "About this trip" -> "About this release")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About this ${widget.item.kind.displayName.toLowerCase()}', style: AppTypography.headlineSm(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(
                        HtmlUtils.clean(widget.item.description).isNotEmpty
                            ? HtmlUtils.clean(widget.item.description)
                            : 'High-fidelity audio stream from verified source catalog.',
                        maxLines: _isDescriptionExpanded ? 100 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd(color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                        child: Row(
                          children: [
                            Text(
                              _isDescriptionExpanded ? 'Read less ↑' : 'Read more ↓',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Episodes / Content Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _isVideo ? 'Broadcast Channels' : 'Episodes & Tracks (${_episodes.length})',
                    style: AppTypography.headlineSm(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoading
                      ? const ShimmerListSkeleton(count: 3)
                      : _episodes.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  _isVideo ? 'Live broadcast ready. Tap "Watch video" below.' : 'No tracks currently listed.',
                                  style: AppTypography.bodySm(color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
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
        ),

          // 2. Persistent Top Action Header (Pinned at Top of Screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _isScrolled ? 16 : 0,
                  sigmaY: _isScrolled ? 16 : 0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _isScrolled
                        ? AppColors.surface.withValues(alpha: 0.94)
                        : Colors.transparent,
                    border: _isScrolled
                        ? const Border(bottom: BorderSide(color: AppColors.border, width: 0.8))
                        : null,
                    boxShadow: _isScrolled
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Back Button
                          _buildCircleActionButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),

                          // Animated Centered Title when scrolled
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _isScrolled ? 1.0 : 0.0,
                              child: Text(
                                widget.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Actions Right: Favorite & Share
                          Row(
                            children: [
                              _buildCircleActionButton(
                                icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isFavorite ? AppColors.error : AppColors.textPrimary,
                                onTap: _toggleFavorite,
                              ),
                              const SizedBox(width: 10),
                              _buildCircleActionButton(
                                icon: Icons.share_outlined,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Media link copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
            widget.item.artworkUrl,
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
                child: Icon(
                  _isVideo ? Icons.tv_rounded : Icons.music_note_rounded,
                  size: 72,
                  color: Colors.white24,
                ),
              ),
            ),
          ),

          // Gentle Gradient Overlay for Readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 19),
      ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(BuildContext context, Episode ep) {
    return GestureDetector(
      onTap: () => _playContent(ep),
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
                ep.artworkUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 46,
                  height: 46,
                  color: AppColors.primaryContainer,
                  child: Icon(
                    _isVideo ? Icons.tv_rounded : Icons.music_note_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.title,
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
                    '${ep.publishedDate} • ${ep.durationString}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
}
