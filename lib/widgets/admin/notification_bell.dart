import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/notification_providers.dart';
import 'package:myna/widgets/admin/notification_panel.dart';

/// Notification bell icon with unread badge
class NotificationBell extends ConsumerWidget {
  final bool showPanel;

  const NotificationBell({
    super.key,
    this.showPanel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          color: AppColors.textSecondary,
          onPressed: () {
            if (showPanel) {
              _showNotificationPanel(context, ref);
            } else {
              Navigator.of(context).pushNamed('/admin/engage/notifications');
            }
          },
          tooltip: 'اعلان‌ها',
        ),
        // Badge
        unreadCount.when(
          data: (count) {
            if (count == 0) return const SizedBox.shrink();
            return Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showNotificationPanel(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationPanel(),
    );
  }
}

/// Animated notification bell with shake effect for new notifications
class AnimatedNotificationBell extends ConsumerStatefulWidget {
  const AnimatedNotificationBell({super.key});

  @override
  ConsumerState<AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState
    extends ConsumerState<AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _shake() {
    _controller.forward().then((_) => _controller.reverse());
  }

  @override
  Widget build(BuildContext context) {
    // Listen for new notifications and shake
    ref.listen(realtimeNotificationProvider, (previous, next) {
      next.whenData((_) => _shake());
    });

    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          child: child,
        );
      },
      child: Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            color: AppColors.textSecondary,
            onPressed: () => _showNotificationPanel(context),
            tooltip: 'اعلان‌ها',
          ),
          // Badge
          unreadCount.when(
            data: (count) {
              if (count == 0) return const SizedBox.shrink();
              return Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showNotificationPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationPanel(),
    );
  }
}
