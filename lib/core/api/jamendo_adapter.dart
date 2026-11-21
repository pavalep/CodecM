import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import '../../features/media/domain/models/media_item.dart';

class JamendoAdapter {
  static const String _baseUrl = 'https://api.jamendo.com/v3.0';
  static const String _clientId = AppEnv.jamendoClientId;

  final http.Client _client;

  JamendoAdapter({http.Client? client}) : _client = client ?? http.Client();

  /// Decode HTML entities like Jamendo text often contains (e.g. &amp;, &quot;)
  String _decodeEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  /// Get Popular Tracks
  Future<List<MediaItem>> getPopularTracks({int limit = 20, String? tag}) async {
    final queryParams = {
      'client_id': _clientId,
      'format': 'json',
      'limit': limit.toString(),
      'order': 'popularity_total',
      'include': 'musicinfo',
      if (tag != null && tag.isNotEmpty && tag.toLowerCase() != 'all') 'tags': tag.toLowerCase(),
    };

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['headers']?['status'] == 'success' && data['results'] is List) {
          final results = data['results'] as List;
          return results.map((r) => _mapTrackToMediaItem(r as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      // Network fallback
    }
    return [];
  }

  /// Search Tracks by keyword
  Future<List<MediaItem>> searchTracks(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return getPopularTracks(limit: limit);

    final queryParams = {
      'client_id': _clientId,
      'format': 'json',
      'limit': limit.toString(),
      'namesearch': query.trim(),
      'include': 'musicinfo',
    };

    try {
      final uri = Uri.parse('$_baseUrl/tracks/').replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['headers']?['status'] == 'success' && data['results'] is List) {
          final results = data['results'] as List;
          return results.map((r) => _mapTrackToMediaItem(r as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  MediaItem _mapTrackToMediaItem(Map<String, dynamic> raw) {
    final name = _decodeEntities(raw['name'] as String? ?? 'Untitled Track');
    final artist = _decodeEntities(raw['artist_name'] as String? ?? 'Unknown Artist');
    final album = _decodeEntities(raw['album_name'] as String? ?? '');
    final audio = (raw['audio'] as String?) ?? '';
    var image = (raw['image'] as String?) ?? '';
    if (image.startsWith('http://')) {
      image = 'https://${image.substring(7)}';
    }
    if (image.isEmpty) {
      image = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80';
    }

    final duration = (raw['duration'] as num?)?.toInt() ?? 180;

    return MediaItem(
      id: 'jamendo-${raw['id']}',
      title: name,
      creator: artist,
      kind: MediaKind.music,
      artworkUrl: image,
      streamUrl: audio,
      description: album.isNotEmpty ? 'Album: $album' : 'Jamendo Lossless Stream',
      durationSeconds: duration,
      rating: 4.8,
      reviewCount: '3.4K',
      category: 'Music',
      subtitle: album.isNotEmpty ? album : artist,
      rawMetadata: raw,
    );
  }
}
