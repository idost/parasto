import 'package:flutter/material.dart';
import '../Model/highlight_model.dart';
import 'theme_colors.dart';

/// Apple Books-style Note editor
/// Full-screen dark editor with colored sidebar indicator
class AppleNoteEditor extends StatefulWidget {
  final String highlightedText;
  final String? existingNote;
  final String colorHex;
  final VoidCallback onClose;
  final Function(String note) onSave;

  const AppleNoteEditor({
    super.key,
    required this.highlightedText,
    this.existingNote,
    required this.colorHex,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<AppleNoteEditor> createState() => _AppleNoteEditorState();
}

class _AppleNoteEditorState extends State<AppleNoteEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingNote ?? '');
    _focusNode = FocusNode();
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = Color(HighlightColors.parseHex(widget.colorHex));
    final now = DateTime.now();
    final timeString = '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      backgroundColor: cParastoSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Note title and time
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Note',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Done button (checkmark)
                  GestureDetector(
                    onTap: () {
                      widget.onSave(_controller.text);
                      widget.onClose();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 24,
                        color: cParastoSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cParastoSurfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Colored sidebar indicator
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Highlighted text preview
                            Text(
                              widget.highlightedText.length > 100
                                  ? '${widget.highlightedText.substring(0, 100)}...'
                                  : widget.highlightedText,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            // Note text field
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add a note...',
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the Apple Note editor as a full-screen modal
void showAppleNoteEditor({
  required BuildContext context,
  required String highlightedText,
  String? existingNote,
  required String colorHex,
  required Function(String note) onSave,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: AppleNoteEditor(
            highlightedText: highlightedText,
            existingNote: existingNote,
            colorHex: colorHex,
            onClose: () => Navigator.of(context).pop(),
            onSave: onSave,
          ),
        );
      },
    ),
  );
}
