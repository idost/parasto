import 'dart:ui';

/// Parasto Reader Themes - Low-contrast by design (Apple Books philosophy)
/// These colors are optimized for long Persian (RTL) reading sessions
/// Avoid pure white text — causes eye fatigue in dark readers

// Theme 1: Original - Default Parasto theme (warm navy, matching app design)
const cOriginalBg = Color(0xFF0F1825);    // Parasto Night - warm navy (was 0xFF171717)
const cOriginalText = Color(0xFFB8BCC8);  // Parasto textSecondary for comfortable reading

// Theme 2: Quiet - Darkest, minimal eye strain
const cQuietBg = Color(0xFF0A0A0A);
const cQuietText = Color(0xFF8D8D8E);  // Readable light grey for very dark bg

// Theme 3: Paper - Subtle warm grey
const cPaperBg = Color(0xFF2C2B2D);
const cPaperText = Color(0xFFACACAE);  // Readable light grey for medium dark bg

// Theme 4: Bold - High contrast dark
const cBoldBg = Color(0xFF111111);
const cBoldText = Color(0xFFB7B7B7);  // Readable light grey for dark bg

// Theme 5: Calm - Warm brown tones (best for long RTL reading)
const cCalmBg = Color(0xFF4B443A);
const cCalmText = Color(0xFFD4CDC2);  // Warm light beige for brown bg

// Theme 6: Focus - Deep warm olive (best for long RTL reading)
const cFocusBg = Color(0xFF28251C);
const cFocusText = Color(0xFFB1AD94);  // Warm light olive for olive bg

/// Parasto Design System colors for EPUB reader UI components
/// Aligned with lib/theme/app_theme.dart
const cParastoBackground = Color(0xFF0F1825);   // AppColors.background
const cParastoSurface = Color(0xFF181F2C);      // AppColors.surface
const cParastoSurfaceLight = Color(0xFF202737); // AppColors.surfaceLight
const cParastoSurfaceElevated = Color(0xFF2A3344); // AppColors.surfaceElevated
const cParastoTextPrimary = cOriginalText;
const cParastoTextSecondary = Color(0xFFB8BCC8);
const cParastoPrimary = Color(0xFFF2B544);      // Sound Wave Gold (accent)
const cParastoBorder = Color(0xFF2A3344);

/// Parasto Title Accent Colors
/// Used for chapter numbers, titles, section headers
/// NOT applied to body text
const cParastoTitleAccent = Color(0xFF2FB7A3);     // Primary title accent (teal)
const cParastoTitleAccentSoft = Color(0xFF239685); // Softer variant for subtle emphasis

/// Legacy colors (mapped to new themes for backward compatibility)
const cVioletishColor = cCalmBg;
const cBluishColor = cPaperBg;
const cPinkishColor = cFocusBg;
