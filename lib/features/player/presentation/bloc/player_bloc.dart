import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart' as jab;
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/player/domain/models/episode.dart';
import 'player_event.dart';
import 'player_state.dart';

class _InternalPositionChanged extends PlayerEvent {
  final Duration position;
  const _InternalPositionChanged(this.position);

  @override
  List<Object?> get props => [position];
}

class _InternalDurationChanged extends PlayerEvent {
  final Duration duration;
  const _InternalDurationChanged(this.duration);

  @override
  List<Object?> get props => [duration];
}

class _InternalStatusChanged extends PlayerEvent {
  final PlaybackStatus status;
  const _InternalStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final ja.AudioPlayer? _audioPlayer;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  PlayerBloc({ja.AudioPlayer? audioPlayer, bool enableNativeAudio = true})
      : _audioPlayer = audioPlayer ?? (enableNativeAudio ? ja.AudioPlayer() : null),
        super(const PlayerState(
          status: PlaybackStatus.initial,
          currentEpisode: Episode.empty,
          queue: [],
        )) {
    on<PlayEpisode>(_onPlayEpisode);
    on<TogglePlayPause>(_onTogglePlayPause);
    on<SeekPosition>(_onSeekPosition);
    on<SeekRelative>(_onSeekRelative);
    on<ChangePlaybackSpeed>(_onChangePlaybackSpeed);
    on<SetSleepTimer>(_onSetSleepTimer);
    on<AddToQueue>(_onAddToQueue);
    on<RemoveFromQueue>(_onRemoveFromQueue);
    on<ReorderQueue>(_onReorderQueue);
    on<ClearQueue>(_onClearQueue);
    on<PlayNextTrack>(_onPlayNextTrack);
    on<PlayPreviousTrack>(_onPlayPreviousTrack);
    on<ToggleAutoplaySmartAI>(_onToggleAutoplaySmartAI);
    on<_InternalPositionChanged>((event, emit) => emit(state.copyWith(position: event.position)));
    on<_InternalDurationChanged>((event, emit) => emit(state.copyWith(duration: event.duration)));
    on<_InternalStatusChanged>((event, emit) => emit(state.copyWith(status: event.status)));

    if (_audioPlayer != null) {
      _initPlayerListeners();
    }
  }

  void _initPlayerListeners() {
    _posSub = _audioPlayer?.positionStream.listen((pos) {
      if (!isClosed) {
        add(_InternalPositionChanged(pos));
      }
    });

    _durSub = _audioPlayer?.durationStream.listen((dur) {
      if (dur != null && !isClosed) {
        add(_InternalDurationChanged(dur));
      }
    });

    _stateSub = _audioPlayer?.playerStateStream.listen((ps) {
      if (!isClosed) {
        final isPlaying = ps.playing;
        add(_InternalStatusChanged(isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused));
      }
    });
  }

  Future<void> _onPlayEpisode(PlayEpisode event, Emitter<PlayerState> emit) async {
    // Record into persistent recent history (max 10, de-duplicated to head)
    PersistentStorage.instance.upsertRecentHistory(MediaRepository.episodeToMediaItem(event.episode));

    emit(state.copyWith(
      currentEpisode: event.episode,
      status: PlaybackStatus.playing,
      position: Duration.zero,
      duration: event.episode.totalDuration,
    ));

    final url = event.episode.audioUrl;
    if (url != null && url.isNotEmpty) {
      try {
        final audioSource = ja.AudioSource.uri(
          Uri.parse(url),
          tag: jab.MediaItem(
            id: event.episode.id,
            title: event.episode.title,
            artist: event.episode.host.isNotEmpty ? event.episode.host : event.episode.showTitle,
            album: event.episode.showTitle,
            artUri: Uri.tryParse(event.episode.artworkUrl),
          ),
        );
        await _audioPlayer?.setAudioSource(audioSource);
        await _audioPlayer?.play();
      } catch (e) {
        // Fallback simulation if network audio stream fails
      }
    }
  }

  Future<void> _onTogglePlayPause(TogglePlayPause event, Emitter<PlayerState> emit) async {
    if (state.isPlaying) {
      emit(state.copyWith(status: PlaybackStatus.paused));
      try {
        await _audioPlayer?.pause();
      } catch (_) {}
    } else {
      emit(state.copyWith(status: PlaybackStatus.playing));
      try {
        await _audioPlayer?.play();
      } catch (_) {}
    }
  }

  void _onSeekPosition(SeekPosition event, Emitter<PlayerState> emit) {
    emit(state.copyWith(position: event.position));
  }

  Future<void> _onSeekRelative(SeekRelative event, Emitter<PlayerState> emit) async {
    final nextPos = state.position + event.offset;
    final clamped = nextPos < Duration.zero
        ? Duration.zero
        : (nextPos > state.duration ? state.duration : nextPos);
    emit(state.copyWith(position: clamped));

    try {
      await _audioPlayer?.seek(clamped);
    } catch (_) {}
  }

  Future<void> _onChangePlaybackSpeed(
      ChangePlaybackSpeed event, Emitter<PlayerState> emit) async {
    emit(state.copyWith(speed: event.speed));
    try {
      await _audioPlayer?.setSpeed(event.speed);
    } catch (_) {}
  }

  void _onSetSleepTimer(SetSleepTimer event, Emitter<PlayerState> emit) {
    emit(state.copyWith(sleepTimerMinutes: event.minutes));
  }

  void _onAddToQueue(AddToQueue event, Emitter<PlayerState> emit) {
    final updated = List<Episode>.from(state.queue)..add(event.episode);
    emit(state.copyWith(queue: updated));
  }

  void _onRemoveFromQueue(RemoveFromQueue event, Emitter<PlayerState> emit) {
    final updated = List<Episode>.from(state.queue)..remove(event.episode);
    emit(state.copyWith(queue: updated));
  }

  void _onReorderQueue(ReorderQueue event, Emitter<PlayerState> emit) {
    final updated = List<Episode>.from(state.queue);
    int newIdx = event.newIndex;
    if (newIdx > event.oldIndex) newIdx--;
    final item = updated.removeAt(event.oldIndex);
    updated.insert(newIdx, item);
    emit(state.copyWith(queue: updated));
  }

  void _onClearQueue(ClearQueue event, Emitter<PlayerState> emit) {
    emit(state.copyWith(queue: const []));
  }

  void _onPlayNextTrack(PlayNextTrack event, Emitter<PlayerState> emit) {
    if (state.queue.isNotEmpty) {
      final next = state.queue.first;
      final remaining = List<Episode>.from(state.queue)..removeAt(0);
      emit(state.copyWith(
        currentEpisode: next,
        queue: remaining,
        position: Duration.zero,
        duration: next.totalDuration,
        status: PlaybackStatus.playing,
      ));
    }
  }

  void _onPlayPreviousTrack(PlayPreviousTrack event, Emitter<PlayerState> emit) {
    emit(state.copyWith(position: Duration.zero));
  }

  void _onToggleAutoplaySmartAI(
      ToggleAutoplaySmartAI event, Emitter<PlayerState> emit) {
    emit(state.copyWith(
        isSmartAutoplayEnabled: !state.isSmartAutoplayEnabled));
  }

  @override
  Future<void> close() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer?.dispose();
    return super.close();
  }
}
