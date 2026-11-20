import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/media/domain/models/media_item.dart';

class IPTVAdapter {
  static const String _streamsUrl = 'https://iptv-org.github.io/api/streams.json';

  final http.Client _client;

  IPTVAdapter({http.Client? client}) : _client = client ?? http.Client();

  /// Get Live TV Channels & Streams from IPTV-org API
  Future<List<MediaItem>> getLiveStreams({int limit = 30}) async {
    try {
      final response = await _client.get(Uri.parse(_streamsUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;

        final filtered = list.where((item) {
          final url = item['url'] as String? ?? '';
          final ch = item['channel'] as String? ?? '';
          return url.startsWith('https://') && url.contains('.m3u8') && ch.isNotEmpty;
        }).take(limit).toList();

        return filtered.map((s) => _mapStreamToMediaItem(s as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Live Cinema & Movie Streams from IPTV-org API
  Future<List<MediaItem>> getMovieStreams({int limit = 25}) async {
    try {
      final response = await _client.get(Uri.parse(_streamsUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;

        final movieKeywords = ['movie', 'cinema', 'film', 'action', 'hollywood', 'classic', 'drama', 'box'];

        final filtered = list.where((item) {
          final url = item['url'] as String? ?? '';
          final ch = (item['channel'] as String? ?? '').toLowerCase();
          final matchesMovie = movieKeywords.any((k) => ch.contains(k));
          return matchesMovie && url.startsWith('https://') && url.contains('.m3u8');
        }).take(limit).toList();

        if (filtered.isNotEmpty) {
          return filtered.map((s) => _mapMovieStreamToMediaItem(s as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  MediaItem _mapStreamToMediaItem(Map<String, dynamic> raw) {
    final rawChannel = (raw['channel'] as String?)?.trim() ?? 'Live Stream';
    final channelName = _formatChannelName(rawChannel);
    final url = (raw['url'] as String?) ?? '';
    final quality = (raw['quality'] as String?) ?? 'HD 720p';

    return MediaItem(
      id: 'iptv-${rawChannel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}',
      title: channelName,
      creator: 'Live Broadcast • $quality',
      kind: MediaKind.show,
      artworkUrl: _getChannelArtwork(rawChannel),
      streamUrl: url,
      description: 'Live broadcast feed for $channelName streaming in $quality via public HLS broadcast.',
      durationSeconds: 0,
      rating: 4.8,
      reviewCount: '4.2K',
      category: 'Live TV',
      subtitle: quality,
      rawMetadata: raw,
    );
  }

  MediaItem _mapMovieStreamToMediaItem(Map<String, dynamic> raw) {
    final rawChannel = (raw['channel'] as String?)?.trim() ?? 'Cinema Channel';
    final channelName = _formatChannelName(rawChannel);
    final url = (raw['url'] as String?) ?? '';
    final quality = (raw['quality'] as String?) ?? 'HD 1080p';

    return MediaItem(
      id: 'movie-${rawChannel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}',
      title: '$channelName Movie Cinema',
      creator: 'Cinema Broadcast • $quality',
      kind: MediaKind.movie,
      artworkUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&auto=format&fit=crop&q=80',
      streamUrl: url,
      description: 'Official continuous motion picture cinema broadcast streaming full-length features in $quality.',
      durationSeconds: 5400, // ~1h 30m
      rating: 4.9,
      reviewCount: '5.6K',
      category: 'Movies & Cinema',
      subtitle: '$quality • Live Cinema',
      rawMetadata: raw,
    );
  }

  String _formatChannelName(String raw) {
    final clean = raw.replaceAll(RegExp(r'\.[a-z]{2,3}$'), '');
    final words = clean.split(RegExp(r'[-_.]'));
    return words.map((w) {
      if (w.isEmpty) return '';
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  String _getChannelArtwork(String ch) {
    final c = ch.toLowerCase();
    if (c.contains('news') || c.contains('dw') || c.contains('aljazeera') || c.contains('france')) {
      return 'https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=600&auto=format&fit=crop&q=80';
    } else if (c.contains('movie') || c.contains('cinema') || c.contains('action')) {
      return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&auto=format&fit=crop&q=80';
    } else if (c.contains('sport') || c.contains('race')) {
      return 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=600&auto=format&fit=crop&q=80';
    } else if (c.contains('music')) {
      return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?w=600&auto=format&fit=crop&q=80';
  }
}
