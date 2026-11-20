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
        q = '(${query.trim()}) AND mediatype:(movies)';
      } else if (categoryQuery != null && categoryQuery.isNotEmpty) {
        q = '$categoryQuery AND mediatype:(movies)';
      } else {
        q = 'collection:(feature_films OR silent_films OR short_films) AND mediatype:(movies)';
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

  /// Resolve exact playable MP4 stream URL from item metadata
  Future<String> resolveVideoStreamUrl(String identifier) async {
    try {
      final uri = Uri.parse('$_metadataBaseUrl/$identifier');
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'SimbaMediaPlayer/1.0.0 (paval@simba.app)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final files = data['files'] as List? ?? [];

        // Find primary h.264 MP4 file
        final mp4File = files.firstWhere(
          (f) {
            final name = (f['name'] as String? ?? '').toLowerCase();
            return name.endsWith('.mp4') && !name.contains('_512kb') && !name.contains('_thumb');
          },
          orElse: () => files.firstWhere(
            (f) => (f['name'] as String? ?? '').toLowerCase().endsWith('.mp4'),
            orElse: () => null,
          ),
        );

        if (mp4File != null) {
          final fileName = mp4File['name'] as String;
          return 'https://archive.org/download/$identifier/$fileName';
        }
      }
    } catch (_) {}
    // Standard default stream pattern on Internet Archive
    return 'https://archive.org/download/$identifier/$identifier.mp4';
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
