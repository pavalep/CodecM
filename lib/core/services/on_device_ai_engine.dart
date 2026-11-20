import 'package:codecm/features/player/domain/models/episode.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';

class OnDeviceAiEngine {
  static final OnDeviceAiEngine _instance = OnDeviceAiEngine._internal();
  factory OnDeviceAiEngine() => _instance;
  OnDeviceAiEngine._internal();

  // Model Metadata
  final String modelName = 'EmbeddingGemma-2B-LiteRT-Q4';
  final int cachedVectorCount = 412;
  final double inferenceLatencyMs = 1.2;
  final String deviceExecution = 'GPU / NPU Acceleration (Zero Cloud AI)';

  // Static Seed Mock Podcasts
  static final Podcast acquiredPodcast = Podcast(
    id: 'show-acquired',
    title: 'Acquired',
    subtitle: 'The Complete Story of Great Companies',
    hosts: 'Ben Gilbert & David Rosenthal',
    artworkUrl:
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
    description:
        'Deep structural breakdowns of technology empires, competitive moats, and capital allocation. Synthesized natively on your device with zero cloud dependency.',
    rating: 4.9,
    reviewCount: '18.4K',
    episodeCount: 294,
    rankGlobal: 'Top 1% Global',
    categories: const ['Technology & Business', 'Venture Capital', 'Deep Dives'],
    isFollowing: true,
    onDeviceAffinity: 0.968,
    episodes: [
      Episode(
        id: 'ep-acq-294',
        title: 'NVIDIA: The Complete History & Modern Moats',
        showTitle: 'Acquired',
        host: 'Ben Gilbert & David Rosenthal',
        durationString: '3h 48m',
        totalDuration: const Duration(hours: 3, minutes: 48),
        artworkUrl:
            'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
        description:
            'From a Denny\'s booth to the cornerstone of the trillion-dollar intelligence age. Jensen Huang\'s compounding and CUDA ecosystem architecture.',
        semanticMatchScore: 0.984,
        publishedDate: 'Nov 14, 2026',
        isDownloaded: true,
        progress: 0.72,
        topicTags: const ['Blackwell', 'CUDA Ecosystem', 'Jensen Huang'],
      ),
      Episode(
        id: 'ep-acq-293',
        title: 'Microsoft: The Nadella Transformation',
        showTitle: 'Acquired',
        host: 'Ben Gilbert & David Rosenthal',
        durationString: '3h 12m',
        totalDuration: const Duration(hours: 3, minutes: 12),
        artworkUrl:
            'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80',
        description:
            'How Satya Nadella unwound the Ballmer legacy, bet on cloud computing, and engineered the OpenAI partnership.',
        semanticMatchScore: 0.942,
        publishedDate: 'Oct 28, 2026',
        isDownloaded: true,
        progress: 0.0,
        topicTags: const ['Satya Nadella', 'Cloud Azure', 'OpenAI'],
      ),
      Episode(
        id: 'ep-acq-292',
        title: 'TSMC: The Most Important Company in the World',
        showTitle: 'Acquired',
        host: 'Ben Gilbert & David Rosenthal',
        durationString: '4h 02m',
        totalDuration: const Duration(hours: 4, minutes: 2),
        artworkUrl:
            'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
        description:
            'Morris Chang and the pure-play foundry model that powers global silicon manufacturing.',
        semanticMatchScore: 0.915,
        publishedDate: 'Oct 10, 2026',
        isDownloaded: false,
        progress: 0.0,
        topicTags: const ['Silicon Foundry', 'Morris Chang', 'EUV Lithography'],
      ),
    ],
  );

  static final Episode defaultNowPlaying = Episode(
    id: 'ep-dwarkesh-sholto',
    title: 'Sholto Douglas on RL & Frontier Models',
    showTitle: 'Dwarkesh Podcast',
    host: 'Dwarkesh Patel',
    durationString: '1h 12m',
    totalDuration: const Duration(hours: 1, minutes: 12, seconds: 45),
    artworkUrl:
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&auto=format&fit=crop&q=80',
    description:
        'A technical deep dive on reinforcement learning, post-training paradigms, test-time compute, and the scaling laws of frontier reasoning models.',
    semanticMatchScore: 0.984,
    publishedDate: 'Yesterday',
    isDownloaded: true,
    progress: 0.334,
    topicTags: const ['Reinforcement Learning', 'Frontier AI', 'Compute Scaling'],
    chapters: const [
      EpisodeChapter(title: 'Introduction & Setup', startTime: Duration.zero, endTime: Duration(minutes: 4, seconds: 12)),
      EpisodeChapter(title: 'Pretraining vs Post-Training RL', startTime: Duration(minutes: 4, seconds: 12), endTime: Duration(minutes: 18, seconds: 30)),
      EpisodeChapter(title: 'Scaling Laws & Synthetic Data', startTime: Duration(minutes: 18, seconds: 30), endTime: Duration(minutes: 38, seconds: 15)),
      EpisodeChapter(title: 'Test-Time Compute Search', startTime: Duration(minutes: 38, seconds: 15), endTime: Duration(minutes: 54, seconds: 0)),
      EpisodeChapter(title: 'Hardware Bottlenecks & GPU Clusters', startTime: Duration(minutes: 54, seconds: 0), endTime: Duration(hours: 1, minutes: 12)),
    ],
  );

  static final List<Episode> seedQueue = [
    acquiredPodcast.episodes[0],
    Episode(
      id: 'ep-lex-412',
      title: 'Lex Fridman #412 — Sam Altman: OpenAI, GPT-5 & AGI',
      showTitle: 'Lex Fridman Podcast',
      host: 'Lex Fridman',
      durationString: '2h 08m',
      totalDuration: const Duration(hours: 2, minutes: 8),
      artworkUrl:
          'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=600&auto=format&fit=crop&q=80',
      description:
          'Sam Altman on the road to AGI, compute clusters, transformer architectures, and societal impact.',
      semanticMatchScore: 0.940,
      publishedDate: '3 days ago',
      isDownloaded: true,
      progress: 0.0,
      topicTags: const ['Sam Altman', 'AGI Roadmap', 'Compute'],
    ),
  ];

  static final Episode predictedSmartAutoplay = Episode(
    id: 'ep-machine-minds',
    title: 'Machine Minds — Latent Spaces & Attention Heads',
    showTitle: 'Machine Minds',
    host: 'Dr. Sarah Chen',
    durationString: '38m',
    totalDuration: const Duration(minutes: 38),
    artworkUrl:
        'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?w=600&auto=format&fit=crop&q=80',
    description:
        'Mathematical derivations of multi-head attention and transformer vector dynamics in neural spaces.',
    semanticMatchScore: 0.940,
    publishedDate: '1 week ago',
    isDownloaded: false,
    progress: 0.0,
    topicTags: const ['Attention Heads', 'Vector Spaces', 'Deep Learning'],
  );
}
