import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:codecm/core/theme/app_colors.dart';
import 'package:codecm/features/home/presentation/pages/home_page.dart';
import 'package:codecm/features/discover/presentation/pages/discover_page.dart';
import 'package:codecm/features/profile/presentation/pages/profile_page.dart';
import 'package:codecm/features/player/presentation/widgets/mini_player_widget.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _isBottomBarVisible = true;

  // Exactly 3 Core Navigation Tabs: Home, Explore, Profile
  // Library, Saved / Bookmarks, History & Settings are centralized inside Profile & Home
  final List<Widget> _pages = const [
    HomePage(),
    DiscoverPage(),
    ProfilePage(),
  ];

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      // User is scrolling down -> hide bottom bar for full screen view
      if (_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = false);
      }
    } else if (notification.direction == ScrollDirection.forward ||
        notification.direction == ScrollDirection.idle) {
      // User is scrolling up or stopped scrolling -> reveal bottom bar
      if (!_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onUserScroll,
        child: Stack(
          children: [
            // 1. Screen Body with IndexedStack to retain tab state
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),

            // 2. Persistent Floating MiniPlayer docked cleanly above bottom nav
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: AnimatedSlide(
                offset: _isBottomBarVisible ? Offset.zero : const Offset(0, 1.8),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: const MiniPlayerWidget(),
              ),
            ),
          ],
        ),
      ),

      // 3. Crisp, Minimal 3-Item Bottom Navigation Bar (Animated slide on scroll)
      bottomNavigationBar: AnimatedSlide(
        offset: _isBottomBarVisible ? Offset.zero : const Offset(0, 1.2),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.8),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                  _buildNavItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
                  _buildNavItem(2, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
