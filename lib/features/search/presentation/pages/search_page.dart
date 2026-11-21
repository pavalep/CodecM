import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/core/services/search_suggestion_service.dart';
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
  final FocusNode _focusNode = FocusNode();
  final MediaRepository _repository = MediaRepository();
  final SearchSuggestionService _suggestionService = SearchSuggestionService.instance;
  Timer? _debounce;

  List<MediaItem> _searchResults = [];
  bool _isLoading = false;
  MediaKind? _selectedKind;

  // SQLite + Gemma Suggestion & Recent History State
  List<SearchSuggestionItem> _recentSearches = [];
  List<SearchSuggestionItem> _suggestions = [];
  List<SearchSuggestionItem> _relatedQueries = [];
  bool _isTypingSuggestionsVisible = false;

  // Filter sheet state
  String _selectedSort = 'relevance';
  Map<String, List<String>> _activeFilters = {
    'kind': ['all'],
    'sort': ['relevance'],
  };

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

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _controller.text.trim().isNotEmpty) {
        setState(() => _isTypingSuggestionsVisible = true);
      }
    });

    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      _refreshSuggestions(initial);
      // Execute initial search without polluting recent search history unless committed by user
      _performSearch(initial, commitToHistory: false);
    } else {
      _refreshSuggestions('');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshSuggestions(String prefix) async {
    final bundle = await _suggestionService.getSuggestions(
      prefix: prefix,
      kind: _selectedKind,
      limit: 8,
    );
    if (!mounted) return;
    setState(() {
      _recentSearches = bundle.recent;
      _suggestions = bundle.suggestions;
      _relatedQueries = bundle.related;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isTypingSuggestionsVisible = query.trim().isNotEmpty;
    });
    // 1. Instant (<2ms) SQLite + Gemma autocomplete suggestions on every keystroke
    _refreshSuggestions(query);

    // 2. Debounced API search in background (NEVER writes partial typing prefixes to SQLite history)
    _debounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 380), () {
      _performSearch(clean, commitToHistory: false);
    });
  }

  /// Commits a search query: records it into SQLite `search_history`, hides the typing
  /// autocomplete overlay, unfocuses keyboard, and fetches the pure API results.
  Future<void> _commitSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    _debounce?.cancel();
    _focusNode.unfocus();
    if (_controller.text != clean) {
      _controller.text = clean;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: clean.length),
      );
    }

    setState(() {
      _isTypingSuggestionsVisible = false;
    });

    await _performSearch(clean, commitToHistory: true);
  }

  /// Populates the search bar with [term] (Google/YouTube `↖` arrow action) so the user
  /// can continue editing/refining the query before submitting.
  void _fillQueryIntoSearchBar(String term) {
    final filled = '$term ';
    _controller.text = filled;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: filled.length),
    );
    _focusNode.requestFocus();
    setState(() {
      _isTypingSuggestionsVisible = true;
    });
    _refreshSuggestions(term);
  }

  Future<void> _performSearch(String query, {required bool commitToHistory}) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      _refreshSuggestions('');
      return;
    }

    setState(() => _isLoading = true);

    if (commitToHistory) {
      final updatedRecent = await _suggestionService.recordQuery(
        clean,
        kind: _selectedKind,
      );
      if (mounted) {
        setState(() => _recentSearches = updatedRecent);
      }
      _refreshSuggestions(clean);
    }

    List<MediaItem> results;
    try {
      // Keep API results untouched (no artificial re-ranking of API response)
      results = await _repository.searchMedia(clean, kind: _selectedKind);
    } catch (_) {
      results = [];
    }

    // Apply explicit user sort only if requested (Rating or A-Z)
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
    _refreshSuggestions(_controller.text);
    if (_controller.text.trim().isNotEmpty) {
      _performSearch(_controller.text, commitToHistory: false);
    }
  }

  Future<void> _deleteRecentSearch(String term) async {
    final updated = await _suggestionService.deleteRecentQuery(term);
    if (mounted) {
      setState(() => _recentSearches = updated);
      _refreshSuggestions(_controller.text);
    }
  }

  Future<void> _clearAllRecentSearches() async {
    await _suggestionService.clearAllRecentQueries();
    if (mounted) {
      setState(() => _recentSearches = []);
      _refreshSuggestions(_controller.text);
    }
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
        _refreshSuggestions(_controller.text);
        _performSearch(_controller.text, commitToHistory: false);
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
      _refreshSuggestions(_controller.text);
      _performSearch(_controller.text, commitToHistory: false);
    }
  }

  void _openMediaDetail(MediaItem item) {
    final currentQuery = _controller.text.trim();
    if (currentQuery.length >= 2) {
      _suggestionService.recordQuery(currentQuery, kind: _selectedKind);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MediaDetailPage(item: item)),
    );
  }

  void _playMediaItem(MediaItem item) async {
    final currentQuery = _controller.text.trim();
    if (currentQuery.length >= 2) {
      _suggestionService.recordQuery(currentQuery, kind: _selectedKind);
    }
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
    final hasQuery = _controller.text.trim().isNotEmpty;

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
          // 1. Search Bar with Clear & Keyboard Submit
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusNode.hasFocus ? AppColors.primary : AppColors.border,
                  width: _focusNode.hasFocus ? 1.3 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _commitSearch,
                      onTap: () {
                        if (_controller.text.trim().isNotEmpty) {
                          setState(() => _isTypingSuggestionsVisible = true);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search movies, podcasts, music, radio...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (hasQuery)
                    GestureDetector(
                      onTap: () {
                        _debounce?.cancel();
                        _controller.clear();
                        setState(() {
                          _searchResults = [];
                          _isLoading = false;
                          _isTypingSuggestionsVisible = false;
                        });
                        _refreshSuggestions('');
                        _focusNode.requestFocus();
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

          // 3. Body: Zero-State (Empty Query) vs Active Typing Autocomplete vs Committed Results
          Expanded(
            child: !hasQuery
                ? _buildZeroStateView(context)
                : _isTypingSuggestionsVisible
                    ? _buildTypingAutocompleteView(context)
                    : _buildCommittedResultsView(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATE 1: ZERO-STATE VIEW (Recent Searches from SQLite + Personalized Suggestions)
  // ---------------------------------------------------------------------------
  Widget _buildZeroStateView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: AppTypography.headlineSm(fontSize: 16),
              ),
              GestureDetector(
                onTap: _clearAllRecentSearches,
                child: Text(
                  'Clear all',
                  style: AppTypography.labelLg(color: AppColors.primary, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(_recentSearches.length, (index) {
                final rec = _recentSearches[index];
                final isLast = index == _recentSearches.length - 1;
                return _buildSuggestionListTile(
                  item: rec,
                  queryPrefix: '',
                  showDelete: true,
                  showDivider: !isLast,
                );
              }),
            ),
          ),
          const SizedBox(height: 22),
        ],

        if (_suggestions.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suggested searches',
                style: AppTypography.headlineSm(fontSize: 16),
              ),
              Text(
                _selectedKind != null ? _selectedKind!.displayName : 'Based on your taste',
                style: AppTypography.bodySm(color: AppColors.textTertiary, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(_suggestions.length, (index) {
                final sug = _suggestions[index];
                final isLast = index == _suggestions.length - 1;
                return _buildSuggestionListTile(
                  item: sug,
                  queryPrefix: '',
                  showDelete: false,
                  showDivider: !isLast,
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STATE 2: ACTIVE TYPING AUTOCOMPLETE VIEW (SQLite Prefix + Gemma Semantic Expansion)
  // ---------------------------------------------------------------------------
  Widget _buildTypingAutocompleteView(BuildContext context) {
    final typedQuery = _controller.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Direct "Search for '<typed>'" action row at the top
        GestureDetector(
          onTap: () => _commitSearch(typedQuery),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.primary, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search for "$typedQuery"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                else if (_searchResults.isNotEmpty)
                  Text(
                    '${_searchResults.length} results →',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (_suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(_suggestions.length, (index) {
                final item = _suggestions[index];
                final isLast = index == _suggestions.length - 1;
                return _buildSuggestionListTile(
                  item: item,
                  queryPrefix: typedQuery,
                  showDelete: item.source == SearchSuggestionSource.history,
                  showDivider: !isLast,
                );
              }),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STATE 3: COMMITTED RESULTS VIEW (Recent Chips + Related Searches + Pure API Results)
  // ---------------------------------------------------------------------------
  Widget _buildCommittedResultsView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Searches Chip Shelf (from SQLite, with individual × delete)
        if (_recentSearches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recentSearches.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final rec = _recentSearches[index];
                  return GestureDetector(
                    onTap: () => _commitSearch(rec.term),
                    child: Container(
                      padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
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
                            rec.term,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _deleteRecentSearch(rec.term),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 12.5, color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Related Searches Shelf (from SQLite + Gemma Semantic Neighbors)
        if (_relatedQueries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _relatedQueries.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final rel = _relatedQueries[index];
                  return GestureDetector(
                    onTap: () => _commitSearch(rel.term),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_rounded, size: 12.5, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            rel.term,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Results Header & Count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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

        // Results List or Shimmer
        Expanded(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
                            'Tap a suggested query above or try another keyword.',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return _buildUniversalResultCard(context, item);
                      },
                    ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Google / YouTube-grade Suggestion Row with Prefix Bold Highlighting & `↖` Fill Button
  // ---------------------------------------------------------------------------
  Widget _buildSuggestionListTile({
    required SearchSuggestionItem item,
    required String queryPrefix,
    required bool showDelete,
    required bool showDivider,
  }) {
    IconData leadingIcon;
    Color leadingColor;
    switch (item.source) {
      case SearchSuggestionSource.history:
        leadingIcon = Icons.history_rounded;
        leadingColor = AppColors.textSecondary;
        break;
      case SearchSuggestionSource.prefix:
        leadingIcon = Icons.search_rounded;
        leadingColor = AppColors.primary;
        break;
      case SearchSuggestionSource.semantic:
      case SearchSuggestionSource.taste:
        leadingIcon = Icons.trending_up_rounded;
        leadingColor = AppColors.primary;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _commitSearch(item.term),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(leadingIcon, size: 18, color: leadingColor),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHighlightedTerm(item.term, queryPrefix),
                ),
                if (item.category != 'all' && item.source != SearchSuggestionSource.history) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.categoryDisplayLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
                if (showDelete) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _deleteRecentSearch(item.term),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                // Google Search / YouTube "Query Fill" arrow (`↖`)
                GestureDetector(
                  onTap: () => _fillQueryIntoSearchBar(item.term),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 44, endIndent: 14, color: AppColors.border),
      ],
    );
  }

  Widget _buildHighlightedTerm(String term, String queryPrefix) {
    final cleanPrefix = queryPrefix.trim();
    if (cleanPrefix.isEmpty) {
      return Text(
        term,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      );
    }

    final lowerTerm = term.toLowerCase();
    final lowerPrefix = cleanPrefix.toLowerCase();
    final matchIndex = lowerTerm.indexOf(lowerPrefix);

    if (matchIndex == -1) {
      return Text(
        term,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      );
    }

    final before = term.substring(0, matchIndex);
    final matched = term.substring(matchIndex, matchIndex + cleanPrefix.length);
    final after = term.substring(matchIndex + cleanPrefix.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
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
      onTap: () => _openMediaDetail(item),
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
