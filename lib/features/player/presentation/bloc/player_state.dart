import 'package:equatable/equatable.dart';
import '../../domain/models/episode.dart';

enum PlaybackStatus { initial, playing, paused, buffering, stopped }

class PlayerState extends Equatable {
  final PlaybackStatus status;
  final Episode currentEpisode;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final double speed;
  final int sleepTimerMinutes;
  final List<Episode> queue;
  final bool isSmartAutoplayEnabled;
  final Episode? predictedNext;

  const PlayerState({
    required this.status,
    required this.currentEpisode,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.sleepTimerMinutes = 0,
    this.queue = const [],
    this.isSmartAutoplayEnabled = true,
    this.predictedNext,
  });

  bool get isPlaying => status == PlaybackStatus.playing;

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double get bufferedProgress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  PlayerState copyWith({
    PlaybackStatus? status,
    Episode? currentEpisode,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    double? speed,
    int? sleepTimerMinutes,
    List<Episode>? queue,
    bool? isSmartAutoplayEnabled,
    Episode? predictedNext,
  }) {
    return PlayerState(
      status: status ?? this.status,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      queue: queue ?? this.queue,
      isSmartAutoplayEnabled: isSmartAutoplayEnabled ?? this.isSmartAutoplayEnabled,
      predictedNext: predictedNext ?? this.predictedNext,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentEpisode,
        position,
        bufferedPosition,
        duration,
        speed,
        sleepTimerMinutes,
        queue,
        isSmartAutoplayEnabled,
        predictedNext,
      ];
}
