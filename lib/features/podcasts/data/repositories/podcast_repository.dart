import '../../../../core/api/podcast_index_adapter.dart';
import '../../../../core/services/on_device_ai_engine.dart';
import '../../../player/domain/models/podcast.dart';
import '../../../player/domain/models/episode.dart';
import '../../../../core/storage/persistent_storage.dart';

/// Repository fetching live podcast catalogs and episode feeds from PodcastIndex API,
/// ranked and scored via OnDeviceAiEngine (Gemma 2B LiteRT).
class PodcastRepository {
  static final PodcastRepository _instance = PodcastRepository._internal();
  factory PodcastRepository() => _instance;
  PodcastRepository._internal();

  final PodcastIndexAdapter _adapter = PodcastIndexAdapter();
  final OnDeviceAiEngine _aiEngine = OnDeviceAiEngine.instance;

  List<Podcast> _cachedTrending = [];
  List<Episode> _cachedRecentEpisodes = [];

  /// Fetch Trending Shows from live PodcastIndex API
  Future<List<Podcast>> getTrendingPodcasts({String? categoryId}) async {
    final live = await _adapter.getTrendingPodcasts(max: 20, categoryId: categoryId);
    if (live.isNotEmpty) {
      _cachedTrending = live;
      return live;
    }
    return _cachedTrending;
  }

  /// Search Podcasts by Term on live PodcastIndex API
  Future<List<Podcast>> searchPodcasts(String query) async {
    if (query.trim().isEmpty) return getTrendingPodcasts();
    final live = await _adapter.searchPodcasts(query, max: 20);
    if (live.isNotEmpty) return live;

    final lower = query.toLowerCase();
    return _cachedTrending
        .where((p) =>
            p.title.toLowerCase().contains(lower) ||
            p.hosts.toLowerCase().contains(lower) ||
            p.categories.any((c) => c.toLowerCase().contains(lower)))
        .toList();
  }

  /// Fetch Episodes for a Podcast Show from live PodcastIndex API and score with Gemma 2B LiteRT
  Future<List<Episode>> getEpisodesForPodcast(Podcast podcast) async {
    final feedIdInt = int.tryParse(podcast.id);
    if (feedIdInt != null) {
      final liveEpisodes = await _adapter.getEpisodesByFeedId(feedIdInt, max: 25);
      if (liveEpisodes.isNotEmpty) {
        return _aiEngine.scoreEpisodes(liveEpisodes);
      }
    }
    return [];
  }

  /// Fetch Recent Episodes across network and score with Gemma 2B LiteRT
  Future<List<Episode>> getRecentEpisodes() async {
    final live = await _adapter.getRecentEpisodes(max: 15);
    if (live.isNotEmpty) {
      final scored = await _aiEngine.scoreEpisodes(live);
      _cachedRecentEpisodes = scored;
      return scored;
    }
    return _cachedRecentEpisodes;
  }

  /// Follow Status Management (Persisted via PersistentStorage)
  bool isFollowing(String podcastId) => PersistentStorage.instance.isFollowingPodcast(podcastId);

  void toggleFollow(String podcastId) {
    final found = _cachedTrending.where((p) => p.id == podcastId).firstOrNull;
    if (found != null) {
      PersistentStorage.instance.toggleFollowPodcast(found);
    } else {
      final existing = PersistentStorage.instance.getFollowedPodcasts();
      final match = existing.where((p) => p.id == podcastId).firstOrNull;
      if (match != null) {
        PersistentStorage.instance.toggleFollowPodcast(match);
      }
    }
  }

  void toggleFollowPodcast(Podcast podcast) {
    PersistentStorage.instance.toggleFollowPodcast(podcast);
  }

  List<Podcast> getFollowedPodcasts() {
    return PersistentStorage.instance.getFollowedPodcasts();
  }
}
