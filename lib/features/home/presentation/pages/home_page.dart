import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/core/widgets/browse_list_footer.dart';
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/features/home/presentation/bloc/home_bloc.dart';
import 'package:codecm/features/home/presentation/bloc/home_event.dart';
import 'package:codecm/features/home/presentation/bloc/home_state.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/podcast_details/presentation/pages/podcast_details_page.dart';
import 'package:codecm/features/music/presentation/pages/music_page.dart';
import 'package:codecm/features/radio/presentation/pages/radio_page.dart';
import 'package:codecm/features/shows/presentation/pages/shows_page.dart';
import 'package:codecm/features/audiobooks/presentation/pages/audiobooks_page.dart';
import 'package:codecm/features/movies/presentation/pages/movies_page.dart';
import 'package:codecm/features/search/presentation/pages/search_page.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';
import 'package:codecm/features/saved/presentation/pages/saved_page.dart';
import 'package:codecm/features/library/presentation/pages/library_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc()..add(const LoadHomeData()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _selectedSort = 'recommended';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'all') count++;
    if (_selectedSort != 'recommended') count++;
    return count;
  }

  Future<void> _openHomeFilterSheet() async {
    final filterGroups = [
      const FilterGroup(
        id: 'category',
        title: 'Content Scope',
        multiSelect: false,
        options: [
          FilterOption(key: 'all', label: 'All Content', icon: Icons.auto_awesome_rounded),
          FilterOption(key: 'movies', label: 'Movies & Cinema', icon: Icons.movie_creation_outlined),
          FilterOption(key: 'shows', label: 'TV Shows & Live TV', icon: Icons.tv_rounded),
          FilterOption(key: 'podcasts', label: 'Podcasts', icon: Icons.podcasts_rounded),
          FilterOption(key: 'music', label: 'Music', icon: Icons.music_note_rounded),
          FilterOption(key: 'radio', label: 'Radio Broadcasts', icon: Icons.radio_rounded),
          FilterOption(key: 'audiobooks', label: 'Audiobooks', icon: Icons.auto_stories_rounded),
        ],
      ),
      const FilterGroup(
        id: 'sort',
        title: 'Sort Order',
        multiSelect: false,
        options: [
          FilterOption(key: 'recommended', label: 'Recommended', icon: Icons.thumb_up_rounded),
          FilterOption(key: 'rating', label: 'Highest Rated', icon: Icons.star_rounded),
          FilterOption(key: 'az', label: 'A to Z', icon: Icons.sort_by_alpha_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'category': [_selectedCategory],
        'sort': [_selectedSort],
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCategory = result['category']?.firstOrNull ?? 'all';
        _selectedSort = result['sort']?.firstOrNull ?? 'recommended';
      });
    }
  }

  void _navigateToSearch(String query) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchPage(initialQuery: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          final isLoading = state.status == HomeStatus.loading;
          final movies = state.popularMovies;
          final music = state.popularMusic;
          final radio = state.popularRadio;
          final podcasts = state.trendingPodcasts;
          var bestForYou = List<MediaItem>.from(state.bestForYou);

          // Apply in-memory category filter if user selected one
          if (_selectedCategory == 'movies') {
            bestForYou = state.popularMovies;
          } else if (_selectedCategory == 'shows') {
            bestForYou = state.popularShows;
          } else if (_selectedCategory == 'music') {
            bestForYou = state.popularMusic;
          } else if (_selectedCategory == 'radio') {
            bestForYou = state.popularRadio;
          } else if (_selectedCategory == 'audiobooks') {
            bestForYou = state.popularAudiobooks;
          }

          // Search text filtering for in-page query
          final searchQuery = _searchController.text.trim().toLowerCase();
          if (searchQuery.isNotEmpty) {
            bestForYou = bestForYou.where((item) {
              return item.title.toLowerCase().contains(searchQuery) ||
                  item.creator.toLowerCase().contains(searchQuery) ||
                  item.category.toLowerCase().contains(searchQuery);
            }).toList();
          }

          if (_selectedSort == 'rating') {
            bestForYou.sort((a, b) => b.rating.compareTo(a.rating));
          } else if (_selectedSort == 'az') {
            bestForYou.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          }

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                context.read<HomeBloc>().add(const LoadHomeData(refresh: true));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Sleek Modern Header (Wordmark left, Weather Pill & Filter right)
                    _buildCleanHeader(context, state),

                  // 2. In-Page Search Bar (44dp, 12dp radius, 1px border)
                  _buildSearchBar(context),

                  const SizedBox(height: 12),

                  // 3. Category Quick Rail (6 modules)
                  _buildCategoryRail(context),

                  const SizedBox(height: 16),

                  // 4. PERSISTENT SECTION: "Jump Back In" (Recent History)
                  _buildRecentHistorySection(context),

                  // 5. PERSISTENT SECTION: "Your Subscriptions" (Followed Podcasts)
                  _buildFollowedPodcastsSection(context),

                  // 6. PERSISTENT SECTION: "Saved Bookmarks"
                  _buildSavedBookmarksSection(context),

                  // 7. PUBLIC DOMAIN CINEMA & MOVIES
                  _buildFeaturedCinemaSection(context, movies, isLoading),

                  // 8. POPULAR SHOWS & PODCASTS
                  _buildTrendingPodcastsSection(context, podcasts, isLoading),

                  // 9. CURATED MUSIC & LIVE RADIO
                  _buildMusicAndRadioSection(context, music, radio, isLoading),

                  // 10. BEST FOR YOU (Editorial Mix)
                  _buildBestForYouSection(context, bestForYou, isLoading),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  // 1. Sleek, minimal Google M3 Top App Bar (Wordmark + Live Weather underneath + Filter)
  Widget _buildCleanHeader(BuildContext context, HomeState state) {
    final weatherSummary = state.weather?.summary ?? '10°C • Partly cloudy';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Logo + Wordmark with Live Weather underneath
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Image.asset(
                      'assets/images/app_logo_green.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CodecM',
                        style: AppTypography.displayEditorial(
                          fontSize: 21,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny_outlined, color: AppColors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            weatherSummary,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right: Filter Button
            FilterIconButton(
              onTap: _openHomeFilterSheet,
              activeCount: _activeFilterCount,
            ),
          ],
        ),
      );
    }

  // 2. In-Page Search Bar (44dp, 12dp radius, 1px border)
  Widget _buildSearchBar(BuildContext context) {
    return Padding(
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
                onChanged: (_) => setState(() {}),
                onSubmitted: (query) => _navigateToSearch(query),
                style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search cinema, podcasts, music, radio...',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {});
                },
                child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
              )
            else
              GestureDetector(
                onTap: () => _navigateToSearch(_searchController.text),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 3. Category Quick Rail (6 modules)
  Widget _buildCategoryRail(BuildContext context) {
    final categories = [
      {'title': 'Movies', 'icon': Icons.movie_creation_outlined, 'page': const MoviesPage()},
      {'title': 'TV Shows', 'icon': Icons.tv_rounded, 'page': const ShowsPage()},
      {'title': 'Music', 'icon': Icons.music_note_rounded, 'page': const MusicPage()},
      {'title': 'Radio', 'icon': Icons.radio_rounded, 'page': const RadioPage()},
      {'title': 'Audiobooks', 'icon': Icons.auto_stories_rounded, 'page': const AudiobooksPage()},
      {'title': 'Search', 'icon': Icons.search_rounded, 'page': const SearchPage()},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => cat['page'] as Widget),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    cat['title'] as String,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. PERSISTENT: "Jump Back In" (Recent History)
  Widget _buildRecentHistorySection(BuildContext context) {
    return ValueListenableBuilder<List<MediaItem>>(
      valueListenable: PersistentStorage.instance.recentHistoryNotifier,
      builder: (context, history, _) {
        if (history.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Jump Back In', style: AppTypography.headlineSm(fontSize: 17)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SavedPage(initialSegment: 1)),
                      );
                    },
                    child: Text('History (${history.length})', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return _buildRecentItemCard(context, item);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildRecentItemCard(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () => _playItem(context, item),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with play button overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Image.network(
                    item.artworkUrl,
                    width: 130,
                    height: 82,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      width: 130,
                      height: 82,
                      color: AppColors.primaryContainer,
                      child: Icon(
                        item.isVideo ? Icons.movie_outlined : Icons.music_note_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 16),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.kind.displayName.toUpperCase(),
                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. PERSISTENT: "Your Subscriptions" (Followed Podcasts)
  Widget _buildFollowedPodcastsSection(BuildContext context) {
    return ValueListenableBuilder<List<Podcast>>(
      valueListenable: PersistentStorage.instance.followedPodcastsNotifier,
      builder: (context, followedList, _) {
        if (followedList.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rss_feed_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Your Subscriptions', style: AppTypography.headlineSm(fontSize: 17)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LibraryPage()),
                      );
                    },
                    child: Text('All (${followedList.length})', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: followedList.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final pod = followedList[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: pod)),
                      );
                    },
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              pod.artworkUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 60,
                                height: 60,
                                color: AppColors.primaryContainer,
                                child: const Icon(Icons.podcasts_rounded, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            pod.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // 6. PERSISTENT: "Saved Bookmarks"
  Widget _buildSavedBookmarksSection(BuildContext context) {
    return ValueListenableBuilder<List<MediaItem>>(
      valueListenable: PersistentStorage.instance.bookmarksNotifier,
      builder: (context, bookmarks, _) {
        if (bookmarks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 17, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text('Saved Bookmarks', style: AppTypography.headlineSm(fontSize: 17)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SavedPage(initialSegment: 0)),
                      );
                    },
                    child: Text('All (${bookmarks.length})', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bookmarks.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = bookmarks[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MediaDetailPage(item: item)),
                      );
                    },
                    child: Container(
                      width: 190,
                      padding: const EdgeInsets.all(8),
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
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 54,
                                height: 54,
                                color: AppColors.primaryContainer,
                                child: const Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.creator,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // 7. Feature Cinema & Classic Films (Internet Archive)
  Widget _buildFeaturedCinemaSection(BuildContext context, List<MediaItem> movies, bool isLoading) {
    if (!isLoading && movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Classic Cinema & Films', style: AppTypography.headlineSm(fontSize: 17)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MoviesPage()),
                  );
                },
                child: Text('View all', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        isLoading && movies.isEmpty
            ? const ShimmerCarouselSkeleton()
            : SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: movies.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return _buildCinemaPosterCard(context, movie);
                  },
                ),
              ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildCinemaPosterCard(BuildContext context, MediaItem movie) {
    return GestureDetector(
      onTap: () => _playItem(context, movie),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                movie.artworkUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  color: AppColors.primaryDark,
                  child: const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white38, size: 40)),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('PUBLIC DOMAIN', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.amber, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          movie.formattedRating,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          movie.durationString,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 8. Trending Shows & Podcasts
  Widget _buildTrendingPodcastsSection(BuildContext context, List<Podcast> podcasts, bool isLoading) {
    if (!isLoading && podcasts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trending Shows & Podcasts', style: AppTypography.headlineSm(fontSize: 17)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  );
                },
                child: Text('View all', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        isLoading && podcasts.isEmpty
            ? const ShimmerCarouselSkeleton()
            : SizedBox(
                height: 185,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: podcasts.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final pod = podcasts[index];
                    return _buildPodcastCard(context, pod);
                  },
                ),
              ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildPodcastCard(BuildContext context, Podcast podcast) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaDetailPage(
              item: MediaRepository.podcastToMediaItem(podcast),
            ),
          ),
        );
      },
      child: Container(
        width: 136,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                podcast.artworkUrl,
                width: 136,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 136,
                  height: 110,
                  color: AppColors.primaryContainer,
                  child: const Center(child: Icon(Icons.podcasts_rounded, color: AppColors.primary, size: 36)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.amber, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          podcast.formattedRating,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${podcast.episodeCount} eps',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
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

  // 9. Curated Music & Live Radio
  Widget _buildMusicAndRadioSection(BuildContext context, List<MediaItem> music, List<MediaItem> radio, bool isLoading) {
    final combined = [...music.take(3), ...radio.take(3)];
    if (!isLoading && combined.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Music & Live Broadcasts', style: AppTypography.headlineSm(fontSize: 17)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MusicPage()),
                  );
                },
                child: Text('View all', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: combined.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = combined[index];
              return _buildMusicRadioCard(context, item);
            },
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildMusicRadioCard(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () => _playItem(context, item),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Image.network(
                item.artworkUrl,
                width: 130,
                height: 75,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 130,
                  height: 75,
                  color: AppColors.primaryContainer,
                  child: Icon(
                    item.kind == MediaKind.radio ? Icons.radio_rounded : Icons.music_note_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 10. Best For You Section
  Widget _buildBestForYouSection(BuildContext context, List<MediaItem> bestForYou, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Best for you', style: AppTypography.headlineSm(fontSize: 17)),
                  if (_selectedCategory != 'all') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedCategory.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  );
                },
                child: Text('View all', style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isLoading && bestForYou.isEmpty
              ? const ShimmerListSkeleton(count: 4)
              : Column(
                  children: [
                    for (int i = 0; i < bestForYou.length; i++) ...[
                      _buildMediaTile(context, bestForYou[i]),
                      if (i < bestForYou.length - 1) const SizedBox(height: 10),
                    ],
                    BrowseListFooter(
                      reachedEnd: true,
                      shown: bestForYou.length,
                      endLabel: "You're all caught up with your feed.",
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMediaTile(BuildContext context, MediaItem item) {
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
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 58,
                  height: 58,
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
              onTap: () => _playItem(context, item),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playItem(BuildContext context, MediaItem item) {
    if (item.lane == MediaLane.video || item.kind == MediaKind.show || item.kind == MediaKind.movie) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerPage(item: item)),
      );
    } else {
      final ep = MediaRepository.mediaItemToEpisode(item);
      context.read<PlayerBloc>().add(PlayEpisode(ep));
    }
  }
}
