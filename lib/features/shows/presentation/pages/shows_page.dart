import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';

class ShowsPage extends StatefulWidget {
  const ShowsPage({super.key});

  @override
  State<ShowsPage> createState() => _ShowsPageState();
}

class _ShowsPageState extends State<ShowsPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0 = Live TV Channels, 1 = TV Series
  List<MediaItem> _liveStreams = [];
  List<MediaItem> _tvShows = [];
  bool _isLoading = true;
  String _selectedGenre = 'all';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _repository.getLiveVideoStreams(limit: 25),
      _repository.getPopularShows(),
    ]);

    if (mounted) {
      setState(() {
        _liveStreams = results[0];
        _tvShows = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'category',
        title: _selectedTab == 0 ? 'Channel Category' : 'Genre',
        multiSelect: false,
        options: const [
          FilterOption(key: 'all', label: 'All Content', icon: Icons.auto_awesome_rounded),
          FilterOption(key: 'drama', label: 'Drama', icon: Icons.theater_comedy_rounded),
          FilterOption(key: 'comedy', label: 'Comedy', icon: Icons.sentiment_very_satisfied_rounded),
          FilterOption(key: 'news', label: 'News & Current Affairs', icon: Icons.newspaper_rounded),
          FilterOption(key: 'sports', label: 'Sports & Live Action', icon: Icons.sports_rounded),
          FilterOption(key: 'sci-fi', label: 'Sci-Fi & Action', icon: Icons.rocket_launch_rounded),
          FilterOption(key: 'music', label: 'Music & Entertainment', icon: Icons.music_note_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'category': [_selectedGenre],
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedGenre = result['category']?.firstOrNull ?? 'all';
      });
    }
  }

  void _openVideoPlayer(MediaItem item, [List<MediaItem>? list, int? index]) {
    _repository.addToRecentlyPlayed(item);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          item: item,
          playlist: list,
          initialIndex: index ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseList = _selectedTab == 0 ? _liveStreams : _tvShows;
    final query = _searchController.text.trim().toLowerCase();
    final currentList = baseList.where((item) {
      final matchesQuery = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.creator.toLowerCase().contains(query);
      final matchesGenre = _selectedGenre == 'all' ||
          item.category.toLowerCase().contains(_selectedGenre) ||
          item.tags.any((t) => t.toLowerCase().contains(_selectedGenre));
      return matchesQuery && matchesGenre;
    }).toList();

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
          'Live TV & Shows',
          style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Sub-Tab Switcher: Live TV Channels vs TV Series
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.live_tv_rounded,
                                size: 16,
                                color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Live Channels',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tv_rounded,
                                size: 16,
                                color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TV Series',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
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
                        const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: _selectedTab == 0 ? 'Search live channels...' : 'Search TV shows & series...',
                              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterIconButton(
                  activeCount: _selectedGenre != 'all' ? 1 : 0,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const ShimmerGridSkeleton(
                    count: 6,
                    childAspectRatio: 0.68,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 100),
                  )
                : currentList.isEmpty
                    ? Center(
                        child: Text(
                          _selectedTab == 0 ? 'Connecting to live video streams...' : 'No series catalog available.',
                          style: AppTypography.bodyMd(color: AppColors.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final item = currentList[index];
                          final isLive = _selectedTab == 0;

                          return GestureDetector(
                            onTap: () {
                              if (isLive) {
                                _openVideoPlayer(item, currentList, index);
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (ctx) => MediaDetailPage(item: item)),
                                );
                              }
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
                                              color: AppColors.primaryContainer,
                                              child: const Icon(Icons.tv_rounded, color: AppColors.primary, size: 36),
                                            ),
                                          ),
                                          if (isLive)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.circle, color: Colors.white, size: 7),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'LIVE',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Center(
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                                              isLive ? 'Broadcast' : item.category,
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
