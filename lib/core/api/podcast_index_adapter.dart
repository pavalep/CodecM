import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import '../utils/html_utils.dart';
import '../../features/player/domain/models/podcast.dart';
import '../../features/player/domain/models/episode.dart';

class PodcastIndexAdapter {
  static const String _baseUrl = 'https://api.podcastindex.org/api/1.0';
  static const String _apiKey = AppEnv.podcastIndexApiKey;
  static const String _apiSecret = AppEnv.podcastIndexApiSecret;
  static const String _userAgent = 'CodecMMediaPlayer/1.0.0 (pavalep@gmail.com)';

  final http.Client _client;

  PodcastIndexAdapter({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _buildAuthHeaders() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signature = sha1.convert(utf8.encode(_apiKey + _apiSecret + timestamp)).toString();

    return {
      'User-Agent': _userAgent,
      'X-Auth-Key': _apiKey,
      'X-Auth-Date': timestamp,
      'Authorization': signature,
    };
  }

  String _secureUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=600&auto=format&fit=crop&q=80';
    }
    if (url.startsWith('http://')) {
      return 'https://${url.substring(7)}';
    }
    return url;
  }

  /// Get Trending Podcasts
  Future<List<Podcast>> getTrendingPodcasts({int max = 20, String? categoryId}) async {
    try {
      final queryParams = {
        'max': max.toString(),
        if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') 'cat': categoryId,
      };

      final uri = Uri.parse('$_baseUrl/podcasts/trending').replace(queryParameters: queryParams);
      final response = await _client
          .get(uri, headers: _buildAuthHeaders())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'true' && data['feeds'] is List) {
          final feeds = data['feeds'] as List;
          return feeds.map((f) => _mapRawFeedToPodcast(f as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      // Fallback handled in repository
    }
    return [];
  }

  /// Search Podcasts by Term
  Future<List<Podcast>> searchPodcasts(String query, {int max = 25}) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/byterm').replace(queryParameters: {
        'q': query,
        'max': max.toString(),
      });
      final response = await _client
          .get(uri, headers: _buildAuthHeaders())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'true' && data['feeds'] is List) {
          final feeds = data['feeds'] as List;
          return feeds.map((f) => _mapRawFeedToPodcast(f as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  /// Get Episodes by Podcast Feed ID
  Future<List<Episode>> getEpisodesByFeedId(int feedId, {int max = 25}) async {
    try {
      final uri = Uri.parse('$_baseUrl/episodes/byfeedid').replace(queryParameters: {
        'id': feedId.toString(),
        'max': max.toString(),
      });
      final response = await _client
          .get(uri, headers: _buildAuthHeaders())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'true' && data['items'] is List) {
          final items = data['items'] as List;
          return items.map((it) => _mapRawItemToEpisode(it as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  /// Get Recent Episodes across network
  Future<List<Episode>> getRecentEpisodes({int max = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/recent/episodes').replace(queryParameters: {
        'max': max.toString(),
      });
      final response = await _client
          .get(uri, headers: _buildAuthHeaders())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'true' && data['items'] is List) {
          final items = data['items'] as List;
          return items.map((it) => _mapRawItemToEpisode(it as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  /// Get Podcast Show Details by Feed ID
  Future<Podcast?> getPodcastById(int feedId) async {
    try {
      final uri = Uri.parse('$_baseUrl/podcasts/byfeedid').replace(queryParameters: {
        'id': feedId.toString(),
      });
      final response = await _client
          .get(uri, headers: _buildAuthHeaders())
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'true' && data['feed'] is Map) {
          return _mapRawFeedToPodcast(data['feed'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  Podcast _mapRawFeedToPodcast(Map<String, dynamic> f) {
    final rawCats = f['categories'];
    List<String> categories = [];
    if (rawCats is Map) {
      categories = rawCats.values.map((v) => v.toString()).toList();
    } else if (rawCats is List) {
      categories = rawCats.map((v) => v.toString()).toList();
    }
    if (categories.isEmpty) categories = ['Podcast', 'Culture'];

    final rawEpisodeCount = f['episodeCount'];
    final episodeCount = (rawEpisodeCount is num) ? rawEpisodeCount.toInt() : 12;

    return Podcast(
      id: f['id'].toString(),
      title: (f['title'] ?? 'Untitled Show').toString().trim(),
      subtitle: (f['author'] ?? 'Featured Host').toString().trim(),
      hosts: (f['author'] ?? 'Host').toString().trim(),
      artworkUrl: _secureUrl(f['image']?.toString()),
      description: HtmlUtils.clean((f['description'] ?? 'No description available for this show.').toString()),
      rating: double.parse((4.7 + ((f['id'] as int? ?? 1) % 3) * 0.1).toStringAsFixed(1)),
      reviewCount: '${((f['id'] as int? ?? 1200) % 800) + 200}',
      episodeCount: episodeCount,
      rankGlobal: 'Top 50 Global',
      categories: categories,
      feedUrl: f['url']?.toString() ?? '',
    );
  }

  Episode _mapRawItemToEpisode(Map<String, dynamic> it) {
    final durationSeconds = (it['duration'] is num) ? (it['duration'] as num).toInt() : 2400;
    final totalDuration = Duration(seconds: durationSeconds > 0 ? durationSeconds : 2400);

    String durationStr = '${totalDuration.inMinutes}m';
    if (totalDuration.inHours > 0) {
      durationStr = '${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m';
    }

    final rawDate = it['datePublished'];
    String publishedDate = 'Recent';
    if (rawDate is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt() * 1000);
      publishedDate = '${dt.month}/${dt.day}/${dt.year}';
    }

    return Episode(
      id: it['id'].toString(),
      title: (it['title'] ?? 'Untitled Episode').toString().trim(),
      showTitle: (it['feedTitle'] ?? it['author'] ?? 'Featured Podcast').toString().trim(),
      host: (it['author'] ?? 'Host').toString().trim(),
      durationString: durationStr,
      totalDuration: totalDuration,
      artworkUrl: _secureUrl(it['image']?.toString() ?? it['feedImage']?.toString()),
      description: HtmlUtils.clean((it['description'] ?? 'Episode audio stream ready to play.').toString()),
      semanticMatchScore: 0.96,
      publishedDate: publishedDate,
      isDownloaded: false,
      progress: 0.0,
      audioUrl: it['enclosureUrl']?.toString() ?? '',
      feedId: (it['feedId'] is num) ? (it['feedId'] as num).toInt() : null,
      topicTags: const ['Podcast', 'Audio'],
    );
  }
}
