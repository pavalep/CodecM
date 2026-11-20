import '../../../../core/api/podcast_index_adapter.dart';
import '../../../player/domain/models/podcast.dart';
import '../../../player/domain/models/episode.dart';
import '../../../../core/storage/persistent_storage.dart';

class PodcastRepository {
  static final PodcastRepository _instance = PodcastRepository._internal();
  factory PodcastRepository() => _instance;
  PodcastRepository._internal();

  final PodcastIndexAdapter _adapter = PodcastIndexAdapter();

  List<Podcast> _cachedTrending = [];
  List<Episode> _cachedRecentEpisodes = [];

  // Curated Fallbacks from Buildathon Specs
  static final List<Podcast> seedCuratedPodcasts = [
    const Podcast(
      id: '67911',
      title: 'Acquired',
      subtitle: 'Ben Gilbert & David Rosenthal',
      hosts: 'Ben Gilbert & David Rosenthal',
      artworkUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
      description: 'Every company has a story. Acquired tells the whole story of the greatest companies in the world, and the playbooks behind their success.',
      rating: 4.9,
      reviewCount: '18.4K',
      episodeCount: 294,
      rankGlobal: 'Top 1% Global',
      categories: ['Technology', 'Business', 'Deep Dives'],
      isFollowing: true,
      onDeviceAffinity: 0.98,
    ),
    const Podcast(
      id: '1372519',
      title: 'Dwarkesh Podcast',
      subtitle: 'Dwarkesh Patel',
      hosts: 'Dwarkesh Patel',
      artworkUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80',
      description: 'Long-form deep dive interviews on artificial intelligence, computing history, economics, and synthetic biology.',
      rating: 4.9,
      reviewCount: '12.8K',
      episodeCount: 142,
      rankGlobal: 'Top 1% Global',
      categories: ['Science', 'AI & Computing', 'Philosophy'],
      isFollowing: true,
      onDeviceAffinity: 0.96,
    ),
    const Podcast(
      id: '248381',
      title: 'Lex Fridman Podcast',
      subtitle: 'Lex Fridman',
      hosts: 'Lex Fridman',
      artworkUrl: 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?w=600&auto=format&fit=crop&q=80',
      description: 'Conversations about science, tech, history, philosophy, and the intelligence of the human and machine mind.',
      rating: 4.8,
      reviewCount: '34.2K',
      episodeCount: 420,
      rankGlobal: 'Top 10 Global',
      categories: ['Science & Tech', 'Interviews', 'AI'],
      isFollowing: false,
      onDeviceAffinity: 0.94,
    ),
    const Podcast(
      id: '519283',
      title: 'Machine Minds',
      subtitle: 'Dr. Sarah Chen',
      hosts: 'Dr. Sarah Chen',
      artworkUrl: 'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?w=600&auto=format&fit=crop&q=80',
      description: 'Frontier machine learning architectures, attention mechanisms, reinforcement learning scaling, and transformer dynamics.',
      rating: 4.9,
      reviewCount: '8.4K',
      episodeCount: 68,
      rankGlobal: 'Top 5% Global',
      categories: ['Technology', 'Machine Learning', 'Engineering'],
      isFollowing: false,
      onDeviceAffinity: 0.97,
    ),
    const Podcast(
      id: '782910',
      title: 'Bio Frontier',
      subtitle: 'Dr. Elena Rostova',
      hosts: 'Dr. Elena Rostova',
      artworkUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=600&auto=format&fit=crop&q=80',
      description: 'The intersection of computational biology, CRISPR gene editing, and synthetic genomics.',
      rating: 4.7,
      reviewCount: '4.1K',
      episodeCount: 52,
      rankGlobal: 'Top 5% Global',
      categories: ['Science', 'Genomics', 'BioTech'],
      isFollowing: false,
      onDeviceAffinity: 0.92,
    ),
  ];

  static final List<Episode> seedCuratedEpisodes = [
    const Episode(
      id: 'ep-acquired-nvidia',
      title: 'NVIDIA: The Complete History & Modern Moats',
      showTitle: 'Acquired',
      host: 'Ben Gilbert & David Rosenthal',
      durationString: '3h 48m',
      totalDuration: Duration(hours: 3, minutes: 48),
      artworkUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
      description: 'CUDA parallel architecture, hardware compounding, graphics accelerator evolution, and how Jensen built a datacenter compute monopoly.',
      publishedDate: 'Nov 14, 2026',
      audioUrl: 'https://traffic.libsyn.com/acquired/acquired-nvidia-preview.mp3',
      semanticMatchScore: 0.985,
    ),
    const Episode(
      id: 'ep-dwarkesh-sholto',
      title: 'Sholto Douglas on RL & Frontier Models',
      showTitle: 'Dwarkesh Podcast',
      host: 'Dwarkesh Patel',
      durationString: '1h 12m',
      totalDuration: Duration(hours: 1, minutes: 12),
      artworkUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80',
      description: 'Deep dive into reinforcement learning scaling, test-time compute, reasoning models, and search algorithms.',
      publishedDate: 'Yesterday',
      audioUrl: 'https://traffic.libsyn.com/dwarkesh/dwarkesh-sholto.mp3',
      semanticMatchScore: 0.978,
    ),
    const Episode(
      id: 'ep-machine-minds',
      title: 'Latent Spaces & Attention Heads',
      showTitle: 'Machine Minds',
      host: 'Dr. Sarah Chen',
      durationString: '38m',
      totalDuration: Duration(minutes: 38),
      artworkUrl: 'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?w=600&auto=format&fit=crop&q=80',
      description: 'Mathematical breakdown of multi-head attention and transformer representations.',
      publishedDate: '3 days ago',
      audioUrl: 'https://traffic.libsyn.com/acquired/acquired-nvidia-preview.mp3',
      semanticMatchScore: 0.962,
    ),
    const Episode(
      id: 'ep-bio-crispr',
      title: 'The CRISPR Computation Wave',
      showTitle: 'Bio Frontier',
      host: 'Dr. Elena Rostova',
      durationString: '51m',
      totalDuration: Duration(minutes: 51),
      artworkUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=600&auto=format&fit=crop&q=80',
      description: 'How machine learning algorithms are accelerating synthetic biology and enzymatic engineering.',
      publishedDate: '5 days ago',
      audioUrl: 'https://traffic.libsyn.com/dwarkesh/dwarkesh-sholto.mp3',
      semanticMatchScore: 0.941,
    ),
  ];

  /// Fetch Trending Shows (Live API + Seed Fallback)
  Future<List<Podcast>> getTrendingPodcasts({String? categoryId}) async {
    final live = await _adapter.getTrendingPodcasts(max: 15, categoryId: categoryId);
    if (live.isNotEmpty) {
      _cachedTrending = live;
      return live;
    }
    if (_cachedTrending.isNotEmpty) {
      return _cachedTrending;
    }
    return seedCuratedPodcasts;
  }

  /// Search Podcasts by Term
  Future<List<Podcast>> searchPodcasts(String query) async {
    if (query.trim().isEmpty) return getTrendingPodcasts();
    final live = await _adapter.searchPodcasts(query, max: 20);
    if (live.isNotEmpty) return live;

    final lower = query.toLowerCase();
    return seedCuratedPodcasts
        .where((p) =>
            p.title.toLowerCase().contains(lower) ||
            p.hosts.toLowerCase().contains(lower) ||
            p.categories.any((c) => c.toLowerCase().contains(lower)))
        .toList();
  }

  /// Fetch Episodes for a Podcast Show
  Future<List<Episode>> getEpisodesForPodcast(Podcast podcast) async {
    final feedIdInt = int.tryParse(podcast.id);
    if (feedIdInt != null) {
      final liveEpisodes = await _adapter.getEpisodesByFeedId(feedIdInt, max: 25);
      if (liveEpisodes.isNotEmpty) {
        return liveEpisodes;
      }
    }

    // Curated episodes for known shows or generate representative episodes
    final matching = seedCuratedEpisodes.where((e) => e.showTitle == podcast.title).toList();
    if (matching.isNotEmpty) return matching;

    return [
      Episode(
        id: 'ep-${podcast.id}-1',
        title: '${podcast.title}: State of the Art & New Frontiers',
        showTitle: podcast.title,
        host: podcast.hosts,
        durationString: '48m',
        totalDuration: const Duration(minutes: 48),
        artworkUrl: podcast.artworkUrl,
        description: 'Comprehensive breakdown and expert analysis of key industry developments.',
        publishedDate: '2 days ago',
        audioUrl: 'https://traffic.libsyn.com/acquired/acquired-nvidia-preview.mp3',
        semanticMatchScore: 0.97,
      ),
      Episode(
        id: 'ep-${podcast.id}-2',
        title: '${podcast.title}: Foundation Systems and Scaling',
        showTitle: podcast.title,
        host: podcast.hosts,
        durationString: '1h 05m',
        totalDuration: const Duration(hours: 1, minutes: 5),
        artworkUrl: podcast.artworkUrl,
        description: 'A deep exploration into system architecture, design decisions, and tradeoffs.',
        publishedDate: '1 week ago',
        audioUrl: 'https://traffic.libsyn.com/dwarkesh/dwarkesh-sholto.mp3',
        semanticMatchScore: 0.94,
      ),
    ];
  }

  /// Fetch Recent Episodes
  Future<List<Episode>> getRecentEpisodes() async {
    final live = await _adapter.getRecentEpisodes(max: 12);
    if (live.isNotEmpty) {
      _cachedRecentEpisodes = live;
      return live;
    }
    if (_cachedRecentEpisodes.isNotEmpty) {
      return _cachedRecentEpisodes;
    }
    return seedCuratedEpisodes;
  }

  /// Follow Status Management (Persisted via PersistentStorage)
  bool isFollowing(String podcastId) => PersistentStorage.instance.isFollowingPodcast(podcastId);

  void toggleFollow(String podcastId) {
    // Find the podcast in cache or curated
    Podcast? found;
    try {
      found = _cachedTrending.firstWhere((p) => p.id == podcastId);
    } catch (_) {
      try {
        found = seedCuratedPodcasts.firstWhere((p) => p.id == podcastId);
      } catch (_) {}
    }
    if (found != null) {
      PersistentStorage.instance.toggleFollowPodcast(found);
    } else {
      // Toggle by id alone if we have an existing followed podcast
      final existing = PersistentStorage.instance.getFollowedPodcasts();
      final match = existing.where((p) => p.id == podcastId).firstOrNull;
      if (match != null) {
        PersistentStorage.instance.toggleFollowPodcast(match);
      }
    }
  }

  void toggleFollowPodcast(Podcast podcast) {
    PersistentStorage.instance.toggleFollowPodcast(podcast);
  }

  List<Podcast> getFollowedPodcasts() {
    return PersistentStorage.instance.getFollowedPodcasts();
  }
}
