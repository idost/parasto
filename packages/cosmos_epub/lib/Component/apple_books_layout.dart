import 'dart:math';
import 'package:flutter/widgets.dart';

/// Apple Books-style layout constants and calculations
///
/// Design philosophy: Anchored, book-like, calm
/// - Text feels grounded, not floating
/// - Lines never feel wide or dense
/// - RTL Persian layout with balanced breathing room
class AppleBooksLayout {
  // ============================================================================
  // READING CANVAS
  // ============================================================================

  /// Maximum content width for optimal readability
  /// Narrower than typical to create book-like line lengths
  /// 480px on phones (narrower for better Persian reading), 560px on tablets
  static double maxContentWidth(double screenWidth) {
    return screenWidth > 600 ? 560 : 480;
  }

  /// Dynamic side padding based on screen width
  /// RTL Persian needs generous right-side breathing room
  /// Formula: max(24, screenWidth * 0.065) - slightly more generous
  static double sidePadding(double screenWidth) {
    return max(24.0, screenWidth * 0.065);
  }

  /// Dynamic top padding - ensures text clears the close button area
  /// Provides enough space for the 44px close button + safe area
  static double topPadding(double screenHeight) {
    return max(20.0, screenHeight * 0.03);
  }

  /// Dynamic bottom padding - generous for thumb zone + menu button clearance
  /// Ensures text never appears under the menu button (44px + margins + buffer)
  /// Formula: max(70, screenHeight * 0.08) + safeAreaBottom
  static double bottomPadding(double screenHeight, double safeAreaBottom) {
    return max(70.0, screenHeight * 0.08) + safeAreaBottom;
  }

  // ============================================================================
  // HEADER & FOOTER (thin, bookmark-like)
  // ============================================================================

  /// Header height - thin, like a bookmark not a toolbar
  /// 40px content + safe area (reduced from 44)
  static double headerHeight(double safeAreaTop) {
    return 40 + safeAreaTop;
  }

  /// Footer height - thin status whisper
  /// 36px content + safe area (reduced from 44)
  static double footerHeight(double safeAreaBottom) {
    return 36 + safeAreaBottom;
  }

  /// Calculate the reading viewport height
  static double readingViewportHeight({
    required double screenHeight,
    required double safeAreaTop,
    required double safeAreaBottom,
    required bool overlayVisible,
  }) {
    if (overlayVisible) {
      final header = headerHeight(safeAreaTop);
      final footer = footerHeight(safeAreaBottom);
      return screenHeight - header - footer;
    } else {
      return screenHeight - safeAreaTop - safeAreaBottom;
    }
  }

  // ============================================================================
  // MENU BUTTON (invisible until needed)
  // ============================================================================

  /// Menu button position from bottom - raised to avoid thumb zone
  static double menuButtonBottom(double safeAreaBottom) {
    return safeAreaBottom + 16;
  }

  /// Menu button position from right side
  static const double menuButtonRight = 16.0;

  /// Menu button size - exactly Apple minimum tap target
  static const double menuButtonSize = 44.0;

  /// Menu icon color - bright but not white (softer than E5E5EA)
  static const int menuIconColorValue = 0xFFD1D1D6;

  /// Menu button background opacity - very subtle
  static const double menuButtonBackgroundOpacity = 0.25;

  /// Menu button border opacity - barely visible
  static const double menuButtonBorderOpacity = 0.08;

  // ============================================================================
  // ANIMATIONS (short, eased, non-bouncy)
  // ============================================================================

  /// Overlay show/hide animation - one step slower
  static const Duration overlayAnimationDuration = Duration(milliseconds: 200);

  /// Animation curve - smooth ease, no bounce
  static const Curve animationCurve = Curves.easeOutCubic;

  // ============================================================================
  // TYPOGRAPHY
  // ============================================================================

  /// Default line height for Persian text (scholarly calm)
  static const double persianLineHeight = 1.88;

  /// Title font weight - only slightly heavier, not dramatic
  static const FontWeight titleFontWeight = FontWeight.w500;

  // ============================================================================
  // OVERLAY CONTROLS
  // ============================================================================

  /// Close button opacity - subtle, not demanding
  static const double closeButtonIconOpacity = 0.45;

  /// Title text opacity in header - readable but never loud
  static const double headerTitleOpacity = 0.35;

  /// Page indicator text opacity - status whisper
  static const double pageIndicatorOpacity = 0.4;

  /// Divider opacity - barely visible
  static const double dividerOpacity = 0.06;
}
