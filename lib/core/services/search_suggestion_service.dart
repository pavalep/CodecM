import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:codecm/core/services/on_device_ai_engine.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';

enum SearchSuggestionSource {
  history,
  prefix,
  semantic,
  taste,
}

class SearchSuggestionItem {
  final String term;
  final String category;
  final SearchSuggestionSource source;
  final int count;
  final double score;

  const SearchSuggestionItem({
    required this.term,
    this.category = 'all',
    this.source = SearchSuggestionSource.prefix,
    this.count = 1,
    this.score = 1.0,
  });

  factory SearchSuggestionItem.fromMap(Map<dynamic, dynamic> map) {
    final rawSource = map['source']?.toString() ?? 'prefix';
    SearchSuggestionSource src;
    switch (rawSource) {
      case 'history':
        src = SearchSuggestionSource.history;
        break;
      case 'semantic':
        src = SearchSuggestionSource.semantic;
        break;
      case 'taste':
        src = SearchSuggestionSource.taste;
        break;
      case 'prefix':
      default:
        src = SearchSuggestionSource.prefix;
        break;
    }
    return SearchSuggestionItem(
      term: map['term']?.toString() ?? '',
      category: map['category']?.toString() ?? 'all',
      source: src,
      count: (map['count'] as num?)?.toInt() ?? 1,
      score: (map['score'] as num?)?.toDouble() ?? 1.0,
    );
  }

  String get categoryDisplayLabel {
    switch (category.toLowerCase()) {
      case 'movie':
        return 'Movies';
      case 'podcast':
        return 'Podcasts';
      case 'music':
        return 'Music';
      case 'radio':
        return 'Radio';
      case 'show':
        return 'Shows';
      case 'audiobook':
        return 'Audiobooks';
      default:
        return 'All';
    }
  }
}

class SearchSuggestionBundle {
  final List<SearchSuggestionItem> recent;
  final List<SearchSuggestionItem> suggestions;
  final List<SearchSuggestionItem> related;

  const SearchSuggestionBundle({
    this.recent = const [],
    this.suggestions = const [],
    this.related = const [],
  });
}

/// Production Search Suggestion & Recent Search Service backed by:
/// 1. Native Android SQLite (`SearchDatabaseHelper.kt` -> `codecm_search_v1.db`)
///    with Frecency-ranked `search_history` and pre-computed 256-D Gemma vectors in `curated_suggestions`.
/// 2. Local JSON + Dart 256-D vector fallback for non-Android test environments.
class SearchSuggestionService {
  static final SearchSuggestionService instance = SearchSuggestionService._internal();
  factory SearchSuggestionService() => instance;
  SearchSuggestionService._internal();

  static const MethodChannel _channel = MethodChannel('com.app.codecm/gemma_litert');

  final ValueNotifier<List<SearchSuggestionItem>> recentSearchesNotifier =
      ValueNotifier<List<SearchSuggestionItem>>([]);

  // Fallback local history for non-Android / unit test environments
  final List<Map<String, dynamic>> _fallbackHistory = [];
  bool _fallbackLoaded = false;

  static const List<Map<String, dynamic>> _curatedPool = [
    // Movies
    {'term': 'Classic Cinema', 'category': 'movie', 'popularity': 98},
    {'term': 'Charlie Chaplin', 'category': 'movie', 'popularity': 96},
    {'term': 'Film Noir Mystery', 'category': 'movie', 'popularity': 95},
    {'term': 'Alfred Hitchcock', 'category': 'movie', 'popularity': 94},
    {'term': 'Sci-Fi Classics', 'category': 'movie', 'popularity': 94},
    {'term': 'Buster Keaton Comedy', 'category': 'movie', 'popularity': 91},
    {'term': 'Vintage Horror & Thriller', 'category': 'movie', 'popularity': 92},
    {'term': 'Golden Age Hollywood', 'category': 'movie', 'popularity': 90},
    {'term': 'Silent Era Masterpieces', 'category': 'movie', 'popularity': 88},
    {'term': 'Action & Adventure Films', 'category': 'movie', 'popularity': 89},
    {'term': 'Sherlock Holmes Mystery', 'category': 'movie', 'popularity': 93},
    {'term': 'Classic Animation & Cartoons', 'category': 'movie', 'popularity': 90},
    // Podcasts
    {'term': 'Technology & AI Podcasts', 'category': 'podcast', 'popularity': 98},
    {'term': 'True Crime Investigations', 'category': 'podcast', 'popularity': 96},
    {'term': 'Daily World News', 'category': 'podcast', 'popularity': 95},
    {'term': 'Startup Founders & Business', 'category': 'podcast', 'popularity': 93},
    {'term': 'History & Civilizations', 'category': 'podcast', 'popularity': 94},
    {'term': 'Science & Astronomy', 'category': 'podcast', 'popularity': 94},
    {'term': 'Philosophy & Stoicism', 'category': 'podcast', 'popularity': 91},
    {'term': 'Psychology & Mindset', 'category': 'podcast', 'popularity': 92},
    {'term': 'Book Club & Literature', 'category': 'podcast', 'popularity': 90},
    {'term': 'Comedy & Interviews', 'category': 'podcast', 'popularity': 91},
    // Music
    {'term': 'Lo-Fi Chill Beats', 'category': 'music', 'popularity': 98},
    {'term': 'Ambient Electronic', 'category': 'music', 'popularity': 96},
    {'term': 'Indie Folk & Acoustic', 'category': 'music', 'popularity': 94},
    {'term': 'Late Night Jazz', 'category': 'music', 'popularity': 95},
    {'term': 'Classical Piano & Strings', 'category': 'music', 'popularity': 93},
    {'term': 'Synthwave & Retro Electro', 'category': 'music', 'popularity': 92},
    {'term': 'Deep Focus Instrumental', 'category': 'music', 'popularity': 95},
    {'term': 'Cinematic Soundtracks', 'category': 'music', 'popularity': 91},
    // Radio
    {'term': 'Jazz FM Live Radio', 'category': 'radio', 'popularity': 96},
    {'term': 'Classical Symphony Radio', 'category': 'radio', 'popularity': 94},
    {'term': 'World News Broadcast', 'category': 'radio', 'popularity': 95},
    {'term': 'Chillout & Lounge Radio', 'category': 'radio', 'popularity': 93},
    {'term': '80s & 90s Retro Hits', 'category': 'radio', 'popularity': 91},
    {'term': 'BBC & European Radio', 'category': 'radio', 'popularity': 92},
    // TV Shows
    {'term': 'Sci-Fi & Fantasy Series', 'category': 'show', 'popularity': 95},
    {'term': 'Crime & Detective Drama', 'category': 'show', 'popularity': 94},
    {'term': 'Comedy Sitcoms', 'category': 'show', 'popularity': 92},
    {'term': 'Nature & Wildlife Shows', 'category': 'show', 'popularity': 91},
    {'term': 'Mystery & Suspense Shows', 'category': 'show', 'popularity': 93},
    // Audiobooks
    {'term': 'Classic Literature Audiobooks', 'category': 'audiobook', 'popularity': 96},
    {'term': 'Sherlock Holmes Stories', 'category': 'audiobook', 'popularity': 95},
    {'term': 'Science Fiction Novels', 'category': 'audiobook', 'popularity': 94},
    {'term': 'Philosophy & Meditations', 'category': 'audiobook', 'popularity': 92},
    {'term': 'Mystery & Detective Fiction', 'category': 'audiobook', 'popularity': 93},
  ];

  /// Fetch hybrid SQLite + Gemma search suggestions for the given [prefix] and optional [kind].
  Future<SearchSuggestionBundle> getSuggestions({
    String prefix = '',
    MediaKind? kind,
    int limit = 8,
  }) async {
    final kindStr = kind?.name ?? 'all';
    final tasteContext = OnDeviceAiEngine.instance.buildUserTasteContext();

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getSearchSuggestions',
        {
          'prefix': prefix,
          'kind': kindStr,
          'tasteContext': tasteContext,
          'limit': limit,
        },
      );

      if (res != null) {
        final rawRecent = (res['recent'] as List?) ?? const [];
        final rawSuggestions = (res['suggestions'] as List?) ?? const [];
        final rawRelated = (res['related'] as List?) ?? const [];

        final recent = rawRecent
            .whereType<Map>()
            .map((m) => SearchSuggestionItem.fromMap(m))
            .where((s) => s.term.isNotEmpty)
            .toList();

        final suggestions = rawSuggestions
            .whereType<Map>()
            .map((m) => SearchSuggestionItem.fromMap(m))
            .where((s) => s.term.isNotEmpty)
            .toList();

        final related = rawRelated
            .whereType<Map>()
            .map((m) => SearchSuggestionItem.fromMap(m))
            .where((s) => s.term.isNotEmpty)
            .toList();

        recentSearchesNotifier.value = recent;
        return SearchSuggestionBundle(
          recent: recent,
          suggestions: suggestions,
          related: related,
        );
      }
    } catch (_) {
      // Fallback for non-Android / unit test environment
    }

    return _computeFallbackSuggestions(
      prefix: prefix,
      kindStr: kindStr,
      tasteContext: tasteContext,
      limit: limit,
    );
  }

  /// Record a committed search query into SQLite `search_history`.
  /// Call ONLY on explicit submit, suggestion tap, or result tap — never on typing debounce.
  Future<List<SearchSuggestionItem>> recordQuery(
    String query, {
    MediaKind? kind,
  }) async {
    final clean = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < 2) return recentSearchesNotifier.value;

    final kindStr = kind?.name ?? 'all';

    try {
      final rawList = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'recordSearchQuery',
        {
          'query': clean,
          'kind': kindStr,
        },
      );
      if (rawList != null) {
        final list = rawList
            .map((m) => SearchSuggestionItem.fromMap(m))
            .where((s) => s.term.isNotEmpty)
            .toList();
        recentSearchesNotifier.value = list;
        return list;
      }
    } catch (_) {}

    await _ensureFallbackLoaded();
    final norm = _normalize(clean);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Prefix upgrade within 90s
    _fallbackHistory.removeWhere((entry) {
      final eNorm = _normalize(entry['term']?.toString() ?? '');
      final ts = (entry['timestamp'] as int?) ?? 0;
      return (now - ts) < 90000 &&
          eNorm != norm &&
          norm.startsWith(eNorm) &&
          norm.length > eNorm.length;
    });

    final existingIdx = _fallbackHistory.indexWhere(
      (e) => (e['term']?.toString() ?? '').toLowerCase() == clean.toLowerCase(),
    );
    int prevCount = 0;
    if (existingIdx != -1) {
      prevCount = (_fallbackHistory[existingIdx]['count'] as int?) ?? 1;
      _fallbackHistory.removeAt(existingIdx);
    }
    _fallbackHistory.insert(0, {
      'term': clean,
      'category': kindStr,
      'source': 'history',
      'count': prevCount + 1,
      'timestamp': now,
    });
    if (_fallbackHistory.length > 20) {
      _fallbackHistory.removeRange(20, _fallbackHistory.length);
    }
    await _saveFallbackHistory();
    final list = _getFallbackRecentItems();
    recentSearchesNotifier.value = list;
    return list;
  }

  /// Delete a single query from SQLite `search_history`.
  Future<List<SearchSuggestionItem>> deleteRecentQuery(String query) async {
    try {
      final rawList = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'deleteRecentSearch',
        {'query': query},
      );
      if (rawList != null) {
        final list = rawList
            .map((m) => SearchSuggestionItem.fromMap(m))
            .where((s) => s.term.isNotEmpty)
            .toList();
        recentSearchesNotifier.value = list;
        return list;
      }
    } catch (_) {}

    await _ensureFallbackLoaded();
    _fallbackHistory.removeWhere(
      (e) => (e['term']?.toString() ?? '').toLowerCase() == query.trim().toLowerCase(),
    );
    await _saveFallbackHistory();
    final list = _getFallbackRecentItems();
    recentSearchesNotifier.value = list;
    return list;
  }

  /// Clear all entries in SQLite `search_history`.
  Future<void> clearAllRecentQueries() async {
    try {
      await _channel.invokeMethod('clearRecentSearches');
      recentSearchesNotifier.value = const [];
      return;
    } catch (_) {}

    _fallbackHistory.clear();
    await _saveFallbackHistory();
    recentSearchesNotifier.value = const [];
  }

  // ---------------------------------------------------------------------------
  // Dart Fallback (Unit tests / Non-Android target)
  // ---------------------------------------------------------------------------
  Future<SearchSuggestionBundle> _computeFallbackSuggestions({
    required String prefix,
    required String kindStr,
    required String tasteContext,
    required int limit,
  }) async {
    await _ensureFallbackLoaded();
    final recent = _getFallbackRecentItems();
    final normPrefix = _normalize(prefix);
    final ai = OnDeviceAiEngine.instance;
    final tasteVec = ai.computeLocalEmbedding(tasteContext);

    final filteredPool = _curatedPool.where((row) {
      if (kindStr.isNotEmpty && kindStr != 'all') {
        return row['category'] == kindStr;
      }
      return true;
    }).toList();

    if (normPrefix.isEmpty) {
      final recentLower = recent.map((r) => r.term.toLowerCase()).toSet();
      final personalized = filteredPool
          .where((r) => !recentLower.contains((r['term'] as String).toLowerCase()))
          .map((row) {
            final term = row['term'] as String;
            final cat = row['category'] as String;
            final pop = (row['popularity'] as int) / 100.0;
            final vec = ai.computeLocalEmbedding('$term $cat');
            final sim = ai.computeLocalCosineSimilarity(tasteVec, vec);
            return SearchSuggestionItem(
              term: term,
              category: cat,
              source: SearchSuggestionSource.taste,
              score: 0.72 * sim + 0.28 * pop,
            );
          })
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return SearchSuggestionBundle(
        recent: recent,
        suggestions: personalized.take(limit).toList(),
        related: personalized.take(5).toList(),
      );
    }

    final queryVec = ai.computeLocalEmbedding('$prefix $kindStr');
    final merged = <SearchSuggestionItem>[];
    final seen = <String>{};

    // Tier 1: History matches
    for (final rec in recent) {
      final n = _normalize(rec.term);
      if (n.startsWith(normPrefix) || n.contains(' $normPrefix')) {
        if (seen.add(rec.term.toLowerCase())) {
          merged.add(rec);
        }
      }
      if (merged.length >= 3) break;
    }

    // Tier 2: Prefix matches
    final prefixMatches = filteredPool
        .where((row) {
          final n = _normalize(row['term'] as String);
          return n.startsWith(normPrefix) || n.contains(' $normPrefix');
        })
        .map((row) {
          final term = row['term'] as String;
          final cat = row['category'] as String;
          final vec = ai.computeLocalEmbedding('$term $cat');
          final sim = ai.computeLocalCosineSimilarity(queryVec, vec);
          return SearchSuggestionItem(
            term: term,
            category: cat,
            source: SearchSuggestionSource.prefix,
            score: 0.95 + 0.05 * sim,
          );
        })
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    for (final m in prefixMatches) {
      if (seen.add(m.term.toLowerCase())) {
        merged.add(m);
        if (merged.length >= limit) break;
      }
    }

    // Tier 3: Gemma semantic expansion
    final semanticList = filteredPool
        .where((row) => (row['term'] as String).toLowerCase() != prefix.trim().toLowerCase())
        .map((row) {
          final term = row['term'] as String;
          final cat = row['category'] as String;
          final vec = ai.computeLocalEmbedding('$term $cat');
          final sim = ai.computeLocalCosineSimilarity(queryVec, vec);
          final tasteSim = ai.computeLocalCosineSimilarity(tasteVec, vec);
          return SearchSuggestionItem(
            term: term,
            category: cat,
            source: SearchSuggestionSource.semantic,
            score: 0.80 * sim + 0.20 * tasteSim,
          );
        })
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    for (final s in semanticList) {
      if (merged.length >= limit) break;
      if (seen.add(s.term.toLowerCase())) {
        merged.add(s);
      }
    }

    return SearchSuggestionBundle(
      recent: recent,
      suggestions: merged.take(limit).toList(),
      related: semanticList.take(6).toList(),
    );
  }

  List<SearchSuggestionItem> _getFallbackRecentItems() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = _fallbackHistory.map((e) {
      final count = (e['count'] as int?) ?? 1;
      final ts = (e['timestamp'] as int?) ?? now;
      final ageHours = math.max(0, now - ts) / 3600000.0;
      final decay = math.exp(-0.08 * ageHours);
      final frecency = (count * 0.35 + 0.65) * decay;
      return SearchSuggestionItem(
        term: e['term']?.toString() ?? '',
        category: e['category']?.toString() ?? 'all',
        source: SearchSuggestionSource.history,
        count: count,
        score: frecency,
      );
    }).where((s) => s.term.isNotEmpty).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return items.take(10).toList();
  }

  Future<void> _ensureFallbackLoaded() async {
    if (_fallbackLoaded) return;
    _fallbackLoaded = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recent_searches_v1.json');
      if (await file.exists()) {
        final raw = json.decode(await file.readAsString());
        if (raw is List) {
          _fallbackHistory
            ..clear()
            ..addAll(raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveFallbackHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recent_searches_v1.json');
      await file.writeAsString(json.encode(_fallbackHistory));
    } catch (_) {}
  }

  String _normalize(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
