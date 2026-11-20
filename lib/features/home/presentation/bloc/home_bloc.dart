import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final MediaRepository _repository;

  HomeBloc({MediaRepository? repository})
      : _repository = repository ?? MediaRepository(),
        super(const HomeState()) {
    on<LoadHomeData>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(LoadHomeData event, Emitter<HomeState> emit) async {
    if (state.status == HomeStatus.initial || event.refresh) {
      emit(state.copyWith(status: HomeStatus.loading));
    }

    try {
      final results = await Future.wait([
        _repository.getWeather(),
        _repository.getTrendingPodcasts(),
        _repository.getPopularMovies(),
        _repository.getPopularMusic(),
        _repository.getPopularRadio(),
        _repository.getPopularShows(),
        _repository.getPopularAudiobooks(),
      ]);

      final weather = results[0] as dynamic;
      final podcasts = results[1] as dynamic;
      final movies = results[2] as List<MediaItem>;
      final music = results[3] as List<MediaItem>;
      final radio = results[4] as List<MediaItem>;
      final shows = results[5] as List<MediaItem>;
      final audiobooks = results[6] as List<MediaItem>;

      // Construct "Best for you" editorial mix from real items across all lanes
      final List<MediaItem> bestForYou = [];
      if (movies.isNotEmpty) bestForYou.add(movies.first);
      if (music.isNotEmpty) bestForYou.add(music.first);
      if (radio.isNotEmpty) bestForYou.add(radio.first);
      if (shows.isNotEmpty) bestForYou.add(shows.first);
      if (audiobooks.isNotEmpty) bestForYou.add(audiobooks.first);
      if (movies.length > 1) bestForYou.add(movies[1]);
      if (music.length > 1) bestForYou.add(music[1]);
      if (radio.length > 1) bestForYou.add(radio[1]);

      emit(state.copyWith(
        status: HomeStatus.loaded,
        weather: weather,
        trendingPodcasts: podcasts,
        popularMovies: movies,
        popularMusic: music,
        popularRadio: radio,
        popularShows: shows,
        popularAudiobooks: audiobooks,
        bestForYou: bestForYou,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
