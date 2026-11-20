import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';

/// Persistent storage manager conforming to buildathon MMKV / Zustand specifications
class PersistentStorage {
  static final PersistentStorage instance = PersistentStorage._internal();
  PersistentStorage._internal();

  bool _isInitialized = false;
  String? _documentsPath;

  // In-memory caches for instantaneous UI reads
  List<MediaItem> _bookmarks = [];
  List<MediaItem> _recentHistory = [];
  List<Podcast> _followedPodcasts = [];
  List<MediaItem> _liveFavorites = [];

  static const int maxBookmarks = 20;
  static const int maxRecentHistory = 10; // Exactly 10 per buildathon doc 12 §8.4

  // ValueNotifier listeners so UI can reactively update when state changes
  final ValueNotifier<List<MediaItem>> bookmarksNotifier = ValueNotifier([]);
  final ValueNotifier<List<MediaItem>> recentHistoryNotifier = ValueNotifier([]);
  final ValueNotifier<List<Podcast>> followedPodcastsNotifier = ValueNotifier([]);
  final ValueNotifier<List<MediaItem>> liveFavoritesNotifier = ValueNotifier([]);

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _documentsPath = dir.path;
      await _loadAll();
      _isInitialized = true;
    } catch (e) {
      debugPrint('PersistentStorage initialization error: $e');
    }
  }

  Future<File> _getFile(String filename) async {
    final path = _documentsPath ?? (await getApplicationDocumentsDirectory()).path;
    _documentsPath = path;
    return File('$path/$filename');
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadBookmarks(),
      _loadRecentHistory(),
      _loadFollowedPodcasts(),
      _loadLiveFavorites(),
    ]);
  }

  // ----------------------------------------------------
  // 1. BOOKMARKS STORE (useBookmarksStore - max 20)
  // ----------------------------------------------------
  Future<void> _loadBookmarks() async {
    try {
      final file = await _getFile('bookmarks.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (json.decode(content) as List)
            .map((item) => _mediaItemFromJson(item as Map<String, dynamic>))
            .take(maxBookmarks)
            .toList();
        _bookmarks = list;
        bookmarksNotifier.value = List.unmodifiable(_bookmarks);
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  Future<void> _saveBookmarks() async {
    try {
      final file = await _getFile('bookmarks.json');
      final raw = _bookmarks.map((m) => _mediaItemToJson(m)).toList();
      await file.writeAsString(json.encode(raw));
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }

  List<MediaItem> getBookmarks() => List.unmodifiable(_bookmarks);

  bool isBookmarked(String id) => _bookmarks.any((m) => m.id == id);

  Future<void> toggleBookmark(MediaItem item) async {
    final exists = _bookmarks.indexWhere((m) => m.id == item.id);
    if (exists != -1) {
      _bookmarks.removeAt(exists);
    } else {
      _bookmarks.insert(0, item);
      if (_bookmarks.length > maxBookmarks) {
        _bookmarks = _bookmarks.sublist(0, maxBookmarks);
      }
    }
    bookmarksNotifier.value = List.unmodifiable(_bookmarks);
    await _saveBookmarks();
  }

  Future<void> removeBookmark(String id) async {
    _bookmarks.removeWhere((m) => m.id == id);
    bookmarksNotifier.value = List.unmodifiable(_bookmarks);
    await _saveBookmarks();
  }

  Future<void> clearBookmarks() async {
    _bookmarks.clear();
    bookmarksNotifier.value = [];
    await _saveBookmarks();
  }

  // ----------------------------------------------------
  // 2. RECENT HISTORY STORE (useRecentHistoryStore - max 10)
  // ----------------------------------------------------
  Future<void> _loadRecentHistory() async {
    try {
      final file = await _getFile('recent_history.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (json.decode(content) as List)
            .map((item) => _mediaItemFromJson(item as Map<String, dynamic>))
            .take(maxRecentHistory)
            .toList();
        _recentHistory = list;
        recentHistoryNotifier.value = List.unmodifiable(_recentHistory);
      }
    } catch (e) {
      debugPrint('Error loading recent history: $e');
    }
  }

  Future<void> _saveRecentHistory() async {
    try {
      final file = await _getFile('recent_history.json');
      final raw = _recentHistory.map((m) => _mediaItemToJson(m)).toList();
      await file.writeAsString(json.encode(raw));
    } catch (e) {
      debugPrint('Error saving recent history: $e');
    }
  }

  List<MediaItem> getRecentHistory() => List.unmodifiable(_recentHistory);

  Future<void> addToRecentHistory(MediaItem item) => upsertRecentHistory(item);

  Future<void> upsertRecentHistory(MediaItem item) async {
    // Deduplicate: moving entry to the head with fresh timestamp (keep genuine rewatches)
    _recentHistory.removeWhere((m) => m.id == item.id);
    _recentHistory.insert(0, item);
    if (_recentHistory.length > maxRecentHistory) {
      _recentHistory = _recentHistory.sublist(0, maxRecentHistory);
    }
    recentHistoryNotifier.value = List.unmodifiable(_recentHistory);
    await _saveRecentHistory();
  }

  Future<void> removeRecentHistory(String id) async {
    _recentHistory.removeWhere((m) => m.id == id);
    recentHistoryNotifier.value = List.unmodifiable(_recentHistory);
    await _saveRecentHistory();
  }

  Future<void> clearRecentHistory() async {
    _recentHistory.clear();
    recentHistoryNotifier.value = [];
    await _saveRecentHistory();
  }

  // ----------------------------------------------------
  // 3. FOLLOWED PODCASTS STORE (useFollowedPodcastsStore)
  // ----------------------------------------------------
  Future<void> _loadFollowedPodcasts() async {
    try {
      final file = await _getFile('followed_podcasts.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (json.decode(content) as List)
            .map((item) => _podcastFromJson(item as Map<String, dynamic>))
            .toList();
        _followedPodcasts = list;
        followedPodcastsNotifier.value = List.unmodifiable(_followedPodcasts);
      }
    } catch (e) {
      debugPrint('Error loading followed podcasts: $e');
    }
  }

  Future<void> _saveFollowedPodcasts() async {
    try {
      final file = await _getFile('followed_podcasts.json');
      final raw = _followedPodcasts.map((p) => _podcastToJson(p)).toList();
      await file.writeAsString(json.encode(raw));
    } catch (e) {
      debugPrint('Error saving followed podcasts: $e');
    }
  }

  List<Podcast> getFollowedPodcasts() => List.unmodifiable(_followedPodcasts);

  bool isFollowingPodcast(String podcastId) => _followedPodcasts.any((p) => p.id == podcastId);

  Future<void> toggleFollowPodcast(Podcast podcast) async {
    final idx = _followedPodcasts.indexWhere((p) => p.id == podcast.id);
    if (idx != -1) {
      _followedPodcasts.removeAt(idx);
    } else {
      _followedPodcasts.insert(0, podcast);
    }
    followedPodcastsNotifier.value = List.unmodifiable(_followedPodcasts);
    await _saveFollowedPodcasts();
  }

  Future<void> unfollowPodcast(String podcastId) async {
    _followedPodcasts.removeWhere((p) => p.id == podcastId);
    followedPodcastsNotifier.value = List.unmodifiable(_followedPodcasts);
    await _saveFollowedPodcasts();
  }

  // ----------------------------------------------------
  // 4. LIVE FAVORITES STORE (useLiveFavoritesStore)
  // ----------------------------------------------------
  Future<void> _loadLiveFavorites() async {
    try {
      final file = await _getFile('live_favorites.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (json.decode(content) as List)
            .map((item) => _mediaItemFromJson(item as Map<String, dynamic>))
            .toList();
        _liveFavorites = list;
        liveFavoritesNotifier.value = List.unmodifiable(_liveFavorites);
      }
    } catch (e) {
      debugPrint('Error loading live favorites: $e');
    }
  }

  Future<void> _saveLiveFavorites() async {
    try {
      final file = await _getFile('live_favorites.json');
      final raw = _liveFavorites.map((m) => _mediaItemToJson(m)).toList();
      await file.writeAsString(json.encode(raw));
    } catch (e) {
      debugPrint('Error saving live favorites: $e');
    }
  }

  List<MediaItem> getLiveFavorites() => List.unmodifiable(_liveFavorites);

  bool isLiveFavorite(String id) => _liveFavorites.any((m) => m.id == id);

  Future<void> toggleLiveFavorite(MediaItem item) async {
    final idx = _liveFavorites.indexWhere((m) => m.id == item.id);
    if (idx != -1) {
      _liveFavorites.removeAt(idx);
    } else {
      _liveFavorites.insert(0, item);
    }
    liveFavoritesNotifier.value = List.unmodifiable(_liveFavorites);
    await _saveLiveFavorites();
  }

  // ----------------------------------------------------
  // JSON Serialization Helpers
  // ----------------------------------------------------
  Map<String, dynamic> _mediaItemToJson(MediaItem item) => {
        'id': item.id,
        'title': item.title,
        'creator': item.creator,
        'kind': item.kind.name,
        'artworkUrl': item.artworkUrl,
        'streamUrl': item.streamUrl,
        'description': item.description,
        'durationSeconds': item.durationSeconds,
        'rating': item.rating,
        'reviewCount': item.reviewCount,
        'category': item.category,
        'publishedDate': item.publishedDate,
        'subtitle': item.subtitle,
      };

  MediaItem _mediaItemFromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        creator: json['creator'] as String? ?? 'Unknown Artist',
        kind: MediaKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => MediaKind.podcast,
        ),
        artworkUrl: json['artworkUrl'] as String? ?? '',
        streamUrl: json['streamUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
        reviewCount: json['reviewCount'] as String? ?? '1K',
        category: json['category'] as String? ?? 'General',
        publishedDate: json['publishedDate'] as String?,
        subtitle: json['subtitle'] as String?,
      );

  Map<String, dynamic> _podcastToJson(Podcast p) => {
        'id': p.id,
        'title': p.title,
        'subtitle': p.subtitle,
        'hosts': p.hosts,
        'artworkUrl': p.artworkUrl,
        'description': p.description,
        'feedUrl': p.feedUrl,
        'episodeCount': p.episodeCount,
        'rating': p.rating,
        'reviewCount': p.reviewCount,
        'rankGlobal': p.rankGlobal,
        'categories': p.categories,
      };

  Podcast _podcastFromJson(Map<String, dynamic> json) => Podcast(
        id: (json['id'] ?? '').toString(),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        hosts: json['hosts'] as String? ?? 'Host',
        artworkUrl: json['artworkUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        feedUrl: json['feedUrl'] as String? ?? '',
        episodeCount: json['episodeCount'] as int? ?? 12,
        rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
        reviewCount: json['reviewCount'] as String? ?? '1K',
        rankGlobal: json['rankGlobal'] as String? ?? 'Top 1% Global',
        categories: (json['categories'] as List?)?.map((c) => c.toString()).toList() ?? const ['General'],
      );
}
