import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myna/theme/app_theme.dart';

/// Premium splash screen for Parasto.
///
/// Design: Centered, elegant.
/// Uses Vazirmatn Bold for clean Persian typography.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _lineWidth;
  late Animation<double> _quoteOpacity;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    // Match status bar with background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Single controller for all animations (4 seconds)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // Logo text fades in and scales elegantly (0-20%)
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOutCubic),
      ),
    );

    // Line expands (15-40%)
    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.40, curve: Curves.easeOutCubic),
      ),
    );

    // Quote fades in (30-50%)
    _quoteOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.50, curve: Curves.easeOut),
      ),
    );

    // Everything fades out (85-100%)
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeOut.value,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App name - scales in elegantly (no icon)
                      Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: const Text(
                          'پرستو',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.4,
                          ),
                        ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Elegant thin gold line
                      Container(
                        width: 80 * _lineWidth.value,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Quote - Vazirmatn, off-white
                      Opacity(
                        opacity: _quoteOpacity.value,
                        child: Text(
                          'آدمی فربه شود از راهِ گوش',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary.withValues(alpha: 0.9),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Attribution - Vazirmatn, subtle
                      Opacity(
                        opacity: _quoteOpacity.value,
                        child: const Text(
                          'مولوی',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
