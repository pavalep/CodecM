import 'dart:async';
import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  final List<Map<String, String>> _categories = [
    {
      'id': 'all',
      'label': 'All Movies',
      'query': 'collection:(feature_films OR silent_films OR short_films)',
    },
    {
      'id': 'classic-films',
      'label': 'Classic Films',
      'query': 'subject:"classic films"',
    },
    {
      'id': 'public-domain',
      'label': 'Public Domain',
      'query': 'subject:"public domain"',
    },
    {
      'id': 'sci-fi',
      'label': 'Sci-Fi & Fantasy',
      'query': 'subject:"sci-fi"',
    },
    {
      'id': 'comedy',
      'label': 'Comedy',
      'query': 'subject:"comedy"',
    },
    {
      'id': 'film-noir',
      'label': 'Film Noir',
      'query': 'subject:"film noir"',
    },
    {
      'id': 'silent-films',
      'label': 'Silent Films',
      'query': 'collection:silent_films',
    },
    {
      'id': 'animation',
      'label': 'Animation',
      'query': 'subject:"animation"',
    },
  ];

  int _selectedCategoryIndex = 0;
  String _selectedSort = 'downloads desc';
  List<MediaItem> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    setState(() => _isLoading = true);
    final query = _searchController.text.trim();

    List<MediaItem> list;
    if (query.isNotEmpty) {
      list = await _repository.searchMovies(query);
    } else {
      final categoryQuery = _categories[_selectedCategoryIndex]['query'];
      list = await _repository.getPopularMovies(
        categoryQuery: categoryQuery,
        sort: _selectedSort,
      );
    }

    if (mounted) {
      setState(() {
        _movies = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadMovies();
    });
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
    _loadMovies();
  }

  void _onSortSelected(String sortKey) {
    setState(() {
      _selectedSort = sortKey;
    });
    _loadMovies();
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'category',
        title: 'Category',
        multiSelect: false,
        options: _categories.map((c) => FilterOption(key: c['id']!, label: c['label']!)).toList(),
      ),
      const FilterGroup(
        id: 'sort',
        title: 'Sort by',
        multiSelect: false,
        options: [
          FilterOption(key: 'downloads desc', label: 'Most popular', icon: Icons.trending_up_rounded),
          FilterOption(key: 'addeddate desc', label: 'Recently added', icon: Icons.schedule_rounded),
          FilterOption(key: 'title asc', label: 'A–Z', icon: Icons.sort_by_alpha_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'category': [_categories[_selectedCategoryIndex]['id']!],
        'sort': [_selectedSort],
      },
    );

    if (result != null && mounted) {
      final selectedCatId = result['category']?.firstOrNull;
      if (selectedCatId != null) {
        final idx = _categories.indexWhere((c) => c['id'] == selectedCatId);
        if (idx != -1) _selectedCategoryIndex = idx;
      }
      final sortVal = result['sort']?.firstOrNull;
      if (sortVal != null) {
        _selectedSort = sortVal;
      }
      _loadMovies();
    }
  }

  Future<void> _playMovie(MediaItem item, [List<MediaItem>? list, int? index]) async {
    _repository.addToRecentlyPlayed(item);

    // Resolve exact streaming URL from Internet Archive metadata if necessary
    String streamUrl = item.streamUrl;
    if (item.id.startsWith('ia-')) {
      final rawId = item.id.substring(3);
      final resolved = await _repository.resolveMovieStreamUrl(rawId);
      if (resolved.isNotEmpty) {
        streamUrl = resolved;
      }
    }

    if (!mounted) return;
    final playableItem = item.copyWith(streamUrl: streamUrl);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          item: playableItem,
          playlist: list,
          initialIndex: index ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Movies & Cinema',
          style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.primary),
            tooltip: 'Sort Movies',
            onSelected: _onSortSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'downloads desc',
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: _selectedSort == 'downloads desc' ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Most popular',
                      style: TextStyle(
                        fontWeight: _selectedSort == 'downloads desc' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedSort == 'downloads desc' ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'addeddate desc',
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: _selectedSort == 'addeddate desc' ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recently added',
                      style: TextStyle(
                        fontWeight: _selectedSort == 'addeddate desc' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedSort == 'addeddate desc' ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'title asc',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha_rounded,
                      size: 18,
                      color: _selectedSort == 'title asc' ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'A–Z',
                      style: TextStyle(
                        fontWeight: _selectedSort == 'title asc' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedSort == 'title asc' ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Dedicated Search Bar & Universal Filter (Spec 24: search: {placeholder: 'Search movies…'})
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search movies…',
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
                              _loadMovies();
                            },
                            child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterIconButton(
                  activeCount: _selectedCategoryIndex > 0 || _selectedSort != 'downloads desc' ? 1 : 0,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),

          // 2. Horizontal Category Filter Chips (Spec 24: Movie Categories)
          SizedBox(
            height: 38,
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
                    child: Center(
                      child: Text(
                        cat['label']!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // 3. Movie Grid Content
          Expanded(
            child: _isLoading
                ? const ShimmerGridSkeleton(
                    count: 6,
                    childAspectRatio: 0.65,
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 24),
                  )
                : _movies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.movie_filter_rounded, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'No movies found matching your query.',
                              style: AppTypography.bodyMd(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _movies.length,
                        itemBuilder: (context, index) {
                          final item = _movies[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MediaDetailPage(item: item),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Movie Poster
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            item.artworkUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [AppColors.primaryDark, AppColors.primary],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.movie_rounded, color: Colors.white38, size: 38),
                                              ),
                                            ),
                                          ),
                                          // Year / Tag Badge
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                item.subtitle ?? 'Film',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Play Button Overlay
                                          Center(
                                            child: GestureDetector(
                                              onTap: () => _playMovie(item, _movies, index),
                                              child: Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.9),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.3),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Details
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.creator,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: AppColors.amber, size: 14),
                                            const SizedBox(width: 3),
                                            Text(
                                              item.rating.toStringAsFixed(1),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                            const Spacer(),
                                            Text(
                                              item.durationString,
                                              style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                                            ),
                                          ],
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
        ],
      ),
    );
  }
}
