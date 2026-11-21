import 'package:flutter/material.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/core/theme/app_typography.dart';
import 'package:codecm/core/storage/persistent_storage.dart';
import 'package:codecm/features/auth/presentation/pages/login_page.dart';
import 'package:codecm/features/library/presentation/pages/library_page.dart';
import 'package:codecm/features/saved/presentation/pages/saved_page.dart';
import 'package:codecm/features/ai_dj/presentation/pages/ai_dj_page.dart';
import 'package:codecm/features/media/domain/models/media_item.dart';
import 'package:codecm/features/player/domain/models/podcast.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggedIn = false;
  String _audioQuality = 'Lossless (320 kbps)';
  String _videoQuality = 'Auto HD (1080p)';
  bool _wifiOnly = true;
  String _cacheSize = '14.2 MB';

  void _clearCache() {
    setState(() {
      _cacheSize = '0.0 MB';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Media cache cleared successfully (0 MB)'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (result == true && mounted) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Profile & Library',
                style: AppTypography.displayEditorial(fontSize: 24),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your library, subscriptions, offline downloads, and streaming preferences.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),

              const SizedBox(height: 18),

              // 1. Account Status Card (Default: Guest Mode with Login button)
              _buildAccountCard(),

              const SizedBox(height: 22),

              // 2. My Content & Library Section (Replaces bottom tabs with direct navigation)
              Text(
                'My Content & Library',
                style: AppTypography.headlineSm(fontSize: 17),
              ),
              const SizedBox(height: 10),
              _buildLibraryHub(),

              const SizedBox(height: 22),

              // 3. Streaming & Playback Preferences
              Text(
                'Streaming & Playback',
                style: AppTypography.headlineSm(fontSize: 17),
              ),
              const SizedBox(height: 10),
              _buildPreferencesSection(),

              const SizedBox(height: 22),

              // 4. Open-Source Media Catalogs
              Text(
                'Catalogs & Engine',
                style: AppTypography.headlineSm(fontSize: 17),
              ),
              const SizedBox(height: 10),
              _buildCatalogsSection(),

              const SizedBox(height: 24),

              // App Version footer
              Center(
                child: Text(
                  'CodecM v1.0.0 • Open Media Engine',
                  style: AppTypography.labelSm(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    if (_isLoggedIn) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Paval', style: AppTypography.titleMd(fontSize: 16)),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'pavalep@gmail.com',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Connected via Google Sign-In',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isLoggedIn = false),
                  child: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontSize: 13)),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account library synchronized')),
                    );
                  },
                  child: const Text('Sync Library', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default Guest State: Clean, minimal, actionable
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Guest Listener', style: AppTypography.titleMd(fontSize: 15)),
                    const SizedBox(height: 2),
                    const Text(
                      'Sign in to sync your bookmarks, subscriptions, and playback across devices.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _navigateToLogin,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In or Register', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryHub() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
          // 1. Followed Podcasts & Subscriptions
          ValueListenableBuilder<List<Podcast>>(
            valueListenable: PersistentStorage.instance.followedPodcastsNotifier,
            builder: (context, followedList, _) {
              return _buildHubTile(
                icon: Icons.rss_feed_rounded,
                iconBg: AppColors.primaryContainer,
                iconColor: AppColors.primary,
                title: 'Subscribed Podcasts',
                subtitle: '${followedList.length} shows followed',
                badgeCount: followedList.length,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LibraryPage()),
                  );
                },
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),

          // 2. Saved Bookmarks
          ValueListenableBuilder<List<MediaItem>>(
            valueListenable: PersistentStorage.instance.bookmarksNotifier,
            builder: (context, bookmarks, _) {
              return _buildHubTile(
                icon: Icons.favorite_outline_rounded,
                iconBg: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFEF4444),
                title: 'Saved Bookmarks',
                subtitle: '${bookmarks.length} items saved (max 20)',
                badgeCount: bookmarks.length,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedPage(initialSegment: 0)),
                  );
                },
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),

          // 3. Playback History
          ValueListenableBuilder<List<MediaItem>>(
            valueListenable: PersistentStorage.instance.recentHistoryNotifier,
            builder: (context, history, _) {
              return _buildHubTile(
                icon: Icons.history_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: 'Playback History',
                subtitle: '${history.length} recently played (max 10)',
                badgeCount: history.length,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedPage(initialSegment: 1)),
                  );
                },
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),

          // 4. Gemma 2B LiteRT AI DJ Studio
          _buildHubTile(
            icon: Icons.auto_awesome_rounded,
            iconBg: const Color(0xFFE0E7FF),
            iconColor: const Color(0xFF4F46E5),
            title: 'Gemma 2B LiteRT AI DJ Studio',
            subtitle: 'On-device 256-D neural audio blend & cosine ranking',
            badgeCount: 0,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiDjPage()),
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
          // Audio Quality
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 20),
            ),
            title: const Text('Audio Stream Quality', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_audioQuality, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
              onSelected: (val) => setState(() => _audioQuality = val),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Lossless (320 kbps)', child: Text('Lossless (320 kbps)')),
                PopupMenuItem(value: 'High Quality (256 kbps)', child: Text('High Quality (256 kbps)')),
                PopupMenuItem(value: 'Standard (128 kbps)', child: Text('Standard (128 kbps)')),
              ],
            ),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),

          // Video Quality
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hd_rounded, color: AppColors.primary, size: 20),
            ),
            title: const Text('Video Quality', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_videoQuality, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
              onSelected: (val) => setState(() => _videoQuality = val),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Auto HD (1080p)', child: Text('Auto HD (1080p)')),
                PopupMenuItem(value: 'Standard HD (720p)', child: Text('Standard HD (720p)')),
                PopupMenuItem(value: 'Data Saver (480p)', child: Text('Data Saver (480p)')),
              ],
            ),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),

          // Wi-Fi Only Toggle
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            activeThumbColor: AppColors.primary,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi_rounded, color: AppColors.primary, size: 20),
            ),
            title: const Text('Stream Over Wi-Fi Only', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Prevent cellular data consumption', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            value: _wifiOnly,
            onChanged: (val) => setState(() => _wifiOnly = val),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),

          // Clear Cache
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 20),
            ),
            title: const Text('Local Media Cache', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('$_cacheSize cached on device', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              onPressed: _clearCache,
              child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCatalogsSection() {
    final catalogs = [
      {'name': 'Internet Archive', 'desc': 'Public domain movies & feature cinema', 'icon': Icons.movie_outlined},
      {'name': 'PodcastIndex', 'desc': 'Global open RSS podcast directory', 'icon': Icons.podcasts_rounded},
      {'name': 'TVMaze API', 'desc': 'Television schedule & series broadcast data', 'icon': Icons.tv_rounded},
      {'name': 'Jamendo Music', 'desc': 'Creative Commons independent artists', 'icon': Icons.music_note_rounded},
      {'name': 'Radio Browser', 'desc': 'Community live radio stations worldwide', 'icon': Icons.radio_rounded},
      {'name': 'LibriVox Audiobooks', 'desc': 'Public domain spoken audiobooks', 'icon': Icons.auto_stories_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: catalogs.asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            return Column(
              children: [
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Icon(cat['icon'] as IconData, size: 20, color: AppColors.primary),
                  title: Text(cat['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(cat['desc'] as String, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                ),
                if (idx < catalogs.length - 1)
                  const Divider(height: 1, indent: 48, color: AppColors.border),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
