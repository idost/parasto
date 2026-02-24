const String libTheme = "lib_theme";
const String libFont = "lib_font";
const String libFontSize = "lib_font_settings";
const String libLineSpacing = "lib_line_spacing";
const String libPageTurnAnimation = "lib_page_turn_animation";

/// Page turn animation styles (Apple Books-inspired)
enum PageTurnStyle {
  slide,  // Modern default - smooth horizontal slide
  curl,   // Classic skeuomorphic page flip
  none,   // Instant - no animation
}

/// Animation durations for page turns
class PageTurnDurations {
  static const Duration slide = Duration(milliseconds: 300);
  static const Duration curl = Duration(milliseconds: 450);
  static const Duration none = Duration.zero;

  static Duration forStyle(PageTurnStyle style) {
    switch (style) {
      case PageTurnStyle.slide:
        return slide;
      case PageTurnStyle.curl:
        return curl;
      case PageTurnStyle.none:
        return none;
    }
  }
}