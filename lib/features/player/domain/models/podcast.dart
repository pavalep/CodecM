import 'package:equatable/equatable.dart';
import 'episode.dart';

class Podcast extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String hosts;
  final String artworkUrl;
  final String description;
  final double rating;
  final String reviewCount;
  final int episodeCount;
  final String rankGlobal;
  final List<String> categories;
  final bool isFollowing;
  final double onDeviceAffinity;
  final String feedUrl;
  final List<Episode> episodes;

  const Podcast({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.hosts,
    required this.artworkUrl,
    required this.description,
    this.rating = 4.9,
    this.reviewCount = '1.2K',
    this.episodeCount = 24,
    this.rankGlobal = 'Top 1% Global',
    this.categories = const ['Technology', 'Culture'],
    this.isFollowing = false,
    this.onDeviceAffinity = 0.98,
    this.feedUrl = '',
    this.episodes = const [],
  });

  String get formattedRating => rating.toStringAsFixed(1);

  Podcast copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? hosts,
    String? artworkUrl,
    String? description,
    double? rating,
    String? reviewCount,
    int? episodeCount,
    String? rankGlobal,
    List<String>? categories,
    bool? isFollowing,
    double? onDeviceAffinity,
    String? feedUrl,
    List<Episode>? episodes,
  }) {
    return Podcast(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      hosts: hosts ?? this.hosts,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      episodeCount: episodeCount ?? this.episodeCount,
      rankGlobal: rankGlobal ?? this.rankGlobal,
      categories: categories ?? this.categories,
      isFollowing: isFollowing ?? this.isFollowing,
      onDeviceAffinity: onDeviceAffinity ?? this.onDeviceAffinity,
      feedUrl: feedUrl ?? this.feedUrl,
      episodes: episodes ?? this.episodes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        hosts,
        artworkUrl,
        rating,
        episodeCount,
        isFollowing,
        onDeviceAffinity,
        feedUrl,
        episodes,
      ];
}
