import 'package:equatable/equatable.dart';
import '../../domain/models/episode.dart';

abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlayEpisode extends PlayerEvent {
  final Episode episode;
  const PlayEpisode(this.episode);

  @override
  List<Object?> get props => [episode];
}

class TogglePlayPause extends PlayerEvent {}

class SeekPosition extends PlayerEvent {
  final Duration position;
  const SeekPosition(this.position);

  @override
  List<Object?> get props => [position];
}

class SeekRelative extends PlayerEvent {
  final Duration offset; // e.g. -15s or +15s
  const SeekRelative(this.offset);

  @override
  List<Object?> get props => [offset];
}

class ChangePlaybackSpeed extends PlayerEvent {
  final double speed;
  const ChangePlaybackSpeed(this.speed);

  @override
  List<Object?> get props => [speed];
}

class SetSleepTimer extends PlayerEvent {
  final int minutes; // 0 for off, 15, 30, 45, -1 for end of episode
  const SetSleepTimer(this.minutes);

  @override
  List<Object?> get props => [minutes];
}

class AddToQueue extends PlayerEvent {
  final Episode episode;
  const AddToQueue(this.episode);

  @override
  List<Object?> get props => [episode];
}

class RemoveFromQueue extends PlayerEvent {
  final Episode episode;
  const RemoveFromQueue(this.episode);

  @override
  List<Object?> get props => [episode];
}

class ReorderQueue extends PlayerEvent {
  final int oldIndex;
  final int newIndex;
  const ReorderQueue(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

class ClearQueue extends PlayerEvent {}

class PlayNextTrack extends PlayerEvent {}

class PlayPreviousTrack extends PlayerEvent {}

class ToggleAutoplaySmartAI extends PlayerEvent {}

class StopPlayback extends PlayerEvent {}

