import 'package:flutter/material.dart';

/// Centralized iOS-like page transition for Parasto.
///
/// Push: slight slide from right + subtle fade
/// Pop: smooth reverse
///
/// Usage (drop-in replacement for MaterialPageRoute):
/// ```dart
/// Navigator.push(context, AppPageRoute(builder: (_) => DetailScreen()));
/// ```
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  AppPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: _buildTransition,
        );

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Push: slide from right (30% of width) + fade in
    final slideIn = Tween<Offset>(
      begin: const Offset(0.25, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Outgoing page slides slightly left and dims
    final slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.08, 0.0),
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    final fadeOut = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOut,
      ),
    );

    return SlideTransition(
      position: slideOut,
      child: FadeTransition(
        opacity: fadeOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Theme-level page transition that applies iOS-like transitions globally.
///
/// Add to ThemeData:
/// ```dart
/// pageTransitionsTheme: appPageTransitionsTheme,
/// ```
const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: _AppPageTransitionsBuilder(),
    TargetPlatform.android: _AppPageTransitionsBuilder(),
    TargetPlatform.macOS: _AppPageTransitionsBuilder(),
    TargetPlatform.windows: _AppPageTransitionsBuilder(),
    TargetPlatform.linux: _AppPageTransitionsBuilder(),
  },
);

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Don't animate the first route (initial page)
    if (route.isFirst) return child;

    return AppPageRoute._buildTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
