import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/narrator/narrator_dashboard_screen.dart';
import 'package:myna/screens/narrator/narrator_audiobooks_screen.dart';
import 'package:myna/screens/narrator/narrator_upload_screen.dart';
import 'package:myna/screens/narrator/narrator_profile_screen.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/widgets/mini_player.dart';

/// Provider to control narrator shell navigation from child screens
final narratorShellIndexProvider = StateProvider<int>((ref) => 0);

class NarratorMainShell extends ConsumerStatefulWidget {
  const NarratorMainShell({super.key});

  @override
  ConsumerState<NarratorMainShell> createState() => _NarratorMainShellState();
}

class _NarratorMainShellState extends ConsumerState<NarratorMainShell> {
  static const int _tabCount = 4;

  // Lazy loading: only build screens that have been visited
  final Set<int> _visitedScreens = {0};

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const NarratorDashboardScreen();
      case 1:
        return const NarratorAudiobooksScreen();
      case 2:
        return const NarratorUploadScreen();
      case 3:
        return const NarratorProfileScreen();
      default:
        return const NarratorDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only watch hasAudio — avoids rebuilds on position/duration ticks
    final hasAudio = ref.watch(audioProvider.select((s) => s.hasAudio));
    final currentIndex = ref.watch(narratorShellIndexProvider);

    // Mark current tab as visited for lazy loading
    _visitedScreens.add(currentIndex);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Main content — only build visited screens (lazy)
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: [
                  for (int i = 0; i < _tabCount; i++)
                    if (_visitedScreens.contains(i))
                      _buildScreen(i)
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
            // Mini player at bottom (if audio is playing)
            if (hasAudio) const MiniPlayer(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(narratorShellIndexProvider.notifier).state = index;
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'داشبورد',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined),
              activeIcon: Icon(Icons.library_books),
              label: 'کتاب‌ها',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'آپلود',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'پروفایل',
            ),
          ],
        ),
      ),
    );
  }
}
