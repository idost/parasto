import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/widgets/mini_player.dart';
import 'package:myna/screens/listener/home_screen.dart';
import 'package:myna/screens/listener/library_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/screens/listener/profile_screen.dart';

/// Main shell for listener role with bottom navigation.
/// Tabs (RTL order — rightmost first visually):
///   0: خانه      (Home)
///   1: کتابخانه   (Library — my owned content)
///   2: کاوش      (Browse / Discover + Search)
///   3: پروفایل   (Profile & Settings)
///
/// ARCHITECTURE:
/// - IndexedStack preserves tab state (scroll position, etc.)
/// - Lazy loading: screens only built when first visited
/// - Mini-player docked between content and bottom nav (Phase 1.2)
/// - PopScope handles Android back: pop inner stack → Home tab → exit
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  // Track which screens have been visited (for lazy building)
  final Set<int> _visitedScreens = {0}; // Home is always visited first

  static const int _tabCount = 4;
  static const int _homeIndex = 0;

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const LibraryScreen();
      case 2:
        return const SearchScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  /// Android back button logic:
  /// 1. If the current screen's Navigator can pop (e.g., detail pushed within tab) → pop it
  /// 2. If at root of a non-Home tab → switch to Home tab
  /// 3. If already on Home at root → let the system handle (exit app)
  Future<bool> _handleBackButton() async {
    // Try to pop the innermost navigator (detail screens within a tab)
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return false; // Consumed — don't exit
    }

    // At root of a non-Home tab → switch to Home
    if (_currentIndex != _homeIndex) {
      setState(() => _currentIndex = _homeIndex);
      return false; // Consumed — don't exit
    }

    // At Home root → exit app
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldExit = await _handleBackButton();
          if (shouldExit && context.mounted) {
            SystemNavigator.pop(); // Exit app cleanly
          }
        },
        child: Scaffold(
          body: Column(
            children: [
              // Main content — only build visited screens (lazy)
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    for (int i = 0; i < _tabCount; i++)
                      if (_visitedScreens.contains(i))
                        _buildScreen(i)
                      else
                        const SizedBox.shrink(),
                  ],
                ),
              ),
              // Mini player docked above the nav bar — smooth show/hide
              AnimatedSize(
                duration: AppDurations.normal,
                curve: AppCurves.decelerate,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: audio.hasAudio
                    ? const MiniPlayer()
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'خانه'),
                    _buildNavItem(1, Icons.library_books_outlined, Icons.library_books_rounded, 'کتابخانه'),
                    _buildNavItem(2, Icons.explore_outlined, Icons.explore_rounded, 'کاوش'),
                    _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'پروفایل'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _visitedScreens.add(index);
        _currentIndex = index;
      }),
      child: SizedBox(
        // Ensure minimum 48px touch target
        width: 64,
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
