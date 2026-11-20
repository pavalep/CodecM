import 'package:flutter_test/flutter_test.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/player/presentation/bloc/player_state.dart';
import 'package:codecm/core/services/on_device_ai_engine.dart';

void main() {
  group('PlayerBloc Clean Architecture State Management Tests', () {
    late PlayerBloc playerBloc;

    setUp(() {
      playerBloc = PlayerBloc(enableNativeAudio: false);
    });

    tearDown(() {
      playerBloc.close();
    });

    test('initial state has default Acquired episode and is playing', () {
      expect(playerBloc.state.isPlaying, isTrue);
      expect(playerBloc.state.currentEpisode.title, contains('NVIDIA'));
      expect(playerBloc.state.speed, equals(1.2));
      expect(playerBloc.state.isSmartAutoplayEnabled, isTrue);
    });

    test('TogglePlayPause toggles playback state to paused', () async {
      expect(playerBloc.state.isPlaying, isTrue);

      final expectation = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.isPlaying == false)),
      );
      playerBloc.add(TogglePlayPause());
      await expectation;
    });

    test('ChangePlaybackSpeed updates speed to 1.5x', () async {
      final expectation = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.speed == 1.5)),
      );
      playerBloc.add(const ChangePlaybackSpeed(1.5));
      await expectation;
    });

    test('AddToQueue enqueues episode and ClearQueue flushes it', () async {
      final ep = OnDeviceAiEngine.predictedSmartAutoplay;
      final expectationAdd = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.queue.contains(ep))),
      );
      playerBloc.add(AddToQueue(ep));
      await expectationAdd;

      final expectationClear = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.queue.isEmpty)),
      );
      playerBloc.add(ClearQueue());
      await expectationClear;
    });
  });
}
