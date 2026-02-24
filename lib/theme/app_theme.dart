import 'package:flutter/material.dart';
import 'package:myna/utils/app_page_route.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PARASTO (پرستو) DESIGN SYSTEM
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Inspired by the Parasto app icon:
/// - Background: warm cream/beige with soft vignette
/// - Two barn swallows (پرستو) facing each other:
///   • Deep navy-blue wings and back
///   • Warm orange chest/throat
///   • Clean white belly
/// - Golden sound-wave in the middle
///
/// Design Philosophy:
/// - Warm, poetic, Persian, premium
/// - Never gloomy, not techy-neon, not "AI-ish"
/// - Comfortable for extended reading/listening sessions
/// ═══════════════════════════════════════════════════════════════════════════

class AppColors {
  // ══════════════════════════════════════════════════════════════════════════
  // CORE BRAND COLORS (derived from app icon)
  // ══════════════════════════════════════════════════════════════════════════

  /// Primary accent - warm amber-gold from the sound wave
  /// Use for: CTAs, active indicators, progress bars, prices, highlights
  static const Color primary = Color(0xFFF2B544);        // Sound Wave Gold
  static const Color primaryDark = Color(0xFFE5A020);    // Gold pressed/active
  static const Color primaryLight = Color(0xFFF6CB7A);   // Gold soft/hover
  static const Color primaryMuted = Color(0x33F2B544);   // Gold 20% for backgrounds

  /// Secondary accent - warm orange from swallow's chest
  /// Use for: secondary CTAs, tags, chapter badges, narrator highlights
  static const Color secondary = Color(0xFFE67634);      // Swallow Chest Orange
  static const Color secondaryLight = Color(0xFFEF8F4D); // Orange soft
  static const Color secondaryMuted = Color(0x33E67634); // Orange 20% for backgrounds

  /// Tertiary - deep navy from swallow's wings
  /// Use for: badges, special indicators, premium features
  static const Color navy = Color(0xFF1E3A5F);           // Swallow Wing Navy
  static const Color navyLight = Color(0xFF2A4A73);      // Navy lighter

  // ══════════════════════════════════════════════════════════════════════════
  // BACKGROUNDS & SURFACES (Dark Mode - Primary)
  // ══════════════════════════════════════════════════════════════════════════

  /// Primary background - rich warm navy (NOT black, NOT cold)
  /// Inspired by night sky but warmer
  static const Color background = Color(0xFF0F1825);     // Parasto Night

  /// Card/surface color - slightly lighter navy with warmth
  static const Color surface = Color(0xFF181F2C);        // Parasto Surface

  /// Elevated surfaces - dialogs, bottom sheets, player card
  static const Color surfaceLight = Color(0xFF202737);   // Parasto Elevated

  /// Extra elevated - for nested cards, overlays, popovers
  static const Color surfaceElevated = Color(0xFF2A3344); // Parasto Overlay

  /// Highest elevation - modals, important dialogs
  static const Color surfaceTop = Color(0xFF323B4F);     // Parasto Top

  // ══════════════════════════════════════════════════════════════════════════
  // BACKGROUNDS & SURFACES (Light Mode - Future)
  // ══════════════════════════════════════════════════════════════════════════

  /// Light mode - warm cream like icon background
  static const Color backgroundLight = Color(0xFFFAF7F2); // Parasto Cream
  static const Color surfaceLightMode = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceLightElevated = Color(0xFFF5F2ED); // Cream Elevated
  static const Color surfaceLightTop = Color(0xFFEDE8E1);  // Cream Top

  /// Light mode typography
  static const Color textPrimaryLight = Color(0xFF1A1A1A);     // Near black
  static const Color textSecondaryLight = Color(0xFF5A6275);   // Cool grey
  static const Color textTertiaryLight = Color(0xFF8B92A5);    // Stone grey
  static const Color textDisabledLight = Color(0xFFB8BCC8);    // Light disabled

  /// Light mode borders
  static const Color borderLight = Color(0xFFE5E2DC);          // Warm border
  static const Color borderSubtleLight = Color(0x14000000);    // 8% black

  /// Light mode shimmer
  static const Color shimmerBaseLight = Color(0xFFEDE8E1);     // Shimmer base
  static const Color shimmerHighlightLight = Color(0xFFF5F2ED);// Shimmer highlight

  // ══════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Primary text - warm off-white (not pure white, easier on eyes)
  static const Color textPrimary = Color(0xFFF9F5F0);    // Warm White

  /// Secondary text - muted blue-grey for descriptions, subtitles
  static const Color textSecondary = Color(0xFFB8BCC8);  // Muted Grey (improved)

  /// Tertiary text - labels, timestamps, meta info
  /// NOTE: Improved from 0xFF8B92A5 to 0xFF9EA5B8 for WCAG AA contrast compliance
  static const Color textTertiary = Color(0xFF9EA5B8);   // Stone Grey (WCAG compliant)

  /// Disabled text - clearly inactive but still readable
  static const Color textDisabled = Color(0xFF5A6275);   // Disabled Grey

  /// Text on primary color (gold button text)
  static const Color textOnPrimary = Color(0xFF1A1A1A);  // Near black for contrast

  /// Text on secondary color (orange button text)
  static const Color textOnSecondary = Color(0xFFFFFFFF); // White

  // ══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Success - fresh green (purchases, completed, saved)
  static const Color success = Color(0xFF4ADE80);        // Success Green
  static const Color successMuted = Color(0x334ADE80);   // Success background

  /// Warning - amber (close to primary family for harmony)
  static const Color warning = Color(0xFFFBBF24);        // Warning Amber
  static const Color warningMuted = Color(0x33FBBF24);   // Warning background

  /// Error - warm coral (not harsh red)
  static const Color error = Color(0xFFF97070);          // Error Coral
  static const Color errorMuted = Color(0x33F97070);     // Error background

  /// Info - cool blue for informational messages
  static const Color info = Color(0xFF60A5FA);           // Info Blue
  static const Color infoMuted = Color(0x3360A5FA);      // Info background

  // ══════════════════════════════════════════════════════════════════════════
  // BORDERS & DIVIDERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Standard borders and dividers
  static const Color border = Color(0xFF2A3344);         // Border Navy

  /// Subtle border (8% opacity of textPrimary)
  static const Color borderSubtle = Color(0x14F9F5F0);   // Border Subtle

  /// Focused border (for inputs)
  static const Color borderFocused = primary;            // Gold when focused

  // ══════════════════════════════════════════════════════════════════════════
  // ICON COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Muted icons (inactive state)
  static const Color iconMuted = Color(0xFF9EA5B8);      // Same as textTertiary (WCAG compliant)

  /// Active icons
  static const Color iconActive = primary;               // Gold when active

  // ══════════════════════════════════════════════════════════════════════════
  // SPECIAL PURPOSE COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Player gradient colors
  static const Color playerGradientStart = Color(0xFF1A2332);
  static const Color playerGradientEnd = Color(0xFF0F1825);

  /// Premium/Pro badge
  static const Color premium = Color(0xFFFFD700);        // Gold

  /// Free badge
  static const Color free = success;

  /// Locked content overlay
  static const Color locked = Color(0x99000000);         // 60% black

  /// Shimmer effect colors
  static const Color shimmerBase = Color(0xFF1E2530);
  static const Color shimmerHighlight = Color(0xFF2A3344);

  // ══════════════════════════════════════════════════════════════════════════
  // RATING COLORS (kept semantic for star ratings)
  // ══════════════════════════════════════════════════════════════════════════

  static const Color rating1 = Color(0xFFEF4444);        // 1 star - Red
  static const Color rating2 = Color(0xFFF97316);        // 2 stars - Orange
  static const Color rating3 = Color(0xFFFBBF24);        // 3 stars - Amber
  static const Color rating4 = Color(0xFF84CC16);        // 4 stars - Lime
  static const Color rating5 = Color(0xFF22C55E);        // 5 stars - Green
  static const Color ratingEmpty = Color(0xFF4B5563);    // Empty star
}

// ════════════════════════════════════════════════════════════════════════════
// TYPOGRAPHY SCALE
// ════════════════════════════════════════════════════════════════════════════

class AppTypography {
  /// Primary font - Abar (licensed Farsi font)
  static const String fontFamily = 'Abar';

  /// Fallback font - Vazirmatn (free open-source)
  static const String fontFamilyFallback = 'Vazirmatn';

  /// Font family fallback list for TextStyle.fontFamilyFallback
  static const List<String> fontFallbacks = ['Vazirmatn'];

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPLAY - Hero titles, splash screens
  // ═══════════════════════════════════════════════════════════════════════════

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADLINE - Page titles, section headers
  // ═══════════════════════════════════════════════════════════════════════════

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TITLE - Card titles, list item titles
  // ═══════════════════════════════════════════════════════════════════════════

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BODY - Regular content text
  // ═══════════════════════════════════════════════════════════════════════════

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LABEL - Buttons, chips, small UI elements
  // ═══════════════════════════════════════════════════════════════════════════

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textTertiary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIAL PURPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Price text (gold color)
  static const TextStyle price = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.primary,
  );

  /// Free badge text
  static const TextStyle freeBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.success,
  );

  /// Duration/time text
  static const TextStyle duration = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textTertiary,
  );

  /// Button text
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC STYLES (for specific UI contexts)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Section header title (home screen sections like "پیشنهاد شده")
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// Card title (audiobook cards, list items)
  /// Note: 15px for clear readability on Persian text
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Card subtitle (author, narrator names)
  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Chip/tag text
  static const TextStyle chip = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Meta info (timestamps, chapter counts, durations)
  static const TextStyle meta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  /// Small badge text (free, price badges)
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// App bar title
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Hero title (large prominent titles)
  static const TextStyle heroTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Banner title overlay
  static const TextStyle bannerTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: Colors.white,
    shadows: [
      Shadow(
        color: Colors.black54,
        blurRadius: 8,
      ),
    ],
  );

  /// Banner subtitle overlay
  static const TextStyle bannerSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: Colors.white,
  );

  /// Form field label
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Form helper/hint text
  static const TextStyle fieldHint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  /// Error message text
  static const TextStyle errorText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.error,
  );

  /// Success message text
  static const TextStyle successText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.success,
  );

  /// Empty state message
  static const TextStyle emptyState = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Progress percentage text
  static const TextStyle progressText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.primary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // MICRO STYLES (very small text for badges, counters, timestamps)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Micro text - smallest readable size (11px)
  /// Use for: tiny badges, status indicators, counters
  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textTertiary,
  );

  /// Micro badge - for colored status badges
  static const TextStyle microBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYER-SPECIFIC STYLES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Player title - audiobook title on player screen
  static const TextStyle playerTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Player chapter title
  static const TextStyle playerChapter = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Player time display (current/total time)
  static const TextStyle playerTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textTertiary,
  );

  /// Speed badge text
  static const TextStyle speedBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.primary,
  );

  /// Sheet title (bottom sheets, dialogs)
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Chapter list item title
  static const TextStyle chapterTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Chapter list item - current/selected state
  static const TextStyle chapterTitleCurrent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.primary,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SPACING & SIZING CONSTANTS
// ════════════════════════════════════════════════════════════════════════════

class AppSpacing {
  // Base unit: 4px
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Section spacing
  static const double sectionPaddingHorizontal = 16;
  static const double sectionPaddingVertical = 20;
  static const double sectionGap = 24;

  // Card spacing
  static const double cardPadding = 16;
  static const double cardGap = 12;

  // List spacing
  static const double listItemGap = 8;
  static const double listPadding = 16;
}

// ════════════════════════════════════════════════════════════════════════════
// BORDER RADIUS
// ════════════════════════════════════════════════════════════════════════════

class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;

  // Preset BorderRadius objects
  static final BorderRadius small = BorderRadius.circular(sm);
  static final BorderRadius medium = BorderRadius.circular(md);
  static final BorderRadius large = BorderRadius.circular(lg);
  static final BorderRadius extraLarge = BorderRadius.circular(xl);
  static final BorderRadius pill = BorderRadius.circular(full);
}

// ════════════════════════════════════════════════════════════════════════════
// SHADOWS
// ════════════════════════════════════════════════════════════════════════════

class AppShadows {
  static List<BoxShadow> get small => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppOpacity.light),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppOpacity.medium),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get large => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: AppOpacity.overlay),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

// ════════════════════════════════════════════════════════════════════════════
// ANIMATION DURATIONS (standardized motion timing)
// ════════════════════════════════════════════════════════════════════════════

class AppDurations {
  /// Instant feedback (tap scale, press states)
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions (state indicators, chip selection, tab switching)
  static const Duration normal = Duration(milliseconds: 250);

  /// Complex transitions (page enter/exit, expand/collapse, skeleton→content)
  static const Duration slow = Duration(milliseconds: 350);

  /// Auto-scroll, carousel timers
  static const Duration carousel = Duration(milliseconds: 400);
}

// ════════════════════════════════════════════════════════════════════════════
// ANIMATION CURVES (semantic naming for consistent motion feel)
// ════════════════════════════════════════════════════════════════════════════

class AppCurves {
  /// Standard ease for most state changes
  static const Curve standard = Curves.easeInOut;

  /// Decelerate into rest — page transitions, expand/collapse
  static const Curve decelerate = Curves.easeOutCubic;

  /// Snappy for small, quick interactions (chip toggle, indicator move)
  static const Curve snappy = Curves.easeOut;
}

// ════════════════════════════════════════════════════════════════════════════
// DIMENSIONS (Common sizes for cards, images, etc.)
// ════════════════════════════════════════════════════════════════════════════

class AppDimensions {
  // ══════════════════════════════════════════════════════════════════════════
  // ACCESSIBILITY - WCAG Touch Targets
  // ══════════════════════════════════════════════════════════════════════════

  /// Minimum touch target size per WCAG 2.5.5 (44x44px)
  static const double minTouchTarget = 44.0;

  /// Recommended touch target for important actions
  static const double touchTargetLarge = 48.0;

  // ══════════════════════════════════════════════════════════════════════════
  // ICON SIZES (paired with text)
  // ══════════════════════════════════════════════════════════════════════════

  /// Icon size when paired with small text (badges, meta info) - 12px text
  static const double iconWithSmallText = 12.0;

  /// Icon size when paired with body text (list items) - 14px text
  static const double iconWithBodyText = 16.0;

  /// Icon size when paired with title text (headers, buttons) - 16-18px text
  static const double iconWithTitleText = 20.0;

  /// Icon size when paired with headline text (section headers) - 20px text
  static const double iconWithHeadline = 22.0;

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  /// Standard horizontal padding for sections
  static const double sectionPaddingH = 16.0;

  /// Top spacing before section headers
  static const double sectionSpacingTop = 24.0;

  /// Bottom spacing after section headers
  static const double sectionSpacingBottom = 12.0;

  // Card dimensions — aspect ratios by content type:
  //   Books (audiobook + ebook): 2:3 portrait
  //   Music, podcasts, articles: 1:1 square
  static const double cardWidth = 160.0;
  static const double cardWidthSmall = 120.0;
  static const double cardWidthLarge = 180.0;
  static const double cardCoverHeight = 240.0; // 160×240 = 2:3 ratio (books)
  static const double cardCoverHeightSmall = 180.0; // 120×180 = 2:3 ratio
  static const double musicCardCoverHeight = 160.0; // 1:1 square (music, podcasts, articles)

  /// Carousel container height for 2:3 book cards (cover 240 + spacing + text + badge)
  static const double carouselHeightBook = 340.0;

  /// Carousel container height for 1:1 square cards (cover 160 + spacing + text + badge)
  static const double carouselHeightSquare = 260.0;

  // Grid layout
  static const double gridAspectRatio = 0.58; // Accounts for 2:3 cover + text area
  static const double gridSpacing = 12.0;

  // Thumbnail dimensions (2:3 aspect ratio)
  static const double thumbnailWidth = 70.0;
  static const double thumbnailHeight = 105.0; // 70×105 = 2:3 ratio
  static const double thumbnailWidthSmall = 50.0;
  static const double thumbnailHeightSmall = 75.0; // 50×75 = 2:3 ratio

  // Avatar sizes
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 48.0;
  static const double avatarLarge = 80.0;
  static const double avatarXLarge = 100.0;

  // Icon sizes (standalone)
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Button heights
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 52.0;

  // Player dimensions
  static const double playerCoverSize = 280.0;
  static const double miniPlayerHeight = 72.0;

  // Banner dimensions
  static const double bannerHeight = 180.0;
  static const double bannerHeightSmall = 140.0;
}

// ════════════════════════════════════════════════════════════════════════════
// CARD VARIANTS (Consistent card styling across the app)
// ════════════════════════════════════════════════════════════════════════════

class CardVariant {
  /// Standard card - solid surface background with subtle shadow
  /// Use for: audiobook cards, list items, basic content containers
  static BoxDecoration get standard => BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.medium,
    boxShadow: AppShadows.small,
  );

  /// Elevated card - surface with more prominent shadow
  /// Use for: important cards, featured items, dialogs
  static BoxDecoration get elevated => BoxDecoration(
    color: AppColors.surfaceLight,
    borderRadius: AppRadius.large,
    boxShadow: AppShadows.medium,
  );

  /// Featured card - gradient background with accent border
  /// Use for: continue listening, highlighted content, hero sections
  static BoxDecoration get featured => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.primary.withValues(alpha: AppOpacity.light),
        AppColors.surface,
      ],
    ),
    borderRadius: AppRadius.large,
    border: Border.all(
      color: AppColors.primary.withValues(alpha: AppOpacity.medium),
      width: 1,
    ),
  );

  /// Outlined card - transparent with border
  /// Use for: selectable items, form sections, grouped content
  static BoxDecoration get outlined => BoxDecoration(
    color: Colors.transparent,
    borderRadius: AppRadius.medium,
    border: Border.all(
      color: AppColors.border,
      width: 1,
    ),
  );

  /// Interactive card - for items that respond to tap
  /// Use for: tappable cards that need visual feedback
  static BoxDecoration get interactive => BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.medium,
    border: Border.all(
      color: AppColors.border,
      width: 1,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// OPACITY VALUES (Standard opacity levels)
// ════════════════════════════════════════════════════════════════════════════

class AppOpacity {
  /// Fully disabled state
  static const double disabled = 0.38;

  /// Semi-transparent (button hover, light overlays)
  static const double hover = 0.08;

  /// Slightly more visible (pressed states)
  static const double pressed = 0.12;

  /// Subtle backgrounds and overlays
  static const double veryLight = 0.1;

  /// Light backgrounds (badges, chips)
  static const double light = 0.15;

  /// Medium opacity (selected states)
  static const double medium = 0.2;

  /// Dark overlays (modals, dialogs backdrop)
  static const double overlay = 0.3;

  /// Heavy overlay (image gradients)
  static const double overlayHeavy = 0.5;

  /// Scrim (modal backgrounds)
  static const double scrim = 0.6;
}

// ════════════════════════════════════════════════════════════════════════════
// THEME DATA
// ════════════════════════════════════════════════════════════════════════════

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      canvasColor: AppColors.surface,

      // ════════════════════════════════════════════════════════════════════════
      // PAGE TRANSITIONS (iOS-like slide+fade for all routes)
      // ════════════════════════════════════════════════════════════════════════
      pageTransitionsTheme: appPageTransitionsTheme,

      // ════════════════════════════════════════════════════════════════════════
      // APP BAR
      // ════════════════════════════════════════════════════════════════════════
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.headlineSmall,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // CARD
      // ════════════════════════════════════════════════════════════════════════
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
        ),
        margin: EdgeInsets.zero,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // ELEVATED BUTTON (Primary CTA)
      // ════════════════════════════════════════════════════════════════════════
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.surfaceLight,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // OUTLINED BUTTON (Secondary CTA)
      // ════════════════════════════════════════════════════════════════════════
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // TEXT BUTTON (Tertiary action)
      // ════════════════════════════════════════════════════════════════════════
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(44, 44),
          textStyle: AppTypography.button,
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // INPUT DECORATION (Text fields)
      // ════════════════════════════════════════════════════════════════════════
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.small,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTypography.bodyMedium,
        errorStyle: AppTypography.labelSmall.copyWith(color: AppColors.error),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // BOTTOM NAVIGATION
      // ════════════════════════════════════════════════════════════════════════
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // TAB BAR
      // ════════════════════════════════════════════════════════════════════════
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelMedium,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // SNACKBAR
      // ════════════════════════════════════════════════════════════════════════
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // DIALOG
      // ════════════════════════════════════════════════════════════════════════
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.large,
        ),
        titleTextStyle: AppTypography.headlineSmall,
        contentTextStyle: AppTypography.bodyMedium,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // BOTTOM SHEET
      // ════════════════════════════════════════════════════════════════════════
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: AppColors.border,
        dragHandleSize: Size(40, 4),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // CHIP
      // ════════════════════════════════════════════════════════════════════════
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryMuted,
        disabledColor: AppColors.surfaceLight,
        labelStyle: AppTypography.labelMedium,
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // PROGRESS INDICATOR
      // ════════════════════════════════════════════════════════════════════════
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // SLIDER
      // ════════════════════════════════════════════════════════════════════════
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: AppOpacity.medium),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // SWITCH
      // ════════════════════════════════════════════════════════════════════════
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: AppOpacity.overlayHeavy);
          }
          return AppColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // CHECKBOX
      // ════════════════════════════════════════════════════════════════════════
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
        side: const BorderSide(color: AppColors.border, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // RADIO
      // ════════════════════════════════════════════════════════════════════════
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textTertiary;
        }),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // DIVIDER
      // ════════════════════════════════════════════════════════════════════════
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // LIST TILE
      // ════════════════════════════════════════════════════════════════════════
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.primaryMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
        ),
        titleTextStyle: AppTypography.titleMedium,
        subtitleTextStyle: AppTypography.bodySmall,
        leadingAndTrailingTextStyle: AppTypography.labelMedium,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // ICON
      // ════════════════════════════════════════════════════════════════════════
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // FAB
      // ════════════════════════════════════════════════════════════════════════
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.large,
        ),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // POPUP MENU
      // ════════════════════════════════════════════════════════════════════════
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.small,
        ),
        textStyle: AppTypography.bodyMedium,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // TOOLTIP
      // ════════════════════════════════════════════════════════════════════════
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.small,
        ),
        textStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ════════════════════════════════════════════════════════════════════════
      // COLOR SCHEME
      // ════════════════════════════════════════════════════════════════════════
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryMuted,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textOnSecondary,
        secondaryContainer: AppColors.secondaryMuted,
        onSecondaryContainer: AppColors.secondary,
        tertiary: AppColors.navy,
        onTertiary: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textPrimary,
        errorContainer: AppColors.errorMuted,
        onErrorContainer: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceElevated,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSubtle,
        shadow: Colors.black,
        scrim: Colors.black54,
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.background,
        inversePrimary: AppColors.primaryDark,
        brightness: Brightness.dark,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // TEXT THEME
      // ════════════════════════════════════════════════════════════════════════
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // Uses the same structural layout as darkTheme with light-mode colors.
  // Brand accent (gold) stays identical for consistency.
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    return darkTheme.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      canvasColor: AppColors.surfaceLightMode,

      appBarTheme: darkTheme.appBarTheme.copyWith(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      ),

      cardTheme: darkTheme.cardTheme.copyWith(
        color: AppColors.surfaceLightMode,
      ),

      dialogTheme: darkTheme.dialogTheme.copyWith(
        backgroundColor: AppColors.surfaceLightMode,
      ),

      bottomSheetTheme: darkTheme.bottomSheetTheme.copyWith(
        backgroundColor: AppColors.surfaceLightMode,
      ),

      bottomNavigationBarTheme: darkTheme.bottomNavigationBarTheme.copyWith(
        backgroundColor: AppColors.surfaceLightMode,
      ),

      dividerTheme: darkTheme.dividerTheme.copyWith(
        color: AppColors.borderLight,
      ),

      popupMenuTheme: darkTheme.popupMenuTheme.copyWith(
        color: AppColors.surfaceLightElevated,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceLightTop,
          borderRadius: AppRadius.small,
        ),
        textStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.textPrimaryLight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryMuted,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textOnSecondary,
        secondaryContainer: AppColors.secondaryMuted,
        onSecondaryContainer: AppColors.secondary,
        tertiary: AppColors.navy,
        onTertiary: AppColors.textPrimaryLight,
        error: AppColors.error,
        onError: AppColors.textOnSecondary,
        errorContainer: AppColors.errorMuted,
        onErrorContainer: AppColors.error,
        surface: AppColors.surfaceLightMode,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.surfaceLightElevated,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderSubtleLight,
        shadow: Colors.black,
        scrim: Colors.black54,
        inverseSurface: AppColors.textPrimaryLight,
        onInverseSurface: AppColors.backgroundLight,
        inversePrimary: AppColors.primaryLight,
        brightness: Brightness.light,
      ),

      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.textPrimaryLight),
        displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.textPrimaryLight),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.textPrimaryLight),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimaryLight),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimaryLight),
        titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryLight),
        titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.textPrimaryLight),
        titleSmall: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimaryLight),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight),
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.textPrimaryLight),
        labelMedium: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryLight),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryLight),
      ),
    );
  }
}
