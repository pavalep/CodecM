import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';

/// Singleton manager that coordinates active VideoPlayerController state
/// between VideoPlayerPage and MiniPlayerWidget.
class VideoPlaybackManager {
  static final VideoPlaybackManager instance = VideoPlaybackManager._internal();
  VideoPlaybackManager._internal();

  VideoPlayerController? _controller;
  MediaItem? _currentItem;

  final ValueNotifier<bool> hasActiveVideoNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);

  VideoPlayerController? get controller => _controller;
  MediaItem? get currentItem => _currentItem;

  void attachController(VideoPlayerController controller, MediaItem item) {
    if (_controller != null && _controller != controller) {
      _controller!.removeListener(_onControllerUpdated);
      _controller!.dispose();
    }
    _controller = controller;
    _currentItem = item;
    hasActiveVideoNotifier.value = true;
    _controller!.addListener(_onControllerUpdated);
    _onControllerUpdated();
  }

  void _onControllerUpdated() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    isPlayingNotifier.value = ctrl.value.isPlaying;
    positionNotifier.value = ctrl.value.position;
    durationNotifier.value = ctrl.value.duration;
  }

  void togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    isPlayingNotifier.value = ctrl.value.isPlaying;
  }

  void seekRelative(Duration offset) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final nextPos = ctrl.value.position + offset;
    final dur = ctrl.value.duration;
    if (dur > Duration.zero) {
      final clamped = nextPos < Duration.zero
          ? Duration.zero
          : (nextPos > dur ? dur : nextPos);
      ctrl.seekTo(clamped);
    } else {
      ctrl.seekTo(nextPos < Duration.zero ? Duration.zero : nextPos);
    }
  }

  void stop() {
    final ctrl = _controller;
    _controller = null;
    _currentItem = null;
    hasActiveVideoNotifier.value = false;
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration.zero;
    if (ctrl != null) {
      ctrl.removeListener(_onControllerUpdated);
      ctrl.pause();
      ctrl.dispose();
    }
  }
}
