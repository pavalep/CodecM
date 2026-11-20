import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/html_utils.dart';
import '../../features/media/domain/models/media_item.dart';

class InternetArchiveAdapter {
  static const String _searchUrl = 'https://archive.org/advancedsearch.php';
  static const String _metadataBaseUrl = 'https://archive.org/metadata';

  final http.Client _client;

  InternetArchiveAdapter({http.Client? client}) : _client = client ?? http.Client();

  /// Search movies on Internet Archive matching Buildathon Spec 15 & 24
  Future<List<MediaItem>> searchMovies({
    String query = '',
    String? categoryQuery,
    int limit = 20,
    int page = 1,
    String sort = 'downloads desc',
  }) async {
    try {
      String q;
      if (query.trim().isNotEmpty) {
        q = '(${query.trim()}) AND mediatype:(movies) AND format:(h.264 OR MPEG4)';
      } else if (categoryQuery != null && categoryQuery.isNotEmpty) {
        q = '$categoryQuery AND mediatype:(movies) AND format:(h.264 OR MPEG4)';
      } else {
        q = 'collection:(feature_films OR silent_films OR short_films) AND mediatype:(movies) AND format:(h.264 OR MPEG4)';
      }

      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'q': q,
        'fl[]': 'identifier,title,description,creator,year,runtime,avg_rating,downloads',
        'rows': '$limit',
        'page': '$page',
        'output': 'json',
        'sort[]': sort,
      });

      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'SimbaMediaPlayer/1.0.0 (paval@simba.app)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final docs = data['response']?['docs'] as List? ?? [];
        return docs.map((doc) => _mapDocToMediaItem(doc as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static const List<String> _videoFormats = [
    '512kb',
    'h.264',
    'h264',
    'mpeg4',
    'mpeg-4',
    'matroska',
    'webm',
    'ogg theora',
    'ogg video',
  ];
  static const List<String> _videoFallbackFormats = ['cinepack', 'avi', 'mpeg2'];

  static final Map<String, String> _resolvedStreamCache = {};

  static int _videoFormatRank(String format) {
    final f = format.toLowerCase();
    // 512Kb MPEG4, h.264, and standard MP4 all stream directly on Android ExoPlayer
    // Group them into the primary tier so smaller files win per Buildathon Doc 15
    if (f.contains('512kb') || f.contains('h.264') || f.contains('h264') || f.contains('mpeg4') || f.contains('mpeg-4')) {
      return 0;
    }
    final idx = _videoFormats.indexWhere((c) => f.contains(c));
    if (idx != -1) return idx;
    final fb = _videoFallbackFormats.indexWhere((c) => f.contains(c));
    return fb == -1 ? -1 : _videoFormats.length + fb;
  }

  /// Resolve exact playable MP4 stream URL from item metadata per Buildathon Doc 15 §4.9
  Future<String> resolveVideoStreamUrl(String identifier) async {
    if (_resolvedStreamCache.containsKey(identifier)) {
      return _resolvedStreamCache[identifier]!;
    }

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final uri = Uri.parse('$_metadataBaseUrl/$identifier');
        final response = await _client.get(
          uri,
          headers: {'User-Agent': 'CodecMMediaPlayer/1.0.0 (paval@codecm.app)'},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final files = data['files'] as List? ?? [];

          // Rank all candidate video files per Buildathon Doc 15 algorithm
          final candidates = <Map<String, dynamic>>[];
          for (int i = 0; i < files.length; i++) {
            final f = files[i] as Map<String, dynamic>;
            final format = (f['format'] as String? ?? '').toLowerCase();
            final name = (f['name'] as String? ?? '').toLowerCase();
            if (name.contains('_thumb') || name.contains('_sample')) continue;

            final rank = _videoFormatRank(format);
            if (rank != -1 || name.endsWith('.mp4')) {
              final size = int.tryParse(f['size']?.toString() ?? '') ?? 999999999;
              // 512kb MPEG-4 derivatives and .ia.mp4 files are pre-processed with qt-faststart
              // and lightweight bitrates (360p/480p) specifically for instant mobile streaming
              final isFastStream = name.contains('512kb') || name.contains('.ia.mp4') || format.contains('512kb');
              candidates.add({
                'file': f,
                'rank': isFastStream ? -1 : (rank != -1 ? rank : 99),
                'isFastStream': isFastStream,
                'size': size,
                'index': i,
              });
            }
          }

          if (candidates.isNotEmpty) {
            candidates.sort((a, b) {
              // Priority 1: Fast-start web derivatives (512kb / .ia.mp4) first
              final aFast = (a['isFastStream'] as bool?) ?? false;
              final bFast = (b['isFastStream'] as bool?) ?? false;
              if (aFast != bFast) return aFast ? -1 : 1;

              final rankDiff = (a['rank'] as int).compareTo(b['rank'] as int);
              if (rankDiff != 0) return rankDiff;

              // Priority 2: Smaller file size streams first without initial buffer stall
              final sizeDiff = (a['size'] as int).compareTo(b['size'] as int);
              if (sizeDiff != 0) return sizeDiff;
              return (a['index'] as int).compareTo(b['index'] as int);
            });

            final best = candidates.first['file'] as Map<String, dynamic>;
            final fileName = best['name'] as String;
            final server = data['server'] as String? ?? data['d1'] as String?;
            final dir = data['dir'] as String?;
            final resolvedUrl = (server != null && dir != null && server.isNotEmpty && dir.isNotEmpty)
                ? 'https://$server$dir/$fileName'
                : 'https://archive.org/download/$identifier/$fileName';
            _resolvedStreamCache[identifier] = resolvedUrl;
            return resolvedUrl;
          }
        }
      } catch (_) {}
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }
    // Standard default stream pattern on Internet Archive
    final defaultUrl = 'https://archive.org/download/$identifier/$identifier.mp4';
    _resolvedStreamCache[identifier] = defaultUrl;
    return defaultUrl;
  }

  MediaItem _mapDocToMediaItem(Map<String, dynamic> doc) {
    final id = doc['identifier']?.toString() ?? '';

    // Extract title (handle wire array or string)
    String title = 'Untitled Movie';
    final rawTitle = doc['title'];
    if (rawTitle is List && rawTitle.isNotEmpty) {
      title = rawTitle.first.toString().trim();
    } else if (rawTitle != null) {
      title = rawTitle.toString().trim();
    }

    // Extract creator / director
    String creator = 'Public Domain Cinema';
    final rawCreator = doc['creator'];
    if (rawCreator is List && rawCreator.isNotEmpty) {
      creator = rawCreator.first.toString().trim();
    } else if (rawCreator != null && rawCreator.toString().trim().isNotEmpty) {
      creator = rawCreator.toString().trim();
    }

    // Extract year
    final rawYear = doc['year']?.toString() ?? '';
    final year = rawYear.isNotEmpty ? rawYear.split('-').first : 'Classic';

    // Extract description
    String description = '';
    final rawDesc = doc['description'];
    if (rawDesc is List && rawDesc.isNotEmpty) {
      description = HtmlUtils.clean(rawDesc.first.toString());
    } else if (rawDesc != null) {
      description = HtmlUtils.clean(rawDesc.toString());
    }
    if (description.isEmpty) {
      description = 'Public domain feature film archived on Internet Archive.';
    }

    // Extract runtime
    int durationSec = 5400; // default ~1h 30m
    final rawRuntime = doc['runtime']?.toString() ?? '';
    if (rawRuntime.isNotEmpty) {
      durationSec = _parseRuntime(rawRuntime);
    }

    // Downloads count
    final downloads = (doc['downloads'] as num?)?.toInt() ?? 1000;
    final reviewCountStr = downloads > 1000000
        ? '${(downloads / 1000000).toStringAsFixed(1)}M'
        : downloads > 1000
            ? '${(downloads / 1000).toStringAsFixed(1)}K'
            : '$downloads';

    // Direct streaming URL (will resolve to actual file or default mp4)
    final streamUrl = 'https://archive.org/download/$id/$id.mp4';

    return MediaItem(
      id: 'ia-$id',
      title: title,
      creator: creator,
      kind: MediaKind.movie,
      artworkUrl: 'https://archive.org/services/img/$id',
      streamUrl: streamUrl,
      description: description,
      durationSeconds: durationSec,
      rating: 4.8,
      reviewCount: reviewCountStr,
      category: 'Movie',
      subtitle: '$year • $creator',
      rawMetadata: doc,
    );
  }

  int _parseRuntime(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length == 3) {
        return (int.parse(parts[0]) * 3600) + (int.parse(parts[1]) * 60) + int.parse(parts[2].split('.').first);
      } else if (parts.length == 2) {
        return (int.parse(parts[0]) * 60) + int.parse(parts[1].split('.').first);
      } else {
        final sec = int.tryParse(raw.split('.').first);
        if (sec != null && sec > 0) return sec;
      }
    } catch (_) {}
    return 5400;
  }
}
