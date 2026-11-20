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

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  List<MediaItem> _tracks = [];
  bool _isLoading = true;
  String _selectedGenre = 'All';
  String _selectedSort = 'popular';

  final List<String> _genres = [
    'All',
    'Pop',
    'Rock',
    'Electronic',
    'Hip-Hop',
    'Jazz',
    'Classical',
    'Chillout',
    'Ambient',
  ];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() => _isLoading = true);
    final tag = _selectedGenre == 'All' ? null : _selectedGenre.toLowerCase();
    final items = await _repository.getPopularMusic(tag: tag);
    if (mounted) {
      setState(() {
        _tracks = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'genre',
        title: 'Music Genre',
        multiSelect: false,
        options: _genres.map((g) => FilterOption(key: g, label: g)).toList(),
      ),
      const FilterGroup(
        id: 'sort',
        title: 'Sort Order',
        multiSelect: false,
        options: [
          FilterOption(key: 'popular', label: 'Most popular', icon: Icons.trending_up_rounded),
          FilterOption(key: 'rating', label: 'Top rated', icon: Icons.star_rounded),
          FilterOption(key: 'az', label: 'Title (A–Z)', icon: Icons.sort_by_alpha_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'genre': [_selectedGenre],
        'sort': [_selectedSort],
      },
    );

    if (result != null && mounted) {
      final newGenre = result['genre']?.firstOrNull ?? _selectedGenre;
      final newSort = result['sort']?.firstOrNull ?? _selectedSort;
      if (newGenre != _selectedGenre || newSort != _selectedSort) {
        setState(() {
          _selectedGenre = newGenre;
          _selectedSort = newSort;
        });
        _loadTracks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var displayTracks = List<MediaItem>.from(_tracks);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      displayTracks = displayTracks.where((t) {
        return t.title.toLowerCase().contains(query) || t.creator.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedSort == 'rating') {
      displayTracks.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSort == 'az') {
      displayTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Music Catalogue', style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          // Search & Filter Row (44dp, 12dp radius, 1px border)
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
                            decoration: const InputDecoration(
                              hintText: 'Search songs, artists, albums...',
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
                ),
                const SizedBox(width: 8),
                FilterIconButton(
                  activeCount: _selectedGenre != 'All' || _selectedSort != 'popular' ? 1 : 0,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Genre Pills (10dp radius, 1px border)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _genres.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final genre = _genres[index];
                final isSelected = _selectedGenre == genre;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedGenre = genre);
                    _loadTracks();
                  },
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
                        genre,
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
          const SizedBox(height: 10),

          // Track List (12dp radius, 10dp image, 1px border)
          Expanded(
            child: _isLoading
                ? const ShimmerListSkeleton(
                    count: 6,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                    shrinkWrap: false,
                    physics: BouncingScrollPhysics(),
                  )
                : displayTracks.isEmpty
                    ? Center(
                        child: Text(
                          'No tracks found matching your filter.',
                          style: AppTypography.bodyMd(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                        itemCount: displayTracks.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = displayTracks[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (ctx) => MediaDetailPage(item: item)),
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
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.creator,
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
                                      final ep = MediaRepository.mediaItemToEpisode(item);
                                      context.read<PlayerBloc>().add(PlayEpisode(ep));
                                    },
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20),
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
