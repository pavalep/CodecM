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

class AudiobooksPage extends StatefulWidget {
  const AudiobooksPage({super.key});

  @override
  State<AudiobooksPage> createState() => _AudiobooksPageState();
}

class _AudiobooksPageState extends State<AudiobooksPage> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  List<MediaItem> _books = [];
  bool _isLoading = true;
  String _selectedSubject = 'all';
  String _selectedSort = 'popular';

  final List<Map<String, String>> _subjects = [
    {'key': 'all', 'label': 'All Subjects'},
    {'key': 'fiction', 'label': 'Fiction & Literature'},
    {'key': 'history', 'label': 'Historical Works'},
    {'key': 'poetry', 'label': 'Poetry & Drama'},
    {'key': 'philosophy', 'label': 'Philosophy & Science'},
    {'key': 'adventure', 'label': 'Action & Adventure'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAudiobooks() async {
    setState(() => _isLoading = true);
    final subject = _selectedSubject == 'all' ? null : _selectedSubject;
    final items = subject != null
        ? await _repository.searchMedia(subject, kind: MediaKind.audiobook)
        : await _repository.getPopularAudiobooks();
    if (mounted) {
      setState(() {
        _books = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final filterGroups = [
      FilterGroup(
        id: 'subject',
        title: 'Subject Matter',
        multiSelect: false,
        options: _subjects.map((s) => FilterOption(key: s['key']!, label: s['label']!)).toList(),
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
        'subject': [_selectedSubject],
        'sort': [_selectedSort],
      },
    );

    if (result != null && mounted) {
      final newSubject = result['subject']?.firstOrNull ?? _selectedSubject;
      final newSort = result['sort']?.firstOrNull ?? _selectedSort;
      if (newSubject != _selectedSubject || newSort != _selectedSort) {
        setState(() {
          _selectedSubject = newSubject;
          _selectedSort = newSort;
        });
        _loadAudiobooks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var displayBooks = List<MediaItem>.from(_books);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      displayBooks = displayBooks.where((b) {
        return b.title.toLowerCase().contains(query) || b.creator.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedSort == 'rating') {
      displayBooks.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSort == 'az') {
      displayBooks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
        title: Text('Public Audiobooks', style: AppTypography.displayEditorial(fontSize: 22, color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          // Search & Filter Row (44dp, 12dp radius, 1px border)
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
                              hintText: 'Search audiobooks & authors...',
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
                  activeCount: _selectedSubject != 'all' || _selectedSort != 'popular' ? 1 : 0,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),

          // Audiobooks List (12dp radius, 10dp image, 1px border)
          Expanded(
            child: _isLoading
                ? const ShimmerListSkeleton(
                    count: 6,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                    shrinkWrap: false,
                    physics: BouncingScrollPhysics(),
                  )
                : displayBooks.isEmpty
                    ? Center(
                        child: Text(
                          'No audiobooks found matching your query.',
                          style: AppTypography.bodyMd(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: displayBooks.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = displayBooks[index];
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
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => Container(
                                        width: 60,
                                        height: 60,
                                        color: AppColors.primaryContainer,
                                        child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary),
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
