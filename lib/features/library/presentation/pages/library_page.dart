import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';
import 'package:codecm/core/widgets/shimmer_loading.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  int _selectedSegment = 0; // 0 = Subscribed, 1 = Recent History
  List<Podcast> _recommendedPodcasts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeedData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSeedData() async {
    final pods = await _repository.getTrendingPodcasts();
    if (mounted) {
      setState(() {
        _recommendedPodcasts = pods;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'view',
        title: 'Library View',
        multiSelect: false,
        options: const [
          FilterOption(key: '0', label: 'Subscribed Podcasts', icon: Icons.podcasts_rounded),
          FilterOption(key: '1', label: 'Recent History (Last 10)', icon: Icons.history_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'view': [_selectedSegment.toString()],
      },
    );

    if (result != null && mounted) {
      final viewStr = result['view']?.firstOrNull;
      if (viewStr != null) {
        setState(() {
          _selectedSegment = int.tryParse(viewStr) ?? 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with optional Back button + Filter button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (canPop)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      Text('Your Library', style: AppTypography.displayEditorial(fontSize: 22)),
                    ],
                  ),
                  FilterIconButton(
                    activeCount: 0,
                    onTap: _openFilterSheet,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Persistent subscribed podcasts, feeds, and playback history.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),

              const SizedBox(height: 14),

              // Search Bar (Unified 44dp height, 12dp radius, 1px border)
              Container(
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
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Filter your library & history...',
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
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Segmented Switcher (Subscribed vs Recent History) (10dp radius)
              ValueListenableBuilder<List<Podcast>>(
                valueListenable: PersistentStorage.instance.followedPodcastsNotifier,
                builder: (context, followedList, _) {
                  return ValueListenableBuilder<List<MediaItem>>(
                    valueListenable: PersistentStorage.instance.recentHistoryNotifier,
                    builder: (context, historyList, _) {
                      return Container(
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
                                onTap: () => setState(() => _selectedSegment = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedSegment == 0 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Subscribed (${followedList.length})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedSegment == 0 ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSegment = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedSegment == 1 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'History (${historyList.length})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedSegment == 1 ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              // Dynamic Segment Content
              _selectedSegment == 0 ? _buildSubscribedView() : _buildHistoryView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribedView() {
    return ValueListenableBuilder<List<Podcast>>(
      valueListenable: PersistentStorage.instance.followedPodcastsNotifier,
      builder: (context, followedList, _) {
        final query = _searchController.text.trim().toLowerCase();
        final filteredList = followedList.where((p) {
          if (query.isEmpty) return true;
          return p.title.toLowerCase().contains(query) || p.hosts.toLowerCase().contains(query);
        }).toList();

        if (filteredList.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR SUBSCRIPTIONS (${filteredList.length})',
                style: AppTypography.labelSm(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final podcast = filteredList[index];
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              podcast.artworkUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 52,
                                height: 52,
                                color: AppColors.primaryContainer,
                                child: const Icon(Icons.podcasts_rounded, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  podcast.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  podcast.hosts,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: AppColors.amber, size: 13),
                                    const SizedBox(width: 3),
                                    Text(
                                      podcast.formattedRating,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${podcast.episodeCount} episodes',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                            onPressed: () {
                              PersistentStorage.instance.unfollowPodcast(podcast.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
            ],
          );
        }

        // When subscriptions are empty: show clean promo banner and recommended shows
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'No followed podcasts yet',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Subscribe to podcasts below to have their feeds auto-cached for uninterrupted offline playback.',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Recommended Podcasts to Follow', style: AppTypography.headlineSm(fontSize: 17)),
            const SizedBox(height: 10),
            _isLoading
                ? const ShimmerListSkeleton(count: 4)
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recommendedPodcasts.take(6).length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final podcast = _recommendedPodcasts[index];
                      final isFollowing = PersistentStorage.instance.isFollowingPodcast(podcast.id);

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                podcast.artworkUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  width: 50,
                                  height: 50,
                                  color: AppColors.primaryContainer,
                                  child: const Icon(Icons.podcasts_rounded, color: AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    podcast.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    podcast.hosts,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? AppColors.surface : AppColors.primary,
                                foregroundColor: isFollowing ? AppColors.primary : Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: AppColors.primary, width: 1),
                                ),
                              ),
                              onPressed: () {
                                PersistentStorage.instance.toggleFollowPodcast(podcast);
                              },
                              child: Text(
                                isFollowing ? 'Following' : '+ Follow',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryView() {
    return ValueListenableBuilder<List<MediaItem>>(
      valueListenable: PersistentStorage.instance.recentHistoryNotifier,
      builder: (context, historyList, _) {
        final query = _searchController.text.trim().toLowerCase();
        final filteredHistory = historyList.where((item) {
          if (query.isEmpty) return true;
          return item.title.toLowerCase().contains(query) || item.creator.toLowerCase().contains(query);
        }).toList();

        if (filteredHistory.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.history_rounded, size: 44, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No playback history yet', style: AppTypography.bodyMd(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Any music, movie, radio, or podcast you play will appear here.',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT PLAYBACK (MAX 10 PER SPEC)',
                  style: AppTypography.labelSm(color: AppColors.textTertiary),
                ),
                GestureDetector(
                  onTap: () {
                    PersistentStorage.instance.clearRecentHistory();
                  },
                  child: const Text(
                    'Clear History',
                    style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredHistory.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filteredHistory[index];

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
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 52,
                              height: 52,
                              color: AppColors.primaryContainer,
                              child: Icon(
                                item.isVideo ? Icons.movie_outlined : Icons.music_note_rounded,
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
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.creator,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
