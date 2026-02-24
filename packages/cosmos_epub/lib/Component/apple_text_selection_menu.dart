import 'package:flutter/material.dart';
import '../Model/highlight_model.dart';
import 'theme_colors.dart';

/// Apple Books-style text selection menu
/// Compact horizontal bar with: Highlight | Add Note | Look Up | > (more)
class AppleTextSelectionMenu extends StatefulWidget {
  final String selectedText;
  final Offset position;
  final Color accentColor;
  final VoidCallback onHighlight;
  final VoidCallback onAddNote;
  final VoidCallback onLookUp;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onSearch;
  final VoidCallback onClose;
  final Function(String colorHex)? onHighlightWithColor;

  const AppleTextSelectionMenu({
    super.key,
    required this.selectedText,
    required this.position,
    required this.accentColor,
    required this.onHighlight,
    required this.onAddNote,
    required this.onLookUp,
    required this.onCopy,
    required this.onShare,
    required this.onSearch,
    required this.onClose,
    this.onHighlightWithColor,
  });

  @override
  State<AppleTextSelectionMenu> createState() => _AppleTextSelectionMenuState();
}

class _AppleTextSelectionMenuState extends State<AppleTextSelectionMenu>
    with SingleTickerProviderStateMixin {
  bool _showMore = false;
  bool _showColorPicker = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: widget.position.dy.clamp(100.0, MediaQuery.of(context).size.height - 200),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _showColorPicker ? _buildColorPicker() : _buildMenu(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: cParastoSurfaceLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _showMore ? _buildExpandedMenu() : _buildCompactMenu(),
      ),
    );
  }

  /// Compact menu: Highlight | Add Note | Look Up | >
  Widget _buildCompactMenu() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuItem(
          icon: Icons.brush_rounded,
          label: 'هایلایت',
          onTap: () {
            setState(() => _showColorPicker = true);
          },
        ),
        _divider(),
        _MenuItem(
          icon: Icons.note_add_rounded,
          label: 'یادداشت',
          onTap: widget.onAddNote,
        ),
        _divider(),
        _MenuItem(
          icon: Icons.search_rounded,
          label: 'جستجو',
          onTap: widget.onLookUp,
        ),
        _divider(),
        _MenuItem(
          icon: Icons.chevron_right_rounded,
          label: '',
          isChevron: true,
          onTap: () => setState(() => _showMore = true),
        ),
      ],
    );
  }

  /// Expanded menu: Translate | Search | Copy | Share
  Widget _buildExpandedMenu() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuItem(
          icon: Icons.chevron_left_rounded,
          label: '',
          isChevron: true,
          onTap: () => setState(() => _showMore = false),
        ),
        _divider(),
        _MenuItem(
          icon: Icons.translate_rounded,
          label: 'ترجمه',
          onTap: widget.onLookUp, // TODO: Separate translate
        ),
        _divider(),
        _MenuItem(
          icon: Icons.search_rounded,
          label: 'جستجو',
          onTap: widget.onSearch,
        ),
        _divider(),
        _MenuItem(
          icon: Icons.copy_rounded,
          label: 'کپی',
          onTap: widget.onCopy,
        ),
        _divider(),
        _MenuItem(
          icon: Icons.share_rounded,
          label: 'اشتراک',
          onTap: widget.onShare,
        ),
      ],
    );
  }

  /// Apple Books-style color picker: Yellow | Green | Blue | Red | Purple | Underline
  Widget _buildColorPicker() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cParastoSurfaceLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Back button
            GestureDetector(
              onTap: () => setState(() => _showColorPicker = false),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Color dots - Apple Books exact colors
            _ColorDot(
              color: Color(HighlightColors.parseHex(HighlightColors.yellow)),
              onTap: () => _selectColor(HighlightColors.yellow),
            ),
            _ColorDot(
              color: Color(HighlightColors.parseHex(HighlightColors.green)),
              onTap: () => _selectColor(HighlightColors.green),
            ),
            _ColorDot(
              color: Color(HighlightColors.parseHex(HighlightColors.blue)),
              onTap: () => _selectColor(HighlightColors.blue),
            ),
            _ColorDot(
              color: Color(HighlightColors.parseHex(HighlightColors.red)),
              onTap: () => _selectColor(HighlightColors.red),
            ),
            _ColorDot(
              color: Color(HighlightColors.parseHex(HighlightColors.purple)),
              onTap: () => _selectColor(HighlightColors.purple),
            ),
            const SizedBox(width: 8),
            // Divider
            Container(
              width: 1,
              height: 24,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 8),
            // Underline option
            GestureDetector(
              onTap: () => _selectColor(HighlightColors.yellow), // Default for underline
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'U',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[300],
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey[300],
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectColor(String colorHex) {
    if (widget.onHighlightWithColor != null) {
      widget.onHighlightWithColor!(colorHex);
    } else {
      widget.onHighlight();
    }
    widget.onClose();
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.grey[700],
    );
  }
}

/// Menu item with icon and optional label
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isChevron ? 8 : 14,
          vertical: 10,
        ),
        child: isChevron
            ? Icon(icon, size: 22, color: Colors.grey[400])
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Color dot for highlight color picker
class _ColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;

  const _ColorDot({
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the Apple text selection menu as an overlay
OverlayEntry? showAppleTextSelectionMenu({
  required BuildContext context,
  required String selectedText,
  required Offset position,
  required Color accentColor,
  required Function(String colorHex) onHighlight,
  required VoidCallback onAddNote,
  required VoidCallback onLookUp,
  required VoidCallback onCopy,
  required VoidCallback onShare,
  required VoidCallback onSearch,
}) {
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => AppleTextSelectionMenu(
      selectedText: selectedText,
      position: position,
      accentColor: accentColor,
      onHighlight: () {
        overlayEntry.remove();
        onHighlight(HighlightColors.yellow);
      },
      onHighlightWithColor: (colorHex) {
        overlayEntry.remove();
        onHighlight(colorHex);
      },
      onAddNote: () {
        overlayEntry.remove();
        onAddNote();
      },
      onLookUp: () {
        overlayEntry.remove();
        onLookUp();
      },
      onCopy: () {
        overlayEntry.remove();
        onCopy();
      },
      onShare: () {
        overlayEntry.remove();
        onShare();
      },
      onSearch: () {
        overlayEntry.remove();
        onSearch();
      },
      onClose: () => overlayEntry.remove(),
    ),
  );

  Overlay.of(context).insert(overlayEntry);
  return overlayEntry;
}
