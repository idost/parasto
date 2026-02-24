// Build-time metadata injected via --dart-define at compile time.
//
// Values are compile-time constants — baked into the binary, not read at
// runtime. This means they survive network failures, cold starts, and any
// environment. The flutter run / flutter build commands in the Makefile
// (and the helper script below) set these automatically from git.
//
// Usage:
//   flutter run --dart-define=GIT_SHA=$(git rev-parse --short HEAD) \
//               --dart-define=GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) \
//               --dart-define=BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
//
// If the defines are not passed (e.g. raw Xcode build), the fallback
// values make the missing info obvious rather than crashing.

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode, kReleaseMode;

class BuildInfo {
  BuildInfo._(); // not instantiable

  // ── Compile-time constants (set via --dart-define) ──────────────────────

  /// Short git commit SHA, e.g. "4fee5ef"
  /// Fallback: "unknown-sha" — means the build was not stamped.
  static const String gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'unknown-sha',
  );

  /// Git branch name, e.g. "cleanup/code-review-backup-20260201-213457"
  static const String gitBranch = String.fromEnvironment(
    'GIT_BRANCH',
    defaultValue: 'unknown-branch',
  );

  /// ISO-8601 UTC build timestamp, e.g. "2026-02-19T03:42:00Z"
  static const String buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'unknown-time',
  );

  /// Bundle identifier injected at build time.
  /// Fallback reads from the compile-time constant so it works without
  /// package_info_plus. Override via --dart-define=BUNDLE_ID=... if needed.
  static const String bundleId = String.fromEnvironment(
    'BUNDLE_ID',
    defaultValue: 'com.myna.audiobook', // matches project.pbxproj
  );

  // ── Derived properties ───────────────────────────────────────────────────

  /// Human-readable build environment label.
  static String get environment {
    if (kReleaseMode) return 'Release';
    if (kProfileMode) return 'Profile';
    if (kDebugMode) return 'Debug';
    return 'Unknown';
  }

  /// Whether the build was stamped with git metadata.
  static bool get isStamped =>
      gitSha != 'unknown-sha' && buildTime != 'unknown-time';

  /// One-line summary for logs / crash reports.
  static String get summary =>
      '$gitSha @ $gitBranch | $buildTime | $environment | $bundleId';
}
