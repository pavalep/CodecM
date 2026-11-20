import 'package:equatable/equatable.dart';
import 'package:codecm/core/api/weather_adapter.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final WeatherInfo? weather;
  final List<Podcast> trendingPodcasts;
  final List<MediaItem> popularMovies;
  final List<MediaItem> popularMusic;
  final List<MediaItem> popularRadio;
  final List<MediaItem> popularShows;
  final List<MediaItem> popularAudiobooks;
  final List<MediaItem> bestForYou;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.weather,
    this.trendingPodcasts = const [],
    this.popularMovies = const [],
    this.popularMusic = const [],
    this.popularRadio = const [],
    this.popularShows = const [],
    this.popularAudiobooks = const [],
    this.bestForYou = const [],
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    WeatherInfo? weather,
    List<Podcast>? trendingPodcasts,
    List<MediaItem>? popularMovies,
    List<MediaItem>? popularMusic,
    List<MediaItem>? popularRadio,
    List<MediaItem>? popularShows,
    List<MediaItem>? popularAudiobooks,
    List<MediaItem>? bestForYou,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      weather: weather ?? this.weather,
      trendingPodcasts: trendingPodcasts ?? this.trendingPodcasts,
      popularMovies: popularMovies ?? this.popularMovies,
      popularMusic: popularMusic ?? this.popularMusic,
      popularRadio: popularRadio ?? this.popularRadio,
      popularShows: popularShows ?? this.popularShows,
      popularAudiobooks: popularAudiobooks ?? this.popularAudiobooks,
      bestForYou: bestForYou ?? this.bestForYou,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        weather,
        trendingPodcasts,
        popularMovies,
        popularMusic,
        popularRadio,
        popularShows,
        popularAudiobooks,
        bestForYou,
        errorMessage,
      ];
}
