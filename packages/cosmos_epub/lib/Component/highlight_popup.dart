import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../Model/highlight_model.dart';

/// Apple Books-style popup shown when tapping a highlight
/// Shows note preview with options to edit, change color, or delete
class HighlightPopup extends StatelessWidget {
  final HighlightModel highlight;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String colorHex) onColorChange;
  final VoidCallback onClose;

  const HighlightPopup({
    super.key,
    required this.highlight,
    required this.backgroundColor,
    required this.textColor,
    required this.onEdit,
    required this.onDelete,
    required this.onColorChange,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = backgroundColor.computeLuminance() < 0.5;
    final popupBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final popupText = isDark ? Colors.white : Colors.black87;
    final highlightColor = Color(HighlightColors.parseHex(highlight.colorHex));

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping popup
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              builder: (_, value, child) {
                return Transform.scale(
                  scale: 0.8 + 0.2 * value,
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                width: 320.w,
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                decoration: BoxDecoration(
                  color: popupBg,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with color indicator
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: highlightColor.withOpacity(0.2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.r),
                          topRight: Radius.circular(16.r),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: highlightColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'هایلایت',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: popupText,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20.sp,
                              color: popupText.withOpacity(0.6),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Highlighted text preview
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: highlightColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border(
                            right: BorderSide(
                              color: highlightColor,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          highlight.highlightedText.length > 150
                              ? '${highlight.highlightedText.substring(0, 150)}...'
                              : highlight.highlightedText,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: popupText.withOpacity(0.8),
                            height: 1.5,
                          ),
                          textDirection: TextDirection.rtl,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Note section (if exists)
                    if (highlight.hasNote) ...[
                      Divider(
                        height: 1,
                        color: popupText.withOpacity(0.1),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.note_rounded,
                                  size: 16.sp,
                                  color: popupText.withOpacity(0.6),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'یادداشت',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: popupText.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              highlight.noteText!,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: popupText,
                                height: 1.5,
                              ),
                              textDirection: TextDirection.rtl,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Color picker
                    Divider(
                      height: 1,
                      color: popupText.withOpacity(0.1),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: HighlightColors.all.map((colorHex) {
                          final isSelected = colorHex == highlight.colorHex;
                          final color = Color(HighlightColors.parseHex(colorHex));
                          return GestureDetector(
                            onTap: () => onColorChange(colorHex),
                            child: Container(
                              width: 36.w,
                              height: 36.h,
                              margin: EdgeInsets.symmetric(horizontal: 6.w),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? popupText
                                      : Colors.black.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 18.sp,
                                      color: popupText,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Action buttons
                    Divider(
                      height: 1,
                      color: popupText.withOpacity(0.1),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.edit_rounded,
                              label: highlight.hasNote ? 'ویرایش یادداشت' : 'افزودن یادداشت',
                              color: popupText,
                              onTap: onEdit,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'حذف',
                              color: Colors.red,
                              onTap: onDelete,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the highlight popup as an overlay
void showHighlightPopup({
  required BuildContext context,
  required HighlightModel highlight,
  required Color backgroundColor,
  required Color textColor,
  required Function(HighlightModel) onEdit,
  required Function(HighlightModel) onDelete,
  required Function(HighlightModel, String colorHex) onColorChange,
}) {
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => HighlightPopup(
      highlight: highlight,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onEdit: () {
        overlayEntry.remove();
        onEdit(highlight);
      },
      onDelete: () {
        overlayEntry.remove();
        onDelete(highlight);
      },
      onColorChange: (colorHex) {
        overlayEntry.remove();
        onColorChange(highlight, colorHex);
      },
      onClose: () => overlayEntry.remove(),
    ),
  );

  Overlay.of(context).insert(overlayEntry);
}
