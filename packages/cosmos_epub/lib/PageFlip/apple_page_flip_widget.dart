import 'package:flutter/material.dart';

import '../Component/constants.dart';

/// Apple Books-style page flip widget with multiple animation styles
/// Supports: Slide (default), Curl (classic), None (instant)
class ApplePageFlipWidget extends StatefulWidget {
  ApplePageFlipWidget({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.pageStyle = PageTurnStyle.slide,
    this.backgroundColor = Colors.white,
    this.isRightSwipe = false,
    this.lastPage,
    required this.onPageFlip,
    this.onTap,
    this.cutoffForward = 0.3,
    this.cutoffPrevious = 0.3,
  }) : assert(children.isEmpty || initialIndex < children.length,
            'initialIndex cannot be greater than children length');

  final List<Widget> children;
  final int initialIndex;
  final PageTurnStyle pageStyle;
  final Color backgroundColor;
  final bool isRightSwipe;
  final Widget? lastPage;
  final Function(int) onPageFlip;
  final VoidCallback? onTap;
  final double cutoffForward;
  final double cutoffPrevious;

  @override
  ApplePageFlipWidgetState createState() => ApplePageFlipWidgetState();
}

class ApplePageFlipWidgetState extends State<ApplePageFlipWidget>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _curlController;

  // For curl/none effect gesture handling
  bool _isDragging = false;
  bool? _isForward;
  Offset? _dragStartPosition;

  static const double _tapTolerance = 10.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _curlController = AnimationController(
      value: 1.0,
      duration: PageTurnDurations.forStyle(widget.pageStyle),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _curlController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ApplePageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageStyle != widget.pageStyle) {
      _curlController.duration = PageTurnDurations.forStyle(widget.pageStyle);
    }

    // CRITICAL FIX: Handle initialIndex changes (e.g., when navigating to a specific page)
    // This happens when the parent widget wants to start on a different page
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
      if (widget.pageStyle == PageTurnStyle.slide && _pageController.hasClients) {
        // Jump without animation for instant navigation
        _pageController.jumpToPage(widget.initialIndex);
      }
    }

    // Handle children change (chapter reload) - reset to the new initial index
    if (oldWidget.children.length != widget.children.length) {
      // Children changed, likely a chapter reload
      // Keep current index if valid, otherwise reset to initialIndex
      if (_currentIndex >= widget.children.length) {
        _currentIndex = widget.initialIndex.clamp(0, widget.children.isEmpty ? 0 : widget.children.length - 1);
        if (widget.pageStyle == PageTurnStyle.slide && _pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      }
    }
  }

  int get _totalPages => widget.children.length + (widget.lastPage != null ? 1 : 0);
  bool get _isFirstPage => _currentIndex == 0;
  bool get _isLastPage => _currentIndex >= _totalPages - 1;

  /// Navigate to a specific page
  Future<void> goToPage(int index) async {
    if (index < 0 || index >= _totalPages) return;

    if (widget.pageStyle == PageTurnStyle.slide) {
      // Update local state first
      setState(() {
        _currentIndex = index;
      });
      // Then animate to the page
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          index,
          duration: PageTurnDurations.slide,
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
    widget.onPageFlip(index);
  }

  /// Go to next page
  Future<void> nextPage() async {
    if (_isLastPage) return;
    await goToPage(_currentIndex + 1);
  }

  /// Go to previous page
  Future<void> previousPage() async {
    if (_isFirstPage) return;
    await goToPage(_currentIndex - 1);
  }

  Widget _buildPage(int index) {
    if (index < widget.children.length) {
      return widget.children[index];
    } else if (widget.lastPage != null && index == widget.children.length) {
      return widget.lastPage!;
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    switch (widget.pageStyle) {
      case PageTurnStyle.slide:
        return _buildSlidePageView();
      case PageTurnStyle.curl:
        return _buildCurlPageView();
      case PageTurnStyle.none:
        return _buildInstantPageView();
    }
  }

  /// Modern slide animation (Apple Books default)
  /// Uses PageView which handles gestures properly with child widgets
  Widget _buildSlidePageView() {
    return PageView.builder(
      controller: _pageController,
      reverse: widget.isRightSwipe,
      // Use ClampingScrollPhysics instead of BouncingScrollPhysics
      // to avoid conflicts with child scroll widgets
      physics: const ClampingScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
        widget.onPageFlip(index);
      },
      itemCount: _totalPages,
      itemBuilder: (context, index) => _buildPage(index),
    );
  }

  /// Classic curl animation (skeuomorphic)
  Widget _buildCurlPageView() {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _dragStartPosition = details.globalPosition;
          _isForward = null;
          _isDragging = false;
        },
        onHorizontalDragUpdate: (details) {
          if (_dragStartPosition != null) {
            final distance = (details.globalPosition - _dragStartPosition!).distance;
            if (distance > _tapTolerance) {
              _isDragging = true;
            }
          }

          if (!_isDragging) return;

          // Determine direction
          if (_isForward == null) {
            if (widget.isRightSwipe
                ? details.delta.dx < 0.0
                : details.delta.dx > 0.0) {
              _isForward = false;
            } else if (widget.isRightSwipe
                ? details.delta.dx > 0.2
                : details.delta.dx < -0.2) {
              _isForward = true;
            }
          }

          // Update animation
          if (_isForward == true && !_isLastPage) {
            final ratio = details.delta.dx / constraints.maxWidth;
            _curlController.value += widget.isRightSwipe ? -ratio : ratio;
          } else if (_isForward == false && !_isFirstPage) {
            final ratio = details.delta.dx / constraints.maxWidth;
            _curlController.value += widget.isRightSwipe ? ratio : -ratio;
          }
        },
        onHorizontalDragEnd: (details) async {
          if (_isForward == true) {
            if (!_isLastPage && _curlController.value <= widget.cutoffForward) {
              await _curlController.reverse();
              setState(() {
                _currentIndex++;
                _curlController.value = 1.0;
              });
              widget.onPageFlip(_currentIndex);
            } else {
              await _curlController.forward();
              widget.onPageFlip(_currentIndex);
            }
          } else if (_isForward == false) {
            if (!_isFirstPage && _curlController.value >= (1 - widget.cutoffPrevious)) {
              setState(() {
                _currentIndex--;
                _curlController.value = 0.0;
              });
              await _curlController.forward();
              widget.onPageFlip(_currentIndex);
            } else {
              await _curlController.reverse();
              widget.onPageFlip(_currentIndex);
            }
          }
          _isForward = null;
          _isDragging = false;
          _dragStartPosition = null;
        },
        onHorizontalDragCancel: () {
          _isForward = null;
          _isDragging = false;
          _dragStartPosition = null;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background/next page
            if (_currentIndex + 1 < _totalPages)
              _buildPage(_currentIndex + 1),
            // Current page with curl effect
            AnimatedBuilder(
              animation: _curlController,
              builder: (context, child) {
                return ClipRect(
                  child: Transform.translate(
                    offset: Offset(
                      widget.isRightSwipe
                          ? constraints.maxWidth * (1 - _curlController.value)
                          : -constraints.maxWidth * (1 - _curlController.value),
                      0,
                    ),
                    child: child,
                  ),
                );
              },
              child: RepaintBoundary(
                child: _buildPage(_currentIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Instant page change (no animation)
  Widget _buildInstantPageView() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _dragStartPosition = details.globalPosition;
        _isDragging = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_dragStartPosition != null) {
          final distance = (details.globalPosition - _dragStartPosition!).distance;
          if (distance > _tapTolerance) {
            _isDragging = true;
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (!_isDragging) return;

        final velocity = details.primaryVelocity ?? 0;
        if (widget.isRightSwipe) {
          if (velocity > 200 && !_isFirstPage) {
            setState(() => _currentIndex--);
            widget.onPageFlip(_currentIndex);
          } else if (velocity < -200 && !_isLastPage) {
            setState(() => _currentIndex++);
            widget.onPageFlip(_currentIndex);
          }
        } else {
          if (velocity < -200 && !_isLastPage) {
            setState(() => _currentIndex++);
            widget.onPageFlip(_currentIndex);
          } else if (velocity > 200 && !_isFirstPage) {
            setState(() => _currentIndex--);
            widget.onPageFlip(_currentIndex);
          }
        }

        _isDragging = false;
        _dragStartPosition = null;
      },
      child: _buildPage(_currentIndex),
    );
  }
}
