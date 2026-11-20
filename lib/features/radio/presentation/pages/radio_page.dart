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

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  List<MediaItem> _stations = [];
  bool _isLoading = true;
  String _selectedTag = 'All';
  String _selectedSort = 'popular';

  final List<String> _tags = [
    'All',
    'News',
    'Jazz',
    'Classical',
    'Pop',
    'Rock',
    'Dance',
    'Ambient',
    'Talk',
  ];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    final tag = _selectedTag == 'All' ? null : _selectedTag.toLowerCase();
    final items = tag != null
        ? await _repository.searchMedia(tag, kind: MediaKind.radio)
        : await _repository.getPopularRadio();
    if (mounted) {
      setState(() {
        _stations = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'tag',
        title: 'Broadcast Tag',
        multiSelect: false,
        options: _tags.map((t) => FilterOption(key: t, label: t)).toList(),
      ),
      const FilterGroup(
        id: 'sort',
        title: 'Sort Order',
        multiSelect: false,
        options: [
          FilterOption(key: 'popular', label: 'Most popular', icon: Icons.trending_up_rounded),
          FilterOption(key: 'rating', label: 'Top rated', icon: Icons.star_rounded),
          FilterOption(key: 'az', label: 'Station Name (A–Z)', icon: Icons.sort_by_alpha_rounded),
        ],
      ),
    ];

    final result = await FilterSheet.show(
      context: context,
      groups: filterGroups,
      currentValues: {
        'tag': [_selectedTag],
        'sort': [_selectedSort],
      },
    );

    if (result != null && mounted) {
      final newTag = result['tag']?.firstOrNull ?? _selectedTag;
      final newSort = result['sort']?.firstOrNull ?? _selectedSort;
      if (newTag != _selectedTag || newSort != _selectedSort) {
        setState(() {
          _selectedTag = newTag;
          _selectedSort = newSort;
        });
        _loadStations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var displayStations = List<MediaItem>.from(_stations);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      displayStations = displayStations.where((s) {
        return s.title.toLowerCase().contains(query) || s.creator.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedSort == 'rating') {
      displayStations.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSort == 'az') {
      displayStations.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
        title: Text('Live Radio Stations', style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary)),
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
                              hintText: 'Search radio stations & streams...',
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
                  activeCount: _selectedTag != 'All' || _selectedSort != 'popular' ? 1 : 0,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Tag Pills (10dp radius, 1px border)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tags.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final isSelected = _selectedTag == tag;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTag = tag);
                    _loadStations();
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
                        tag,
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

          // Station List (12dp radius, 10dp image, 1px border)
          Expanded(
            child: _isLoading
                ? const ShimmerListSkeleton(
                    count: 6,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                    shrinkWrap: false,
                    physics: BouncingScrollPhysics(),
                  )
                : displayStations.isEmpty
                    ? Center(
                        child: Text(
                          'No live radio stations found for this tag.',
                          style: AppTypography.bodyMd(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                        itemCount: displayStations.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = displayStations[index];

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
                                        child: const Icon(Icons.radio_rounded, color: AppColors.primary),
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
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFDE8E8),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.fiber_manual_record_rounded, size: 8, color: Color(0xFFEF4444)),
                                                  SizedBox(width: 3),
                                                  Text('LIVE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                                                ],
                                              ),
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
