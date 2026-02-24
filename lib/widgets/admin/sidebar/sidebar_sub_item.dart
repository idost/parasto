import 'package:flutter/material.dart';

/// Data class for sub-items in expandable sections.
/// Used by both desktop and mobile sidebar.
class SidebarSubItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const SidebarSubItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.onTap,
    this.badge,
  });
}
