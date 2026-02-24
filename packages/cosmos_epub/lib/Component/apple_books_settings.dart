import 'package:flutter/material.dart';

import 'constants.dart';
import 'theme_colors.dart';

/// Apple Books EXACT settings sheet implementation
/// Pixel-perfect match to iOS Apple Books app
class AppleBooksSettingsSheet extends StatefulWidget {
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final String selectedFont;
  final List<String> fontNames;
  final double fontSize;
  final double lineSpacing;
  final int selectedThemeId;
  final PageTurnStyle pageTurnStyle;
  final double brightness;
  final VoidCallback onUpdate;
  final Function(String) onFontChanged;
  final Function(double) onFontSizeChanged;
  final Function(double) onLineSpacingChanged;
  final Function(int) onThemeChanged;
  final Function(PageTurnStyle) onPageTurnChanged;
  final Function(double) onBrightnessChanged;

  const AppleBooksSettingsSheet({
    super.key,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.selectedFont,
    required this.fontNames,
    required this.fontSize,
    required this.lineSpacing,
    required this.selectedThemeId,
    required this.pageTurnStyle,
    required this.brightness,
    required this.onUpdate,
    required this.onFontChanged,
    required this.onFontSizeChanged,
    required this.onLineSpacingChanged,
    required this.onThemeChanged,
    required this.onPageTurnChanged,
    required this.onBrightnessChanged,
  });

  @override
  State<AppleBooksSettingsSheet> createState() => _AppleBooksSettingsSheetState();
}

class _AppleBooksSettingsSheetState extends State<AppleBooksSettingsSheet> {
  late double _fontSize;
  late double _brightness;
  late int _selectedThemeId;
  late PageTurnStyle _pageTurnStyle;
  late String _selectedFont;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _brightness = widget.brightness;
    _selectedThemeId = widget.selectedThemeId;
    _pageTurnStyle = widget.pageTurnStyle;
    _selectedFont = widget.selectedFont;
  }

  // Theme data - exact Apple Books themes
  static const List<_ThemeData> _themes = [
    _ThemeData(1, 'اصلی', cOriginalBg, cOriginalText, false),      // Original (dark)
    _ThemeData(2, 'ساکت', cQuietBg, cQuietText, false),            // Quiet (darkest)
    _ThemeData(3, 'کاغذ', cPaperBg, cPaperText, true),             // Paper (light warm)
    _ThemeData(4, 'پررنگ', cBoldBg, cBoldText, false),             // Bold (high contrast)
    _ThemeData(5, 'آرام', cCalmBg, cCalmText, true),               // Calm (sepia)
    _ThemeData(6, 'متمرکز', cFocusBg, cFocusText, false),          // Focus (olive)
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = widget.backgroundColor.computeLuminance() < 0.5;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cParastoSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== DRAG HANDLE =====
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          const SizedBox(height: 16),

          // ===== TITLE =====
          Text(
            'پوسته و تنظیمات',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
              fontFamily: _selectedFont,
              package: 'cosmos_epub',
            ),
          ),

          const SizedBox(height: 24),

          // ===== FONT SIZE ROW (A slider A) =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Small A button
                _buildFontSizeButton(
                  isLarge: false,
                  isDark: isDark,
                  onTap: () {
                    if (_fontSize > 14) {
                      setState(() => _fontSize = (_fontSize - 1).clamp(14.0, 32.0));
                      widget.onFontSizeChanged(_fontSize);
                    }
                  },
                ),
                const SizedBox(width: 12),
                // Slider
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                      activeTrackColor: widget.accentColor,
                      inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      thumbColor: Colors.white,
                      overlayColor: widget.accentColor.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 14,
                      max: 32,
                      onChanged: (v) => setState(() => _fontSize = v),
                      onChangeEnd: (v) => widget.onFontSizeChanged(v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Large A button
                _buildFontSizeButton(
                  isLarge: true,
                  isDark: isDark,
                  onTap: () {
                    if (_fontSize < 32) {
                      setState(() => _fontSize = (_fontSize + 1).clamp(14.0, 32.0));
                      widget.onFontSizeChanged(_fontSize);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== PAGE TURN STYLE ROW =====
          // Note: Using Directionality.override to keep LTR order for icons
          // (Bolt=Slide on left, Book=Curl in middle, Arrows=None on right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? cParastoSurfaceLight : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // Slide: Lightning bolt (fast horizontal slide)
                    _buildPageTurnSegment(
                      style: PageTurnStyle.slide,
                      icon: Icons.bolt_rounded,
                      isDark: isDark,
                    ),
                    // Curl: Open book (classic page flip)
                    _buildPageTurnSegment(
                      style: PageTurnStyle.curl,
                      icon: Icons.menu_book_rounded,
                      isDark: isDark,
                    ),
                    // None: Swap arrows (instant transition)
                    _buildPageTurnSegment(
                      style: PageTurnStyle.none,
                      icon: Icons.sync_alt_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ===== THEMES GRID (3x2) - Apple Books exact layout =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _themes.length,
              itemBuilder: (context, index) {
                final theme = _themes[index];
                final isSelected = _selectedThemeId == theme.id;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedThemeId = theme.id);
                    widget.onThemeChanged(theme.id);
                  },
                  child: Column(
                    children: [
                      // Theme card with Aa
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: theme.bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? widget.accentColor
                                  : (theme.isLight ? Colors.grey[300]! : Colors.grey[700]!),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: widget.accentColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: theme.textColor,
                                fontFamily: _selectedFont,
                                package: 'cosmos_epub',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Theme name
                      Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? widget.accentColor
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontFamily: _selectedFont,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ===== BRIGHTNESS ROW =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Sun min icon
                Icon(
                  Icons.brightness_low_rounded,
                  size: 24,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                // Slider
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                      activeTrackColor: widget.accentColor,
                      inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      thumbColor: Colors.white,
                      overlayColor: widget.accentColor.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _brightness,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (v) {
                        setState(() => _brightness = v);
                        widget.onBrightnessChanged(v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sun max icon
                Icon(
                  Icons.brightness_high_rounded,
                  size: 24,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== FONT SELECTOR ROW =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => _showFontPicker(context, isDark),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? cParastoSurfaceLight : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // Checkmark icon
                    Icon(
                      Icons.text_fields_rounded,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    // Font name
                    Expanded(
                      child: Text(
                        _selectedFont,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                          fontFamily: _selectedFont,
                          package: 'cosmos_epub',
                        ),
                      ),
                    ),
                    // Label
                    Text(
                      'قلم',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontFamily: _selectedFont,
                        package: 'cosmos_epub',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: bottomPadding + 20),
        ],
      ),
    );
  }

  /// Build font size button (A small or A large)
  Widget _buildFontSizeButton({
    required bool isLarge,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? cParastoSurfaceLight : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'آ',
            style: TextStyle(
              fontSize: isLarge ? 24 : 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
              fontFamily: _selectedFont,
              package: 'cosmos_epub',
            ),
          ),
        ),
      ),
    );
  }

  /// Build page turn segment button
  Widget _buildPageTurnSegment({
    required PageTurnStyle style,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _pageTurnStyle == style;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _pageTurnStyle = style);
          widget.onPageTurnChanged(style);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.accentColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  /// Show font picker bottom sheet
  void _showFontPicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? cParastoSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'انتخاب قلم',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                  fontFamily: _selectedFont,
                  package: 'cosmos_epub',
                ),
              ),
              const SizedBox(height: 16),
              // Font list
              Expanded(
                child: ListView.builder(
                  itemCount: widget.fontNames.length,
                  itemBuilder: (context, index) {
                    final font = widget.fontNames[index];
                    final isSelected = _selectedFont == font;
                    return ListTile(
                      onTap: () {
                        setState(() => _selectedFont = font);
                        widget.onFontChanged(font);
                        Navigator.pop(context);
                      },
                      leading: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: widget.accentColor,
                              size: 22,
                            )
                          : const SizedBox(width: 22),
                      title: Text(
                        font,
                        style: TextStyle(
                          fontSize: 17,
                          fontFamily: font,
                          package: 'cosmos_epub',
                          color: isSelected
                              ? widget.accentColor
                              : (isDark ? Colors.white : Colors.black),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeData {
  final int id;
  final String name;
  final Color bgColor;
  final Color textColor;
  final bool isLight;

  const _ThemeData(this.id, this.name, this.bgColor, this.textColor, this.isLight);
}
