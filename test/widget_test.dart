import 'package:flutter_test/flutter_test.dart';
import 'package:codecm/features/player/domain/models/episode.dart';
import 'package:codecm/features/player/presentation/bloc/player_bloc.dart';
import 'package:codecm/features/player/presentation/bloc/player_event.dart';
import 'package:codecm/features/player/presentation/bloc/player_state.dart';
import 'package:codecm/core/services/on_device_ai_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerBloc & OnDeviceAiEngine (Gemma 2B LiteRT) Tests', () {
    late PlayerBloc playerBloc;

    const sampleLiveEpisode = Episode(
      id: 'ep-live-101',
      title: 'Frontier Neural Architectures & On-Device LiteRT',
      showTitle: 'Open AI Edge Feed',
      host: 'CodecM Live Stream',
      durationString: '42m',
      totalDuration: Duration(minutes: 42),
      artworkUrl: 'https://archive.org/services/img/feature_films',
      description: 'Deep technical discussion on 4-bit quantized Gemma 2B models running on mobile NPUs.',
      publishedDate: 'Today',
    );

    setUp(() {
      playerBloc = PlayerBloc(enableNativeAudio: false);
    });

    tearDown(() {
      playerBloc.close();
    });

    test('initial state starts clean with empty episode and PlaybackStatus.initial', () {
      expect(playerBloc.state.status, equals(PlaybackStatus.initial));
      expect(playerBloc.state.isPlaying, isFalse);
      expect(playerBloc.state.currentEpisode, equals(Episode.empty));
      expect(playerBloc.state.speed, equals(1.0));
      expect(playerBloc.state.isSmartAutoplayEnabled, isTrue);
    });

    test('PlayEpisode scores semantic affinity and transitions to playing', () async {
      final expectation = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) =>
            state.isPlaying &&
            state.currentEpisode.id == sampleLiveEpisode.id &&
            state.currentEpisode.semanticMatchScore >= 0.68)),
      );
      playerBloc.add(const PlayEpisode(sampleLiveEpisode));
      await expectation;
    });

    test('TogglePlayPause toggles playback state between playing and paused', () async {
      playerBloc.add(const PlayEpisode(sampleLiveEpisode));
      await expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.isPlaying == true)),
      );

      playerBloc.add(TogglePlayPause());
      await expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.isPlaying == false)),
      );
    });

    test('ChangePlaybackSpeed updates speed to 1.5x', () async {
      final expectation = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.speed == 1.5)),
      );
      playerBloc.add(const ChangePlaybackSpeed(1.5));
      await expectation;
    });

    test('AddToQueue enqueues episode, ClearQueue flushes it, and StopPlayback resets player', () async {
      final expectationAdd = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.queue.contains(sampleLiveEpisode))),
      );
      playerBloc.add(const AddToQueue(sampleLiveEpisode));
      await expectationAdd;

      final expectationClear = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.queue.isEmpty)),
      );
      playerBloc.add(ClearQueue());
      await expectationClear;

      final expectationStop = expectLater(
        playerBloc.stream,
        emits(predicate<PlayerState>((state) => state.status == PlaybackStatus.stopped)),
      );
      playerBloc.add(StopPlayback());
      await expectationStop;
    });

    test('OnDeviceAiEngine computes normalized 256-D embeddings and cosine similarity', () {
      final ai = OnDeviceAiEngine.instance;
      final vecA = ai.computeLocalEmbedding('Gemma 2B LiteRT neural network artificial intelligence');
      final vecB = ai.computeLocalEmbedding('Artificial intelligence neural model on-device inference');
      final vecC = ai.computeLocalEmbedding('Classic silent comedy film festival');

      expect(vecA.length, equals(256));
      final simRelated = ai.computeLocalCosineSimilarity(vecA, vecB);
      final simUnrelated = ai.computeLocalCosineSimilarity(vecA, vecC);
      expect(simRelated, greaterThan(simUnrelated));
    });
  });
}
