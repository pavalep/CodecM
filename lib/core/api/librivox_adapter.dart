import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/media/domain/models/media_item.dart';

class LibriVoxAdapter {
  static const String _baseUrl = 'https://librivox.org/api/feed/audiobooks';

  final http.Client _client;

  LibriVoxAdapter({http.Client? client}) : _client = client ?? http.Client();

  /// Parse total time HH:MM:SS to seconds
  int _parseDuration(String? totalTime) {
    if (totalTime == null) return 7200;
    final parts = totalTime.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    } else if (parts.length == 2) {
      return parts[0] * 60 + parts[1];
    }
    return parts.isNotEmpty ? parts[0] : 7200;
  }

  /// Get Popular / Recent Audiobooks
  Future<List<MediaItem>> getAudiobooks({int limit = 20, int offset = 0}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'format': 'json',
        'limit': limit.toString(),
        'offset': offset.toString(),
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final booksRaw = data['books'];
        List<Map<String, dynamic>> booksList = [];
        if (booksRaw is List) {
          booksList = booksRaw.cast<Map<String, dynamic>>();
        } else if (booksRaw is Map) {
          booksList = booksRaw.values.whereType<Map<String, dynamic>>().toList();
        }

        return booksList.map((b) => _mapBookToMediaItem(b)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search Audiobooks by title
  Future<List<MediaItem>> searchAudiobooks(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return getAudiobooks(limit: limit);

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'format': 'json',
        'title': '^${query.trim()}',
        'limit': limit.toString(),
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final booksRaw = data['books'];
        List<Map<String, dynamic>> booksList = [];
        if (booksRaw is List) {
          booksList = booksRaw.cast<Map<String, dynamic>>();
        } else if (booksRaw is Map) {
          booksList = booksRaw.values.whereType<Map<String, dynamic>>().toList();
        }

        return booksList.map((b) => _mapBookToMediaItem(b)).toList();
      }
    } catch (_) {}
    return [];
  }

  MediaItem _mapBookToMediaItem(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '0';
    final title = (raw['title'] as String?)?.trim() ?? 'Untitled Audiobook';
    final description = (raw['description'] as String?)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';

    // Author extraction
    String author = 'Classic Author';
    final authors = raw['authors'] as List?;
    if (authors != null && authors.isNotEmpty) {
      final first = authors.first as Map<String, dynamic>;
      final firstN = first['first_name'] as String? ?? '';
      final lastN = first['last_name'] as String? ?? '';
      author = '$firstN $lastN'.trim();
      if (authors.length > 1) {
        author += ' & others';
      }
    }

    final durationSecs = _parseDuration(raw['totaltime'] as String?);
    final zipUrl = (raw['url_zip_file'] as String?) ?? '';
    final iarchiveUrl = (raw['url_iarchive'] as String?) ?? '';

    // Audio stream URL or Archive detail
    final streamUrl = iarchiveUrl.isNotEmpty ? iarchiveUrl : zipUrl;

    const image = 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop&q=80';

    return MediaItem(
      id: 'librivox-$id',
      title: title,
      creator: author,
      kind: MediaKind.audiobook,
      artworkUrl: image,
      streamUrl: streamUrl,
      description: description.isNotEmpty ? description : 'Public domain audiobook published by LibriVox.',
      durationSeconds: durationSecs,
      rating: 4.9,
      reviewCount: '1.8K',
      category: 'Audiobook',
      subtitle: author,
      rawMetadata: raw,
    );
  }
}
