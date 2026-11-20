import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/media/domain/models/media_item.dart';

class RadioBrowserAdapter {
  static const String _baseUrl = 'https://de1.api.radio-browser.info/json';

  final http.Client _client;

  RadioBrowserAdapter({http.Client? client}) : _client = client ?? http.Client();

  /// Get Popular / Top Click Stations
  Future<List<MediaItem>> getPopularStations({int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stations/topclick/$limit');
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.map((s) => _mapStationToMediaItem(s as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search Stations by name or tag
  Future<List<MediaItem>> searchStations(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return getPopularStations(limit: limit);

    try {
      final uri = Uri.parse('$_baseUrl/stations/search').replace(queryParameters: {
        'name': query.trim(),
        'limit': limit.toString(),
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.map((s) => _mapStationToMediaItem(s as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Stations by Genre / Tag
  Future<List<MediaItem>> getStationsByTag(String tag, {int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/stations/bytag/${Uri.encodeComponent(tag)}').replace(queryParameters: {
        'limit': limit.toString(),
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.map((s) => _mapStationToMediaItem(s as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  MediaItem _mapStationToMediaItem(Map<String, dynamic> raw) {
    final name = (raw['name'] as String?)?.trim() ?? 'Radio Station';
    final country = (raw['country'] as String?)?.trim() ?? 'Global';
    final tags = (raw['tags'] as String?)?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? [];
    final url = (raw['url_resolved'] as String?) ?? (raw['url'] as String?) ?? '';
    var image = (raw['favicon'] as String?)?.trim() ?? '';
    if (image.startsWith('http://')) {
      image = 'https://${image.substring(7)}';
    }
    if (image.isEmpty) {
      image = 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=600&auto=format&fit=crop&q=80';
    }

    final bitrate = (raw['bitrate'] as num?)?.toInt() ?? 128;
    final codec = (raw['codec'] as String?) ?? 'MP3';

    return MediaItem(
      id: 'radio-${raw['stationuuid'] ?? raw['id'] ?? name}',
      title: name,
      creator: country.isNotEmpty ? country : 'Worldwide Radio',
      kind: MediaKind.radio,
      artworkUrl: image,
      streamUrl: url,
      description: 'Live Broadcast • $codec ${bitrate > 0 ? '$bitrate kbps' : 'HD Stream'}. Tags: ${tags.take(3).join(', ')}',
      durationSeconds: 0, // Live stream
      rating: 4.8,
      reviewCount: '${((raw['clickcount'] as num?)?.toInt() ?? 540) ~/ 100}K',
      category: 'Radio',
      tags: tags,
      subtitle: country,
      rawMetadata: raw,
    );
  }
}
