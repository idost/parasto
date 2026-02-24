import 'package:flutter/material.dart';

/// Data class for mobile sub-items in expandable sections.
class MobileSubItem {
  final IconData icon;
  final String label;
  final String route;
  final int? badge;

  const MobileSubItem({
    required this.icon,
    required this.label,
    required this.route,
    this.badge,
  });
}
