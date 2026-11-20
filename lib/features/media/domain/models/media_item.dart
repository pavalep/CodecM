import 'package:equatable/equatable.dart';

enum MediaKind {
  podcast,
  music,
  radio,
  audiobook,
  show,
  video,
  movie,
}

enum MediaLane {
  audio,
  video,
}

extension MediaKindExtension on MediaKind {
  String get displayName {
    switch (this) {
      case MediaKind.podcast:
        return 'Podcast';
      case MediaKind.music:
        return 'Music';
      case MediaKind.radio:
        return 'Radio';
      case MediaKind.audiobook:
        return 'Audiobook';
      case MediaKind.show:
        return 'TV Show';
      case MediaKind.video:
        return 'Video';
      case MediaKind.movie:
        return 'Movie';
    }
  }

  MediaLane get lane {
    switch (this) {
      case MediaKind.show:
      case MediaKind.video:
      case MediaKind.movie:
        return MediaLane.video;
      default:
        return MediaLane.audio;
    }
  }
}

class MediaItem extends Equatable {
  final String id;
  final String title;
  final String creator; // Host / Artist / Author / Network
  final MediaKind kind;
  final String artworkUrl;
  final String streamUrl;
  final String description;
  final int durationSeconds;
  final double rating;
  final String reviewCount;
  final String category;
  final List<String> tags;
  final bool isFavorite;
  final int episodesCount;
  final String? publishedDate;
  final String? subtitle;
  final Map<String, dynamic> rawMetadata;

  const MediaItem({
    required this.id,
    required this.title,
    required this.creator,
    required this.kind,
    required this.artworkUrl,
    required this.streamUrl,
    this.description = '',
    this.durationSeconds = 0,
    this.rating = 4.9,
    this.reviewCount = '1.2K',
    this.category = 'General',
    this.tags = const [],
    this.isFavorite = false,
    this.episodesCount = 1,
    this.publishedDate,
    this.subtitle,
    this.rawMetadata = const {},
  });

  MediaLane get lane => kind.lane;
  bool get isVideo => lane == MediaLane.video;

  String get durationString {
    if (durationSeconds <= 0) return 'Live';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedRating => rating.toStringAsFixed(1);

  MediaItem copyWith({
    String? id,
    String? title,
    String? creator,
    MediaKind? kind,
    String? artworkUrl,
    String? streamUrl,
    String? description,
    int? durationSeconds,
    double? rating,
    String? reviewCount,
    String? category,
    List<String>? tags,
    bool? isFavorite,
    int? episodesCount,
    String? publishedDate,
    String? subtitle,
    Map<String, dynamic>? rawMetadata,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      kind: kind ?? this.kind,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      description: description ?? this.description,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      episodesCount: episodesCount ?? this.episodesCount,
      publishedDate: publishedDate ?? this.publishedDate,
      subtitle: subtitle ?? this.subtitle,
      rawMetadata: rawMetadata ?? this.rawMetadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        creator,
        kind,
        artworkUrl,
        streamUrl,
        description,
        durationSeconds,
        rating,
        reviewCount,
        category,
        tags,
        isFavorite,
        episodesCount,
        publishedDate,
        subtitle,
        rawMetadata,
      ];
}
