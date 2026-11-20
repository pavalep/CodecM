import 'package:equatable/equatable.dart';

class Episode extends Equatable {
  final String id;
  final String title;
  final String showTitle;
  final String host;
  final String durationString;
  final Duration totalDuration;
  final String artworkUrl;
  final String description;
  final double semanticMatchScore; // LiteRT / EmbeddingGemma score (0.0 to 1.0)
  final String publishedDate;
  final bool isDownloaded;
  final double progress; // 0.0 to 1.0
  final List<String> topicTags;
  final String? audioUrl;
  final int? feedId;
  final List<EpisodeChapter> chapters;

  static const Episode empty = Episode(
    id: '',
    title: '',
    showTitle: '',
    host: '',
    durationString: '',
    totalDuration: Duration.zero,
    artworkUrl: '',
    description: '',
    publishedDate: '',
  );

  const Episode({
    required this.id,
    required this.title,
    required this.showTitle,
    required this.host,
    required this.durationString,
    required this.totalDuration,
    required this.artworkUrl,
    required this.description,
    this.semanticMatchScore = 0.95,
    required this.publishedDate,
    this.isDownloaded = false,
    this.progress = 0.0,
    this.topicTags = const [],
    this.audioUrl,
    this.feedId,
    this.chapters = const [],
  });

  Episode copyWith({
    String? id,
    String? title,
    String? showTitle,
    String? host,
    String? durationString,
    Duration? totalDuration,
    String? artworkUrl,
    String? description,
    double? semanticMatchScore,
    String? publishedDate,
    bool? isDownloaded,
    double? progress,
    List<String>? topicTags,
    String? audioUrl,
    int? feedId,
    List<EpisodeChapter>? chapters,
  }) {
    return Episode(
      id: id ?? this.id,
      title: title ?? this.title,
      showTitle: showTitle ?? this.showTitle,
      host: host ?? this.host,
      durationString: durationString ?? this.durationString,
      totalDuration: totalDuration ?? this.totalDuration,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      description: description ?? this.description,
      semanticMatchScore: semanticMatchScore ?? this.semanticMatchScore,
      publishedDate: publishedDate ?? this.publishedDate,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      progress: progress ?? this.progress,
      topicTags: topicTags ?? this.topicTags,
      audioUrl: audioUrl ?? this.audioUrl,
      feedId: feedId ?? this.feedId,
      chapters: chapters ?? this.chapters,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        showTitle,
        host,
        durationString,
        totalDuration,
        artworkUrl,
        publishedDate,
        isDownloaded,
        progress,
        audioUrl,
        feedId,
      ];
}

class EpisodeChapter extends Equatable {
  final String title;
  final Duration startTime;
  final Duration endTime;

  const EpisodeChapter({
    required this.title,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [title, startTime, endTime];
}
