import '../../../../core/api/podcast_index_adapter.dart';
import '../../../../core/api/jamendo_adapter.dart';
import '../../../../core/api/radio_browser_adapter.dart';
import '../../../../core/api/tvmaze_adapter.dart';
import '../../../../core/api/librivox_adapter.dart';
import '../../../../core/api/iptv_adapter.dart';
import '../../../../core/api/weather_adapter.dart';
import '../../../../core/api/internet_archive_adapter.dart';
import '../../../../core/services/on_device_ai_engine.dart';
import '../../../player/domain/models/podcast.dart';
import '../../../player/domain/models/episode.dart';
import '../../domain/models/media_item.dart';
import '../../../../core/storage/persistent_storage.dart';

class MediaRepository {
  static final MediaRepository _instance = MediaRepository._internal();
  factory MediaRepository() => _instance;
  MediaRepository._internal();

  final PodcastIndexAdapter _podcastAdapter = PodcastIndexAdapter();
  final JamendoAdapter _jamendoAdapter = JamendoAdapter();
  final RadioBrowserAdapter _radioAdapter = RadioBrowserAdapter();
  final TVmazeAdapter _tvmazeAdapter = TVmazeAdapter();
  final LibriVoxAdapter _librivoxAdapter = LibriVoxAdapter();
  final IPTVAdapter _iptvAdapter = IPTVAdapter();
  final WeatherAdapter _weatherAdapter = WeatherAdapter();
  final InternetArchiveAdapter _archiveAdapter = InternetArchiveAdapter();

  List<Podcast> _cachedPodcasts = [];
  List<MediaItem> _cachedMusic = [];
  List<MediaItem> _cachedRadio = [];
  List<MediaItem> _cachedShows = [];
  List<MediaItem> _cachedAudiobooks = [];
  List<MediaItem> _cachedVideoStreams = [];
  List<MediaItem> _cachedMovies = [];

  // Live Weather (Open-Meteo)
  Future<WeatherInfo> getWeather() => _weatherAdapter.getCurrentWeather();

  // Podcasts
  Future<List<Podcast>> getTrendingPodcasts() async {
    final live = await _podcastAdapter.getTrendingPodcasts(max: 15);
    if (live.isNotEmpty) {
      _cachedPodcasts = live;
      return live;
    }
    return _cachedPodcasts;
  }

  // Music
  Future<List<MediaItem>> getPopularMusic({String? tag}) async {
    final live = await _jamendoAdapter.getPopularTracks(limit: 15, tag: tag);
    if (live.isNotEmpty) {
      _cachedMusic = live;
      return live;
    }
    return _cachedMusic;
  }

  // Radio
  Future<List<MediaItem>> getPopularRadio() async {
    final live = await _radioAdapter.getPopularStations(limit: 15);
    if (live.isNotEmpty) {
      _cachedRadio = live;
      return live;
    }
    return _cachedRadio;
  }

  // TV Shows (TVmaze)
  Future<List<MediaItem>> getPopularShows() async {
    final live = await _tvmazeAdapter.getPopularShows(limit: 15);
    if (live.isNotEmpty) {
      _cachedShows = live;
      return live;
    }
    return _cachedShows;
  }

  // Live TV & Video Streams (IPTV-org)
  Future<List<MediaItem>> getLiveVideoStreams({int limit = 25}) async {
    final live = await _iptvAdapter.getLiveStreams(limit: limit);
    if (live.isNotEmpty) {
      _cachedVideoStreams = live;
      return live;
    }
    return _cachedVideoStreams;
  }

  // Movies & Cinema (Internet Archive + IPTV fallback)
  Future<List<MediaItem>> getPopularMovies({
    String? categoryQuery,
    String sort = 'downloads desc',
    int limit = 25,
  }) async {
    final live = await _archiveAdapter.searchMovies(
      categoryQuery: categoryQuery,
      sort: sort,
      limit: limit,
    );
    if (live.isNotEmpty) {
      _cachedMovies = live;
      return live;
    }
    // Fallback to live cinema streams if archive query returns empty
    final iptvMovies = await _iptvAdapter.getMovieStreams(limit: limit);
    if (iptvMovies.isNotEmpty) {
      _cachedMovies = iptvMovies;
      return iptvMovies;
    }
    return _cachedMovies;
  }

  Future<List<MediaItem>> searchMovies(String query) async {
    final results = await _archiveAdapter.searchMovies(query: query);
    if (results.isNotEmpty) return results;
    // Fallback search across cached
    final q = query.toLowerCase();
    return _cachedMovies.where((m) => m.title.toLowerCase().contains(q) || m.creator.toLowerCase().contains(q)).toList();
  }

  Future<String> resolveMovieStreamUrl(String identifier) async {
    return _archiveAdapter.resolveVideoStreamUrl(identifier);
  }

  // Audiobooks
  Future<List<MediaItem>> getPopularAudiobooks() async {
    final live = await _librivoxAdapter.getAudiobooks(limit: 15);
    if (live.isNotEmpty) {
      _cachedAudiobooks = live;
      return live;
    }
    return _cachedAudiobooks;
  }

  // Cross-media search
  Future<List<MediaItem>> searchMedia(String query, {MediaKind? kind}) async {
    if (query.trim().isEmpty) {
      switch (kind) {
        case MediaKind.music:
          return getPopularMusic();
        case MediaKind.radio:
          return getPopularRadio();
        case MediaKind.show:
          return getPopularShows();
        case MediaKind.movie:
          return getPopularMovies();
        case MediaKind.audiobook:
          return getPopularAudiobooks();
        case MediaKind.podcast:
        default:
          final pods = await getTrendingPodcasts();
          return pods.map((p) => podcastToMediaItem(p)).toList();
      }
    }

    if (kind != null) {
      switch (kind) {
        case MediaKind.music:
          return _jamendoAdapter.searchTracks(query);
        case MediaKind.radio:
          return _radioAdapter.searchStations(query);
        case MediaKind.show:
          return _tvmazeAdapter.searchShows(query);
        case MediaKind.movie:
          return searchMovies(query);
        case MediaKind.audiobook:
          return _librivoxAdapter.searchAudiobooks(query);
        case MediaKind.podcast:
          final pods = await _podcastAdapter.searchPodcasts(query);
          return pods.map((p) => podcastToMediaItem(p)).toList();
        default:
          break;
      }
    }

    // Search across all
    final futures = await Future.wait([
      _podcastAdapter.searchPodcasts(query, max: 5),
      searchMovies(query),
      _jamendoAdapter.searchTracks(query, limit: 5),
      _radioAdapter.searchStations(query, limit: 5),
      _tvmazeAdapter.searchShows(query),
      _librivoxAdapter.searchAudiobooks(query, limit: 5),
    ]);

    final List<MediaItem> combined = [];
    final pods = futures[0] as List<Podcast>;
    combined.addAll(pods.map((p) => podcastToMediaItem(p)));
    combined.addAll(futures[1] as List<MediaItem>); // Movies
    combined.addAll(futures[2] as List<MediaItem>); // Music
    combined.addAll(futures[3] as List<MediaItem>); // Radio
    combined.addAll(futures[4] as List<MediaItem>); // Shows
    combined.addAll(futures[5] as List<MediaItem>); // Audiobooks
    return combined;
  }

  // Episodes for Podcast (Scored by On-Device Gemma 2B LiteRT)
  Future<List<Episode>> getEpisodesForPodcast(Podcast podcast) async {
    final feedIdInt = int.tryParse(podcast.id);
    if (feedIdInt != null) {
      final liveEpisodes = await _podcastAdapter.getEpisodesByFeedId(feedIdInt, max: 25);
      if (liveEpisodes.isNotEmpty) {
        return OnDeviceAiEngine.instance.scoreEpisodes(liveEpisodes);
      }
    }
    return [];
  }

  // Bookmarks (Persisted to bookmarks.json - max 20)
  bool isBookmarked(String id) => PersistentStorage.instance.isBookmarked(id);

  void toggleBookmarkItem(MediaItem item) {
    PersistentStorage.instance.toggleBookmark(item);
  }

  void toggleBookmark(String id) {
    // If we only have the ID, find it or remove it
    if (PersistentStorage.instance.isBookmarked(id)) {
      final existing = PersistentStorage.instance.getBookmarks().firstWhere((m) => m.id == id);
      PersistentStorage.instance.toggleBookmark(existing);
    }
  }

  List<MediaItem> getBookmarkedItems() => PersistentStorage.instance.getBookmarks();
  List<String> getBookmarkedIds() => PersistentStorage.instance.getBookmarks().map((m) => m.id).toList();

  // Recently Played (Persisted to recent_history.json - exactly 10 per buildathon doc 12)
  List<MediaItem> getRecentlyPlayed() => PersistentStorage.instance.getRecentHistory();

  void addToRecentlyPlayed(MediaItem item) {
    PersistentStorage.instance.addToRecentHistory(item);
  }

  // Followed Podcasts (Persisted to followed_podcasts.json)
  bool isFollowingPodcast(String podcastId) => PersistentStorage.instance.isFollowingPodcast(podcastId);
  void toggleFollowPodcast(Podcast podcast) => PersistentStorage.instance.toggleFollowPodcast(podcast);
  List<Podcast> getFollowedPodcasts() => PersistentStorage.instance.getFollowedPodcasts();

  // Utility convertor
  static MediaItem podcastToMediaItem(Podcast podcast) {
    return MediaItem(
      id: podcast.id,
      title: podcast.title,
      creator: podcast.hosts,
      kind: MediaKind.podcast,
      artworkUrl: podcast.artworkUrl,
      streamUrl: podcast.feedUrl,
      description: podcast.description,
      durationSeconds: 2700,
      rating: podcast.rating,
      reviewCount: podcast.reviewCount,
      category: podcast.categories.isNotEmpty ? podcast.categories.first : 'Technology',
      tags: podcast.categories,
      episodesCount: podcast.episodeCount > 1 ? podcast.episodeCount : 24,
      subtitle: podcast.subtitle,
      rawMetadata: {'feedId': podcast.id, 'isEpisode': false},
    );
  }

  static Episode mediaItemToEpisode(MediaItem item) {
    return Episode(
      id: item.id,
      title: item.title,
      showTitle: item.creator,
      host: item.creator,
      durationString: item.durationString,
      totalDuration: Duration(seconds: item.durationSeconds > 0 ? item.durationSeconds : 180),
      artworkUrl: item.artworkUrl,
      description: item.description,
      publishedDate: item.publishedDate ?? 'Live',
      audioUrl: item.streamUrl,
      feedId: int.tryParse(item.id),
      topicTags: item.tags,
    );
  }

  static MediaItem episodeToMediaItem(Episode ep) {
    return MediaItem(
      id: ep.id,
      title: ep.title,
      creator: ep.host.isNotEmpty ? ep.host : ep.showTitle,
      kind: MediaKind.podcast,
      artworkUrl: ep.artworkUrl,
      streamUrl: ep.audioUrl ?? '',
      description: ep.description,
      durationSeconds: ep.totalDuration.inSeconds,
      rating: 4.9,
      reviewCount: '1.2K',
      category: 'Podcast',
      episodesCount: 1,
      publishedDate: ep.publishedDate,
      rawMetadata: {
        'isEpisode': true,
        if (ep.feedId != null) 'episodeFeedId': ep.feedId.toString(),
      },
    );
  }
}
