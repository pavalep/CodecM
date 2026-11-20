import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/media/domain/models/media_item.dart';

class TVmazeAdapter {
  static const String _baseUrl = 'https://api.tvmaze.com';

  final http.Client _client;

  TVmazeAdapter({http.Client? client}) : _client = client ?? http.Client();

  String _stripHtml(String? text) {
    if (text == null) return '';
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }

  /// Get Popular TV Shows
  Future<List<MediaItem>> getPopularShows({int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/shows?page=$page');
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.take(limit).map((s) => _mapShowToMediaItem(s as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search TV Shows
  Future<List<MediaItem>> searchShows(String query) async {
    if (query.trim().isEmpty) return getPopularShows();

    try {
      final uri = Uri.parse('$_baseUrl/search/shows?q=${Uri.encodeComponent(query.trim())}');
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list
            .map((item) => _mapShowToMediaItem((item as Map<String, dynamic>)['show'] as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Episodes for Show
  Future<List<Map<String, dynamic>>> getShowEpisodes(int showId) async {
    try {
      final uri = Uri.parse('$_baseUrl/shows/$showId/episodes');
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  MediaItem _mapShowToMediaItem(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '0';
    final name = raw['name'] as String? ?? 'Untitled Show';
    final summary = _stripHtml(raw['summary'] as String?);
    final ratingObj = raw['rating'] as Map<String, dynamic>?;
    final ratingNum = (ratingObj?['average'] as num?)?.toDouble() ?? 8.5;
    final networkObj = raw['network'] as Map<String, dynamic>?;
    final webChannelObj = raw['webChannel'] as Map<String, dynamic>?;
    final network = (networkObj?['name'] as String?) ?? (webChannelObj?['name'] as String?) ?? 'Original Series';
    final genres = (raw['genres'] as List?)?.cast<String>() ?? [];

    final images = raw['image'] as Map<String, dynamic>?;
    var image = (images?['original'] as String?) ?? (images?['medium'] as String?) ?? '';
    if (image.startsWith('http://')) {
      image = 'https://${image.substring(7)}';
    }
    if (image.isEmpty) {
      image = 'https://images.unsplash.com/photo-1578022761797-b8636ac1773c?w=600&auto=format&fit=crop&q=80';
    }

    final premiered = raw['premiered'] as String? ?? '';
    final year = premiered.isNotEmpty ? premiered.split('-').first : '2024';

    return MediaItem(
      id: 'tvmaze-$id',
      title: name,
      creator: network,
      kind: MediaKind.show,
      artworkUrl: image,
      streamUrl: raw['url'] as String? ?? '',
      description: summary.isNotEmpty ? summary : 'Official TV Show production.',
      durationSeconds: 2700, // standard ~45 min
      rating: (ratingNum / 2).clamp(1.0, 5.0),
      reviewCount: '${(ratingNum * 1.5).toStringAsFixed(1)}K',
      category: genres.isNotEmpty ? genres.first : 'Drama',
      tags: genres,
      subtitle: '$year • $network',
      rawMetadata: raw,
    );
  }
}
