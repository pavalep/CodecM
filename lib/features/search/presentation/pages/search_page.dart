import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';
import 'package:codecm/features/player/presentation/pages/full_screen_player_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  final MediaKind? initialKind;

  const SearchPage({
    super.key,
    this.initialQuery,
    this.initialKind,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final MediaRepository _repository = MediaRepository();
  Timer? _debounce;

  List<MediaItem> _searchResults = [];
  bool _isLoading = false;
  MediaKind? _selectedKind;

  // Filter sheet state
  String _selectedSort = 'relevance';
  Map<String, List<String>> _activeFilters = {
    'kind': ['all'],
    'sort': ['relevance'],
  };

  // Recent searches stored dynamically as the user searches
  final List<String> _recentSearches = [];

  final List<Map<String, dynamic>> _scopeTabs = [
    {'label': 'All', 'kind': null},
    {'label': 'Movies', 'kind': MediaKind.movie},
    {'label': 'Podcasts', 'kind': MediaKind.podcast},
    {'label': 'Music', 'kind': MediaKind.music},
    {'label': 'Radio', 'kind': MediaKind.radio},
    {'label': 'Shows', 'kind': MediaKind.show},
    {'label': 'Audiobooks', 'kind': MediaKind.audiobook},
  ];

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKind;
    if (_selectedKind != null) {
      _activeFilters['kind'] = [_selectedKind!.name];
    }
    final initial = widget.initialQuery ?? 'Cinema';
    _controller.text = initial;
    _performSearch(initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    // Save query to recent searches
    if (!_recentSearches.contains(clean)) {
      _recentSearches.insert(0, clean);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }

    List<MediaItem> results;
    try {
      results = await _repository.searchMedia(clean, kind: _selectedKind);
    } catch (_) {
      results = [];
    }

    // Apply sort
    if (_selectedSort == 'rating') {
      results.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSort == 'az') {
      results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _selectTab(MediaKind? kind) {
    setState(() {
      _selectedKind = kind;
      _activeFilters['kind'] = [kind?.name ?? 'all'];
    });
    _performSearch(_controller.text);
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'kind',
        title: 'Media Type',
        multiSelect: false,
        options: const [
          FilterOption(key: 'all', label: 'All Media', icon: Icons.auto_awesome_rounded),
          FilterOption(key: 'movie', label: 'Movies & Cinema', icon: Icons.movie_creation_outlined),
          FilterOption(key: 'podcast', label: 'Podcasts', icon: Icons.podcasts_rounded),
          FilterOption(key: 'music', label: 'Music Tracks', icon: Icons.music_note_rounded),
          FilterOption(key: 'radio', label: 'Radio Broadcasts', icon: Icons.radio_rounded),
          FilterOption(key: 'show', label: 'TV Shows & Series', icon: Icons.tv_rounded),
          FilterOption(key: 'audiobook', label: 'Audiobooks', icon: Icons.auto_stories_rounded),
        ],
      ),
      FilterGroup(
        id: 'sort',
        title: 'Sort Order',
        multiSelect: false,
        options: const [
          FilterOption(key: 'relevance', label: 'Most Relevant', icon: Icons.tune_rounded),
          FilterOption(key: 'rating', label: 'Highest Rated', icon: Icons.star_rounded),
          FilterOption(key: 'az', label: 'A to Z Alphabetical', icon: Icons.sort_by_alpha_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: _activeFilters,
      onReset: () {
        setState(() {
          _activeFilters = {
            'kind': ['all'],
            'sort': ['relevance'],
          };
          _selectedKind = null;
          _selectedSort = 'relevance';
        });
        _performSearch(_controller.text);
      },
    );

    if (result != null && mounted) {
      setState(() {
        _activeFilters = result;
        final selectedKindKey = result['kind']?.firstOrNull ?? 'all';
        if (selectedKindKey == 'all') {
          _selectedKind = null;
        } else {
          _selectedKind = MediaKind.values.where((k) => k.name == selectedKindKey).firstOrNull;
        }
        _selectedSort = result['sort']?.firstOrNull ?? 'relevance';
      });
      _performSearch(_controller.text);
    }
  }

  void _playMediaItem(MediaItem item) async {
    _repository.addToRecentlyPlayed(item);

    if (item.isVideo || item.kind == MediaKind.movie || item.kind == MediaKind.show) {
      MediaItem playItem = item;
      if (item.kind == MediaKind.movie && item.id.startsWith('ia-')) {
        final rawId = item.id.substring(3);
        final resolved = await _repository.resolveMovieStreamUrl(rawId);
        if (resolved.isNotEmpty) {
          playItem = item.copyWith(streamUrl: resolved);
        }
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(item: playItem),
        ),
      );
    } else {
      final ep = MediaRepository.mediaItemToEpisode(item);
      context.read<PlayerBloc>().add(PlayEpisode(ep));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FullScreenPlayerPage()),
      );
    }
  }

  int get _activeFilterBadgeCount {
    int count = 0;
    if (_activeFilters['kind']?.firstOrNull != null && _activeFilters['kind']!.first != 'all') {
      count++;
    }
    if (_activeFilters['sort']?.firstOrNull != null && _activeFilters['sort']!.first != 'relevance') {
      count++;
    }
    return count;
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
          'Universal Search',
          style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary),
        ),
        actions: [
          FilterIconButton(
            activeCount: _activeFilterBadgeCount,
            onTap: _openFilterSheet,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Senior Google Search Pill with Clear & Prefix Search Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: false,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search movies, podcasts, music, radio...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _performSearch('');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Category Scope Tabs (All, Movies, Podcasts, Music, Radio, Shows, Audiobooks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _scopeTabs.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _scopeTabs[index];
                  final isSelected = _selectedKind == tab['kind'];

                  return GestureDetector(
                    onTap: () => _selectTab(tab['kind'] as MediaKind?),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
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
                        tab['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Recent Searches Chip Shelf (if present)
          if (_recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentSearches.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final queryText = _recentSearches[index];
                    return GestureDetector(
                      onTap: () {
                        _controller.text = queryText;
                        _performSearch(queryText);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_rounded, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 5),
                            Text(
                              queryText,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 4. Results Header & Count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchResults.isEmpty && !_isLoading
                      ? 'NO MATCHES FOUND'
                      : 'MATCHED CATALOG (${_searchResults.length})',
                  style: AppTypography.labelSm(
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                if (_selectedSort != 'relevance')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sorted: ${_selectedSort.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. Results List or Shimmer
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: ShimmerListSkeleton(count: 6),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'No results found for "${_controller.text}"',
                              style: AppTypography.bodyMd(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try searching for movies, artists, radio stations, or podcasts.',
                              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return _buildUniversalResultCard(context, item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversalResultCard(BuildContext context, MediaItem item) {
    Color badgeBg;
    Color badgeFg;
    IconData badgeIcon;

    switch (item.kind) {
      case MediaKind.movie:
      case MediaKind.video:
        badgeBg = const Color(0xFFFDE8E8);
        badgeFg = const Color(0xFFC81E1E);
        badgeIcon = Icons.movie_creation_outlined;
        break;
      case MediaKind.podcast:
        badgeBg = const Color(0xFFEAF4EE);
        badgeFg = AppColors.primary;
        badgeIcon = Icons.podcasts_rounded;
        break;
      case MediaKind.music:
        badgeBg = const Color(0xFFEBF5FB);
        badgeFg = const Color(0xFF1E88E5);
        badgeIcon = Icons.music_note_rounded;
        break;
      case MediaKind.radio:
        badgeBg = const Color(0xFFFFF3CD);
        badgeFg = const Color(0xFFB78103);
        badgeIcon = Icons.radio_rounded;
        break;
      case MediaKind.show:
        badgeBg = const Color(0xFFF3E8FD);
        badgeFg = const Color(0xFF8E24AA);
        badgeIcon = Icons.tv_rounded;
        break;
      case MediaKind.audiobook:
        badgeBg = const Color(0xFFE8F8F5);
        badgeFg = const Color(0xFF16A085);
        badgeIcon = Icons.auto_stories_rounded;
        break;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MediaDetailPage(item: item)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            // Artwork with Rounded 10dp corners
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item.artworkUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 70,
                  height: 70,
                  color: AppColors.primaryContainer,
                  child: Icon(badgeIcon, color: AppColors.primary, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Metadata column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Badge + Duration Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 10, color: badgeFg),
                            const SizedBox(width: 3),
                            Text(
                              item.kind.displayName.toUpperCase(),
                              style: TextStyle(
                                color: badgeFg,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.durationString,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Title
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Creator / Host
                  Text(
                    item.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Rating Row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.amber, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        item.formattedRating,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${item.reviewCount})',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Play icon action
            GestureDetector(
              onTap: () => _playMediaItem(item),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
