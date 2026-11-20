import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/core/widgets/browse_list_footer.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = const [
    {'title': 'All', 'kind': null},
    {'title': 'Movies', 'kind': MediaKind.movie},
    {'title': 'Podcasts', 'kind': MediaKind.podcast},
    {'title': 'Music', 'kind': MediaKind.music},
    {'title': 'Radio', 'kind': MediaKind.radio},
    {'title': 'Shows', 'kind': MediaKind.show},
    {'title': 'Audiobooks', 'kind': MediaKind.audiobook},
  ];

  int _selectedCategoryIndex = 0;
  List<MediaItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryData() async {
    setState(() => _isLoading = true);
    final selectedKind = _categories[_selectedCategoryIndex]['kind'] as MediaKind?;
    final query = _searchController.text.trim();

    List<MediaItem> result;
    if (query.isNotEmpty) {
      result = await _repository.searchMedia(query, kind: selectedKind);
    } else {
      switch (selectedKind) {
        case MediaKind.music:
          result = await _repository.getPopularMusic();
          break;
        case MediaKind.radio:
          result = await _repository.getPopularRadio();
          break;
        case MediaKind.show:
          result = await _repository.getPopularShows();
          break;
        case MediaKind.movie:
          result = await _repository.getPopularMovies();
          break;
        case MediaKind.audiobook:
          result = await _repository.getPopularAudiobooks();
          break;
        case MediaKind.podcast:
          final pods = await _repository.getTrendingPodcasts();
          result = pods.map((p) => MediaRepository.podcastToMediaItem(p)).toList();
          break;
        case null:
        default:
          final futures = await Future.wait([
            _repository.getTrendingPodcasts(),
            _repository.getPopularMovies(),
            _repository.getPopularMusic(),
            _repository.getPopularRadio(),
            _repository.getPopularShows(),
            _repository.getPopularAudiobooks(),
          ]);
          final pods = (futures[0] as List).take(3).map((p) => MediaRepository.podcastToMediaItem(p)).toList();
          final movies = (futures[1] as List<MediaItem>).take(3).toList();
          final music = (futures[2] as List<MediaItem>).take(3).toList();
          final radio = (futures[3] as List<MediaItem>).take(3).toList();
          final shows = (futures[4] as List<MediaItem>).take(3).toList();
          final books = (futures[5] as List<MediaItem>).take(3).toList();
          result = [...movies, ...pods, ...music, ...radio, ...shows, ...books];
          break;
      }
    }

    if (mounted) {
      setState(() {
        _items = result;
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
    _loadCategoryData();
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'category',
        title: 'Category Scope',
        multiSelect: false,
        options: _categories.asMap().entries.map((entry) => FilterOption(
          key: entry.key.toString(),
          label: entry.value['title'] as String,
        )).toList(),
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'category': [_selectedCategoryIndex.toString()],
      },
    );

    if (result != null && mounted) {
      final keyStr = result['category']?.firstOrNull;
      if (keyStr != null) {
        final idx = int.tryParse(keyStr);
        if (idx != null && idx != _selectedCategoryIndex) {
          _onCategorySelected(idx);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showcaseItem = _items.isNotEmpty ? _items.first : null;
    final otherItems = _items.length > 1 ? _items.sublist(1) : <MediaItem>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Filter Icon Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Explore Media', style: AppTypography.displayEditorial(fontSize: 22)),
                          const SizedBox(height: 2),
                          const Text(
                            'Discover cinema, podcasts, music, and broadcasts.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterIconButton(
                      onTap: _openFilterSheet,
                      activeCount: _selectedCategoryIndex > 0 ? 1 : 0,
                    ),
                  ],
                ),
              ),

              // 1. Unified Search Bar (44dp, 12dp radius, 1px border)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Search podcasts, movies, music, radio...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _loadCategoryData(),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _loadCategoryData();
                          },
                          child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Horizontal Category Scope Chips (10dp radius, 1px border)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategoryIndex == index;
                    return GestureDetector(
                      onTap: () => _onCategorySelected(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          cat['title'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 3. Showcase Card (14dp radius, crisp 1px border, zero blurry shadow)
              if (showcaseItem != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildShowcaseCard(context, showcaseItem),
                )
              else if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ShimmerShowcaseSkeleton(),
                ),

              const SizedBox(height: 20),

              // 4. "Best experiences for you" Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Best experiences for you', style: AppTypography.headlineSm(fontSize: 17)),
                    Text(
                      'View all',
                      style: AppTypography.labelLg(
                        color: AppColors.primary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isLoading
                    ? const ShimmerListSkeleton(count: 4)
                    : otherItems.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Text('No items found in this category.'),
                            ),
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < otherItems.length; i++) ...[
                                _buildExperienceTile(context, otherItems[i]),
                                if (i < otherItems.length - 1) const SizedBox(height: 10),
                              ],
                              BrowseListFooter(
                                reachedEnd: true,
                                shown: otherItems.length,
                                endLabel: "You're all caught up.",
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseCard(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MediaDetailPage(item: item)),
        );
      },
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item.artworkUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  color: AppColors.primaryDark,
                  child: const Center(
                    child: Icon(Icons.explore_rounded, size: 54, color: Colors.white24),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Recommended',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _repository.toggleBookmarkItem(item);
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _repository.isBookmarked(item.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _repository.isBookmarked(item.id) ? AppColors.error : Colors.white,
                      size: 17,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.creator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '${item.formattedRating} (${item.reviewCount})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          item.durationString,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.kind.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceTile(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MediaDetailPage(item: item)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                item.artworkUrl,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 62,
                  height: 62,
                  color: AppColors.primaryContainer,
                  child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
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
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.creator} • ${item.kind.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.amber, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        item.formattedRating,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.durationString,
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                if (item.lane == MediaLane.video || item.kind == MediaKind.show || item.kind == MediaKind.movie) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VideoPlayerPage(item: item)),
                  );
                } else {
                  final ep = MediaRepository.mediaItemToEpisode(item);
                  context.read<PlayerBloc>().add(PlayEpisode(ep));
                }
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
