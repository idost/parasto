import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enum representing the UI mode of the app for narrator users.
/// This is purely a UI-level switch - it does NOT change database roles.
enum AppMode {
  /// Listener mode - shows MainShell (Home, Library, Search, Profile)
  listener,

  /// Narrator mode - shows NarratorMainShell (Dashboard, Audiobooks, Upload, Profile)
  narrator,
}

/// Provider for the current app mode.
///
/// This controls which shell is shown to narrator users:
/// - [AppMode.listener] → MainShell (default listener experience)
/// - [AppMode.narrator] → NarratorMainShell (narrator dashboard)
///
/// IMPORTANT: This is a UI-only switch. It does NOT modify:
/// - Database roles (profiles.role)
/// - RLS policies or permissions
/// - User capabilities
///
/// Only users with narrator/admin role can switch modes.
/// Listener-only users always see MainShell regardless of this setting.
final appModeProvider = StateProvider<AppMode>((ref) => AppMode.listener);
