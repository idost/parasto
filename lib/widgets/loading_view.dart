import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Reusable loading view widget for consistent loading states across the app.
class LoadingView extends StatelessWidget {
  final String? message;
  final bool overlay;
  final double size;

  const LoadingView({
    super.key,
    this.message,
    this.overlay = false,
    this.size = 40,
  });

  /// Factory for a simple centered spinner
  factory LoadingView.simple() {
    return const LoadingView();
  }

  /// Factory for loading with a message
  factory LoadingView.withMessage(String message) {
    return LoadingView(message: message);
  }

  /// Factory for overlay loading (semi-transparent background)
  factory LoadingView.overlay({String? message}) {
    return LoadingView(overlay: true, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: overlay ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (overlay) {
      return ColoredBox(
        color: AppColors.background.withValues(alpha: 0.8),
        child: content,
      );
    }

    return content;
  }
}

/// A shimmer/skeleton loading placeholder for content
class LoadingPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingPlaceholder({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<LoadingPlaceholder> createState() => _LoadingPlaceholderState();
}

class _LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Book card skeleton for loading states
class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingPlaceholder(height: 160, borderRadius: 8),
          SizedBox(height: 8),
          LoadingPlaceholder(height: 16, width: 100),
          SizedBox(height: 4),
          LoadingPlaceholder(height: 12, width: 60),
        ],
      ),
    );
  }
}

/// List item skeleton for loading states
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          LoadingPlaceholder(width: 60, height: 80, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingPlaceholder(height: 16),
                SizedBox(height: 8),
                LoadingPlaceholder(height: 12, width: 100),
                SizedBox(height: 12),
                LoadingPlaceholder(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
