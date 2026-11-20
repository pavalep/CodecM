import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/features/media/data/repositories/media_repository.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/player/data/services/video_playback_manager.dart';

/// Full-featured Video Player with dedicated VOD Movie playback and Live TV broadcast modes
class VideoPlayerPage extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem>? playlist;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.item,
    this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

enum VideoAspectRatioMode {
  fit169('16:9 Fit', 16 / 9),
  fill('Fill Screen', null),
  classic43('4:3 Classic', 4 / 3),
  original('Original', -1.0);

  final String label;
  final double? ratio;
  const VideoAspectRatioMode(this.label, this.ratio);
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with WidgetsBindingObserver {
  static const MethodChannel _pipChannel = MethodChannel('com.example.codecm/pip');
  final MediaRepository _repository = MediaRepository();

  VideoPlayerController? _controller;
  late MediaItem _currentItem;
  late List<MediaItem> _playlist;
  late int _currentIndex;

  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isInPipMode = false;
  bool _isDraggingScrubber = false;
  double _dragValue = 0.0;
  Timer? _hideTimer;

  // Settings & Options State
  double _playbackSpeed = 1.0;
  // Default to fast-start lightweight stream for near-instant buffering
  String _videoQuality = 'Fast Stream (SD / 480p)';
  VideoAspectRatioMode _aspectRatioMode = VideoAspectRatioMode.fit169;
  String _sleepTimerSetting = 'Off';
  Timer? _activeSleepTimer;
  bool _isMuted = false;
  double _volumeLevel = 1.0;
  String _selectedCaption = 'Off';
  bool _isFavorite = false;

  // Live TV Switcher Channel list
  List<MediaItem> _liveChannels = [];

  bool get _isMovie => _currentItem.kind == MediaKind.movie;
  bool get _isLiveTv => !_isMovie;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentItem = widget.item;
    _playlist = widget.playlist ?? [_currentItem];
    _currentIndex = widget.initialIndex;
    _isFavorite = _currentItem.isFavorite;

    // Record into persistent playback history (max 10, de-duplicated)
    PersistentStorage.instance.upsertRecentHistory(_currentItem);

    final existingCtrl = VideoPlaybackManager.instance.controller;
    if (existingCtrl != null &&
        VideoPlaybackManager.instance.currentItem?.id == widget.item.id &&
        existingCtrl.value.isInitialized) {
      _controller = existingCtrl;
      _isInitialized = true;
      _hasError = false;
    } else {
      _initializeVideo();
    }
    _resetControlsTimer();

    if (_isLiveTv) {
      _loadLiveChannels();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When returning from native PiP or background
    if (state == AppLifecycleState.resumed && _isInPipMode) {
      setState(() {
        _isInPipMode = false;
        _showControls = true;
      });
    }
  }

  Future<void> _loadLiveChannels() async {
    try {
      final channels = await _repository.getLiveVideoStreams(limit: 50);
      if (mounted) {
        setState(() {
          _liveChannels = channels;
          if (widget.playlist == null && channels.isNotEmpty) {
            _playlist = channels;
            final idx = channels.indexWhere((c) => c.id == _currentItem.id);
            if (idx != -1) _currentIndex = idx;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeVideo() async {
    String streamUrl = _currentItem.streamUrl.trim();
    debugPrint('[VideoPlayer] _initializeVideo item=${_currentItem.id}, initialStreamUrl=$streamUrl');

    setState(() {
      _hasError = false;
      _isInitialized = false;
    });

    // Auto-resolve Internet Archive movie streams if needed
    if (_isMovie || _currentItem.id.startsWith('ia-') || streamUrl.contains('archive.org')) {
      final rawId = _currentItem.id.startsWith('ia-')
          ? _currentItem.id.substring(3)
          : streamUrl.contains('archive.org/download/')
              ? streamUrl.split('archive.org/download/').last.split('/').first
              : '';
      debugPrint('[VideoPlayer] Attempting IA stream resolution for rawId=$rawId');
      if (rawId.isNotEmpty) {
        try {
          final resolved = await _repository.resolveMovieStreamUrl(rawId).timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint('[VideoPlayer] Stream resolution timed out after 4s; fallback to $streamUrl');
              return streamUrl;
            },
          );
          if (resolved.isNotEmpty) {
            debugPrint('[VideoPlayer] Resolved direct stream URL: $resolved');
            streamUrl = resolved;
            _currentItem = _currentItem.copyWith(streamUrl: resolved);
          }
        } catch (e) {
          debugPrint('[VideoPlayer] Stream resolution exception: $e');
        }
      }
    }

    if (!mounted) return;

    if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
      debugPrint('[VideoPlayer] Empty or invalid streamUrl');
      setState(() {
        _hasError = true;
        _errorMessage = _isMovie
            ? 'No stream URL available for this film. Please try another title.'
            : 'No live broadcast stream URL is configured for this channel.';
      });
      return;
    }

    _controller?.dispose();
    debugPrint('[VideoPlayer] Initializing VideoPlayerController for $streamUrl');
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _controller = controller;

    try {
      await controller.initialize();
      debugPrint('[VideoPlayer] Controller initialized successfully!');
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
      controller.setPlaybackSpeed(_playbackSpeed);
      controller.setVolume(_isMuted ? 0.0 : _volumeLevel);
      controller.play();
      VideoPlaybackManager.instance.attachController(controller, _currentItem);
    } catch (error) {
      debugPrint('[VideoPlayer] Controller.initialize failed: $error');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = _isMovie
            ? 'Unable to buffer movie from archive server. Please check your network connection or try another title.'
            : 'Live broadcast feed is currently offline or unreachable. Please try another channel.';
      });
    }

    controller.addListener(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (controller.value.hasError && !_hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = controller.value.errorDescription ?? 'Playback error occurred';
          });
        } else {
          setState(() {});
        }
      });
    });
  }

  void _switchItem(MediaItem newItem, int newIndex) {
    if (_currentItem.id == newItem.id) return;
    setState(() {
      _currentItem = newItem;
      _currentIndex = newIndex;
      _isFavorite = newItem.isFavorite;
    });
    PersistentStorage.instance.upsertRecentHistory(newItem);
    _initializeVideo();
  }

  void _playNextItem() {
    if (_playlist.isEmpty) return;
    final nextIdx = (_currentIndex + 1) % _playlist.length;
    _switchItem(_playlist[nextIdx], nextIdx);
  }

  void _playPreviousItem() {
    if (_playlist.isEmpty) return;
    final prevIdx = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    _switchItem(_playlist[prevIdx], prevIdx);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _activeSleepTimer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (VideoPlaybackManager.instance.controller != _controller) {
      _controller?.dispose();
    }
    super.dispose();
  }

  void _resetControlsTimer() {
    _hideTimer?.cancel();
    if (_showControls && !_isInPipMode) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _controller?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _showControls = true;
      } else {
        ctrl.play();
        _resetControlsTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    final current = ctrl.value.position;
    final target = current + Duration(seconds: seconds);
    final duration = ctrl.value.duration;
    if (duration > Duration.zero) {
      if (target < Duration.zero) {
        ctrl.seekTo(Duration.zero);
      } else if (target > duration) {
        ctrl.seekTo(duration);
      } else {
        ctrl.seekTo(target);
      }
    } else {
      ctrl.seekTo(target);
    }
    _resetControlsTimer();
  }

  void _toggleMute() {
    final ctrl = _controller;
    setState(() {
      _isMuted = !_isMuted;
      ctrl?.setVolume(_isMuted ? 0.0 : _volumeLevel);
    });
    _resetControlsTimer();
  }

  Future<void> _enterPictureInPicture() async {
    try {
      final res = await _pipChannel.invokeMethod<bool>('enterPip');
      if (res == true) {
        setState(() {
          _isInPipMode = true;
          _showControls = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Picture-in-Picture window activated.'),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picture-in-Picture requires Android Oreo (API 26+).'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _cycleAspectRatio() {
    final values = VideoAspectRatioMode.values;
    final nextIndex = (values.indexOf(_aspectRatioMode) + 1) % values.length;
    setState(() {
      _aspectRatioMode = values[nextIndex];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aspect Ratio: ${_aspectRatioMode.label}'),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: AppColors.primary,
      ),
    );
    _resetControlsTimer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
    _resetControlsTimer();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Open Full Video More Sheet (Settings & Suboptions)
  void _openSettingsSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VideoMoreSheet(
        isMovie: _isMovie,
        item: _currentItem,
        playbackSpeed: _playbackSpeed,
        videoQuality: _videoQuality,
        aspectRatioMode: _aspectRatioMode,
        sleepTimerSetting: _sleepTimerSetting,
        volumeLevel: _volumeLevel,
        isMuted: _isMuted,
        selectedCaption: _selectedCaption,
        isFavorite: _isFavorite,
        onSpeedChanged: (speed) {
          setState(() {
            _playbackSpeed = speed;
            _controller?.setPlaybackSpeed(speed);
          });
        },
        onQualityChanged: (q) {
          setState(() => _videoQuality = q);
        },
        onAspectRatioChanged: (mode) {
          setState(() => _aspectRatioMode = mode);
        },
        onSleepTimerChanged: (s) {
          _setSleepTimer(s);
        },
        onVolumeChanged: (vol) {
          setState(() {
            _volumeLevel = vol;
            _isMuted = false;
            _controller?.setVolume(vol);
          });
        },
        onCaptionChanged: (cap) {
          setState(() => _selectedCaption = cap);
        },
        onToggleFavorite: () {
          setState(() => _isFavorite = !_isFavorite);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isFavorite ? 'Saved to Favorites' : 'Removed from Favorites'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppColors.primary,
            ),
          );
        },
        onEnterPip: _enterPictureInPicture,
      ),
    ).then((_) => _resetControlsTimer());
  }

  void _setSleepTimer(String setting) {
    _activeSleepTimer?.cancel();
    setState(() => _sleepTimerSetting = setting);

    int minutes = 0;
    if (setting == '15 minutes') minutes = 15;
    if (setting == '30 minutes') minutes = 30;
    if (setting == '45 minutes') minutes = 45;
    if (setting == '60 minutes') minutes = 60;

    if (minutes > 0) {
      _activeSleepTimer = Timer(Duration(minutes: minutes), () {
        if (mounted) {
          _controller?.pause();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sleep timer reached. Playback paused.')),
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sleep timer set for $minutes minutes.')),
      );
    }
  }

  // Open Channels Quick Switcher (for Live TV)
  void _openChannelSwitcher() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ChannelSwitcherSheet(
        channels: _liveChannels.isNotEmpty ? _liveChannels : _playlist,
        currentChannel: _currentItem,
        onSelectChannel: (channel) {
          Navigator.of(ctx).pop();
          final idx = _liveChannels.indexOf(channel);
          _switchItem(channel, idx != -1 ? idx : 0);
        },
      ),
    ).then((_) => _resetControlsTimer());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;
    final isPlaying = ctrl?.value.isPlaying ?? false;
    final isBuffering = ctrl?.value.isBuffering ?? false;

    // PiP Mode: Full screen video with zero overlay, tap to exit
    if (_isInPipMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _isInPipMode = false;
              _showControls = true;
            });
          },
          child: Center(
            child: (_isInitialized && ctrl != null)
                ? AspectRatio(
                    aspectRatio: ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : 16 / 9,
                    child: VideoPlayer(ctrl),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isFullscreen) {
          _toggleFullscreen();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _showControls = !_showControls);
            _resetControlsTimer();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Video Surface Layer
              Center(
                child: _hasError
                    ? _buildErrorView()
                    : (_isInitialized && ctrl != null)
                        ? _buildVideoSurface(ctrl)
                        : _buildLoadingView(),
              ),

              // 2. Restrained Buffering Indicator only when genuinely stalled per Buildathon Doc 20 §9.4
              if (isBuffering && !isPlaying && _isInitialized)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.logoGreen),
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),

              // 3. Ambient Vignette Gradient Scrim
              if (_showControls && !_hasError) ...[
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.22, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top Navigation & Action Header
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildTopHeader(),
                ),

                // Center Transport Controls (Only shown once video is initialized)
                if (_isInitialized)
                  Center(
                    child: _isMovie ? _buildMovieCenterControls(isPlaying) : _buildLiveTvCenterControls(isPlaying),
                  ),

                // Bottom Transport & Controls Bar
                if (_isInitialized)
                  Positioned(
                    bottom: 14,
                    left: 16,
                    right: 16,
                    child: _isMovie
                        ? _buildMovieBottomTransport(ctrl, position, duration)
                        : _buildLiveTvBottomTransport(ctrl),
                  ),
              ],

              // Top back button fallback if error is showing
              if (_hasError)
                Positioned(
                  top: 12,
                  left: 12,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildVideoSurface(VideoPlayerController ctrl) {
    final nativeRatio = ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : 16 / 9;

    switch (_aspectRatioMode) {
      case VideoAspectRatioMode.fill:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
        );
      case VideoAspectRatioMode.classic43:
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: VideoPlayer(ctrl),
        );
      case VideoAspectRatioMode.fit169:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayer(ctrl),
        );
      case VideoAspectRatioMode.original:
        return AspectRatio(
          aspectRatio: nativeRatio,
          child: VideoPlayer(ctrl),
        );
    }
  }

  // Top Action Header
  Widget _buildTopHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _currentItem.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLiveTv)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FEATURE FILM',
                        style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _isMovie
                    ? '${_currentItem.creator} • ${_currentItem.publishedDate ?? 'Cinema Archive'} • VOD'
                    : '${_currentItem.creator} • ${_currentItem.category} • IPTV Broadcast',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        // Aspect ratio quick cycle
        IconButton(
          tooltip: 'Aspect Ratio',
          icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
          onPressed: _cycleAspectRatio,
        ),

        // PiP Button
        IconButton(
          tooltip: 'Picture in Picture',
          icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
          onPressed: _enterPictureInPicture,
        ),

        // Settings / More Options
        IconButton(
          tooltip: 'Playback Settings',
          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          onPressed: _openSettingsSheet,
        ),

        // Fullscreen Toggle
        IconButton(
          tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
          icon: Icon(
            _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            color: Colors.white,
            size: 26,
          ),
          onPressed: _toggleFullscreen,
        ),
      ],
    );
  }

  // Center Controls for VOD Movies (-10s, Play/Pause, +10s)
  Widget _buildMovieCenterControls(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _seekRelative(-10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: () => _seekRelative(10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  // Center Controls for Live TV (Prev Channel, Play/Pause/Reconnect, Next Channel)
  Widget _buildLiveTvCenterControls(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _playPreviousItem,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isPlaying ? AppColors.primary : Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isPlaying ? AppColors.primary : Colors.redAccent).withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: _playNextItem,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  // Bottom Transport for Movies (Scrubber, Timestamps, Speed, Quality)
  Widget _buildMovieBottomTransport(
    VideoPlayerController? ctrl,
    Duration position,
    Duration duration,
  ) {
    final effectiveDuration = duration > Duration.zero
        ? duration
        : Duration(seconds: _currentItem.durationSeconds > 0 ? _currentItem.durationSeconds : 5400);

    final currentProgress = (position.inMilliseconds / (effectiveDuration.inMilliseconds > 0 ? effectiveDuration.inMilliseconds : 1))
        .clamp(0.0, 1.0);
    final sliderValue = _isDraggingScrubber ? _dragValue : currentProgress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Interactive Scrubber Bar
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: sliderValue.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            onChangeStart: (val) {
              setState(() {
                _isDraggingScrubber = true;
                _dragValue = val;
              });
              _hideTimer?.cancel();
            },
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              final targetMs = (val * effectiveDuration.inMilliseconds).toInt();
              ctrl?.seekTo(Duration(milliseconds: targetMs));
              setState(() {
                _isDraggingScrubber = false;
              });
              _resetControlsTimer();
            },
          ),
        ),

        // Timestamps & Quick Action Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(position)} / ${_formatDuration(effectiveDuration)}',
                style: AppTypography.monoMetric(color: Colors.white, fontSize: 12),
              ),

              Row(
                children: [
                  // Quick Speed Pill
                  GestureDetector(
                    onTap: () {
                      final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
                      final nextIdx = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
                      final newSpeed = speeds[nextIdx];
                      setState(() {
                        _playbackSpeed = newSpeed;
                        ctrl?.setPlaybackSpeed(newSpeed);
                      });
                      _resetControlsTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Mute / Unmute Button
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      _isMuted || _volumeLevel == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _toggleMute,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Bottom Transport for Live TV (Mute, Live Indicator, Channels Switcher)
  Widget _buildLiveTvBottomTransport(VideoPlayerController? ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Mute Button
          Row(
            children: [
              IconButton(
                iconSize: 22,
                icon: Icon(
                  _isMuted || _volumeLevel == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
                onPressed: _toggleMute,
              ),
              const SizedBox(width: 4),
              Text(
                _isMuted ? 'Muted' : 'Live Audio',
                style: AppTypography.bodySm(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),

          // Central Live Broadcast Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE BROADCAST',
                style: AppTypography.labelSm(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
            ],
          ),

          // Quick Channel Drawer Button
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _openChannelSwitcher,
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
            label: const Text('Channels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Cinematic poster artwork backdrop
        if (_currentItem.artworkUrl.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.22,
              child: Image.network(
                _currentItem.artworkUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

        // 2. Translucent dark luxury scrim
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.70),
          ),
        ),

        // 3. Professional sleek spinner + concise label per Buildathon Doc 20 §9.4
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.logoGreen),
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isMovie ? 'Buffering' : 'Connecting to broadcast',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isMovie ? Icons.movie_filter_rounded : Icons.tv_off_rounded,
              color: Colors.white70,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isMovie ? 'Movie Unavailable' : 'Live Stream Offline',
            style: AppTypography.headlineSm(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('Go Back', style: AppTypography.labelMd(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _initializeVideo,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Retry', style: AppTypography.labelMd(color: Colors.white)),
              ),
            ],
          ),
          if (_isLiveTv) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _openChannelSwitcher,
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
              label: const Text('Browse Live Channels', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Video More Sheet (Settings, Quality, Speed, PiP, Sleep Timer, Audio, Media Info)
class _VideoMoreSheet extends StatelessWidget {
  final bool isMovie;
  final MediaItem item;
  final double playbackSpeed;
  final String videoQuality;
  final VideoAspectRatioMode aspectRatioMode;
  final String sleepTimerSetting;
  final double volumeLevel;
  final bool isMuted;
  final String selectedCaption;
  final bool isFavorite;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<VideoAspectRatioMode> onAspectRatioChanged;
  final ValueChanged<String> onSleepTimerChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<String> onCaptionChanged;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEnterPip;

  const _VideoMoreSheet({
    required this.isMovie,
    required this.item,
    required this.playbackSpeed,
    required this.videoQuality,
    required this.aspectRatioMode,
    required this.sleepTimerSetting,
    required this.volumeLevel,
    required this.isMuted,
    required this.selectedCaption,
    required this.isFavorite,
    required this.onSpeedChanged,
    required this.onQualityChanged,
    required this.onAspectRatioChanged,
    required this.onSleepTimerChanged,
    required this.onVolumeChanged,
    required this.onCaptionChanged,
    required this.onToggleFavorite,
    required this.onEnterPip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Playback Settings', style: AppTypography.headlineSm(color: Colors.white, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          // 1. Playback Speed Row
          _buildOptionTile(
            icon: Icons.speed_rounded,
            title: 'Playback Speed',
            subtitle: '${playbackSpeed}x Normal',
            onTap: () {
              Navigator.of(context).pop();
              _showSuboptionDialog<double>(
                context: context,
                title: 'Playback Speed',
                currentValue: playbackSpeed,
                options: const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
                labelBuilder: (v) => v == 1.0 ? '1.0x (Normal)' : '${v}x',
                onSelected: onSpeedChanged,
              );
            },
          ),

          // 2. Stream Quality Row
          _buildOptionTile(
            icon: Icons.high_quality_rounded,
            title: 'Stream Quality',
            subtitle: videoQuality,
            onTap: () {
              Navigator.of(context).pop();
              _showSuboptionDialog<String>(
                context: context,
                title: 'Stream Quality',
                currentValue: videoQuality,
                options: const ['Fast Stream (SD / 480p)', 'Data Saver (360p)', 'High Quality (720p)', 'Auto HD (1080p)'],
                labelBuilder: (v) => v,
                onSelected: onQualityChanged,
              );
            },
          ),

          // 3. Aspect Ratio Row
          _buildOptionTile(
            icon: Icons.aspect_ratio_rounded,
            title: 'Aspect Ratio & Scaling',
            subtitle: aspectRatioMode.label,
            onTap: () {
              Navigator.of(context).pop();
              _showSuboptionDialog<VideoAspectRatioMode>(
                context: context,
                title: 'Aspect Ratio Mode',
                currentValue: aspectRatioMode,
                options: VideoAspectRatioMode.values,
                labelBuilder: (v) => v.label,
                onSelected: onAspectRatioChanged,
              );
            },
          ),

          // 4. Picture-in-Picture Row
          _buildOptionTile(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Picture in Picture (PiP)',
            subtitle: 'Continue watching in floating window',
            onTap: () {
              Navigator.of(context).pop();
              onEnterPip();
            },
          ),

          // 5. Sleep Timer Row
          _buildOptionTile(
            icon: Icons.timer_outlined,
            title: 'Sleep Timer',
            subtitle: sleepTimerSetting,
            onTap: () {
              Navigator.of(context).pop();
              _showSuboptionDialog<String>(
                context: context,
                title: 'Set Sleep Timer',
                currentValue: sleepTimerSetting,
                options: const ['Off', '15 minutes', '30 minutes', '45 minutes', '60 minutes'],
                labelBuilder: (v) => v,
                onSelected: onSleepTimerChanged,
              );
            },
          ),

          // 6. Subtitles & Captions Row
          _buildOptionTile(
            icon: Icons.subtitles_rounded,
            title: 'Captions & Subtitles',
            subtitle: selectedCaption,
            onTap: () {
              Navigator.of(context).pop();
              _showSuboptionDialog<String>(
                context: context,
                title: 'Subtitles',
                currentValue: selectedCaption,
                options: const ['Off', 'English [CC]', 'English (SDH)'],
                labelBuilder: (v) => v,
                onSelected: onCaptionChanged,
              );
            },
          ),

          const Divider(color: Colors.white12, height: 20),

          // Bottom Quick Actions (Favorite, Share, Media Info)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFavorite ? Colors.redAccent : Colors.white,
                label: isFavorite ? 'Favorited' : 'Favorite',
                onTap: onToggleFavorite,
              ),
              _buildActionButton(
                icon: Icons.share_rounded,
                color: Colors.white,
                label: 'Share',
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sharing: ${item.title}')),
                  );
                },
              ),
              _buildActionButton(
                icon: Icons.info_outline_rounded,
                color: Colors.white,
                label: 'Media Info',
                onTap: () {
                  Navigator.of(context).pop();
                  _showMediaInfoDialog(context, item, isMovie);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
      onTap: onTap,
    );
  }

  static Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  static void _showSuboptionDialog<T>({
    required BuildContext context,
    required String title,
    required T currentValue,
    required List<T> options,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2220),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headlineSm(color: Colors.white, fontSize: 17)),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    labelBuilder(opt),
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryContainer : Colors.white,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primaryContainer) : null,
                  onTap: () {
                    onSelected(opt);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  static void _showMediaInfoDialog(BuildContext context, MediaItem item, bool isMovie) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2220),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Stream Metadata', style: AppTypography.headlineSm(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaRow('Title', item.title),
            _buildMetaRow('Type', isMovie ? 'VOD / Feature Film' : 'IPTV Live Stream'),
            _buildMetaRow('Provider', isMovie ? 'Internet Archive' : 'IPTV Directory'),
            _buildMetaRow('Format', isMovie ? 'Direct MP4 Stream' : 'Live HLS Stream'),
            _buildMetaRow('Audio', 'Stereo / AAC 44.1 kHz'),
            _buildMetaRow('Identifier', item.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryContainer)),
          ),
        ],
      ),
    );
  }

  static Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Live TV Channel Switcher Sheet (Drawer)
class _ChannelSwitcherSheet extends StatelessWidget {
  final List<MediaItem> channels;
  final MediaItem currentChannel;
  final ValueChanged<MediaItem> onSelectChannel;

  const _ChannelSwitcherSheet({
    required this.channels,
    required this.currentChannel,
    required this.onSelectChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live TV Channels (${channels.length})', style: AppTypography.headlineSm(color: Colors.white, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: channels.length,
              separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final channel = channels[index];
                final isSelected = channel.id == currentChannel.id;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primaryContainer : Colors.white12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: channel.artworkUrl.isNotEmpty
                        ? Image.network(
                            channel.artworkUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, error, stackTrace) => const Icon(Icons.tv_rounded, color: Colors.white54, size: 22),
                          )
                        : const Icon(Icons.tv_rounded, color: Colors.white54, size: 22),
                  ),
                  title: Text(
                    channel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryContainer : Colors.white,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${channel.category} • Live Feed',
                    style: TextStyle(color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.7) : Colors.white54, fontSize: 12),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('WATCHING', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                        )
                      : const Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 22),
                  onTap: () => onSelectChannel(channel),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
