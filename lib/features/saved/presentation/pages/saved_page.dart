import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/core/widgets/filter_sheet.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/media/presentation/pages/media_detail_page.dart';
import 'package:codecm/features/player/presentation/pages/video_player_page.dart';

class SavedPage extends StatefulWidget {
  final int initialSegment;

  const SavedPage({
    super.key,
    this.initialSegment = 0,
  });

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final TextEditingController _searchController = TextEditingController();
  late int _activeSegment; // 0 = Saved / Favorites, 1 = History

  @override
  void initState() {
    super.initState();
    _activeSegment = widget.initialSegment;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'segment',
        title: 'Active Collection',
        multiSelect: false,
        options: const [
          FilterOption(key: '0', label: 'Saved Bookmarks', icon: Icons.favorite_rounded),
          FilterOption(key: '1', label: 'Playback History', icon: Icons.history_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'segment': [_activeSegment.toString()],
      },
    );

    if (result != null && mounted) {
      final segStr = result['segment']?.firstOrNull;
      if (segStr != null) {
        setState(() {
          _activeSegment = int.tryParse(segStr) ?? 0;
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
                      Text(
                        'Saved & Bookmarks',
                        style: AppTypography.displayEditorial(fontSize: 22),
                      ),
                    ],
                  ),
                  FilterIconButton(
                    onTap: _openFilterSheet,
                    activeCount: 0,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Your personal library of bookmarked releases and playback history.',
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
                          hintText: 'Search bookmarks & history...',
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

              // Segment Toggle: Saved vs History (10dp radius)
              ValueListenableBuilder<List<MediaItem>>(
                valueListenable: PersistentStorage.instance.bookmarksNotifier,
                builder: (context, bookmarks, _) {
                  return ValueListenableBuilder<List<MediaItem>>(
                    valueListenable: PersistentStorage.instance.recentHistoryNotifier,
                    builder: (context, history, _) {
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
                                onTap: () => setState(() => _activeSegment = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _activeSegment == 0 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Favorites (${bookmarks.length})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _activeSegment == 0 ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeSegment = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _activeSegment == 1 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'History (${history.length})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _activeSegment == 1 ? Colors.white : AppColors.textSecondary,
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

              // Active Content
              _activeSegment == 0 ? _buildBookmarksList() : _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarksList() {
    return ValueListenableBuilder<List<MediaItem>>(
      valueListenable: PersistentStorage.instance.bookmarksNotifier,
      builder: (context, bookmarkedItems, _) {
        final query = _searchController.text.trim().toLowerCase();
        final filteredItems = bookmarkedItems.where((item) {
          if (query.isEmpty) return true;
          return item.title.toLowerCase().contains(query) || item.creator.toLowerCase().contains(query);
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 44, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text('No saved items yet', style: AppTypography.bodyMd(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Tap the heart icon on any release to bookmark it here (max 20).',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredItems.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildItemTile(context, item, isBookmark: true);
          },
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return ValueListenableBuilder<List<MediaItem>>(
      valueListenable: PersistentStorage.instance.recentHistoryNotifier,
      builder: (context, recentHistory, _) {
        final query = _searchController.text.trim().toLowerCase();
        final filteredHistory = recentHistory.where((item) {
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
                  const Text('Tracks, movies, podcasts, and radio you play will appear here (max 10).',
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
                  'RECENT HISTORY (${filteredHistory.length}/10)',
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
                return _buildItemTile(context, item, isBookmark: false);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemTile(BuildContext context, MediaItem item, {required bool isBookmark}) {
    return GestureDetector(
      onTap: () {
        if (item.isVideo || item.kind == MediaKind.movie || item.kind == MediaKind.show) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VideoPlayerPage(item: item)),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MediaDetailPage(item: item)),
          );
        }
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
                item.artworkUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 60,
                  height: 60,
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
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.amber, size: 14),
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
            if (isBookmark)
              IconButton(
                icon: const Icon(Icons.favorite_rounded, color: AppColors.error),
                onPressed: () {
                  PersistentStorage.instance.toggleBookmark(item);
                },
              )
            else
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 19),
              ),
          ],
        ),
      ),
    );
  }
}
