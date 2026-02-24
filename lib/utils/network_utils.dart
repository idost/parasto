import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/config/cache_config.dart';
import 'package:myna/utils/app_logger.dart';

/// Utility for detecting network speed and adjusting app behavior accordingly.
///
/// Uses a simple ping test to Supabase to estimate connection quality.
/// On slow connections, enables longer cache durations to reduce API calls.
class NetworkUtils {
  NetworkUtils._();

  /// Threshold in milliseconds - connections slower than this are considered "slow".
  /// 2000ms (2 seconds) is a reasonable threshold for mobile networks.
  static const int _slowNetworkThresholdMs = 2000;

  /// Tests network speed by timing a small Supabase query.
  /// Returns the response time in milliseconds, or -1 if the request failed.
  static Future<int> measureNetworkSpeed() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Small query to test connection - just fetch 1 row with minimal data
      await Supabase.instance.client
          .from('audiobooks')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      AppLogger.d('Network speed test failed: $e');
      return -1;
    }
  }

  /// Checks network speed and enables slow network mode if needed.
  /// Call this during app initialization or when resuming from background.
  static Future<void> detectAndConfigureNetworkMode() async {
    final responseTime = await measureNetworkSpeed();

    if (responseTime < 0) {
      // Request failed - assume slow/offline, enable slow mode
      CacheConfig.slowNetworkMode = true;
      AppLogger.i('Network: Request failed, enabling slow network mode');
    } else if (responseTime > _slowNetworkThresholdMs) {
      // Slow connection detected
      CacheConfig.slowNetworkMode = true;
      AppLogger.i('Network: Slow connection detected (${responseTime}ms), enabling slow network mode');
    } else {
      // Good connection
      CacheConfig.slowNetworkMode = false;
      AppLogger.d('Network: Good connection (${responseTime}ms)');
    }
  }

  /// Manually enable slow network mode (e.g., from user settings).
  static void enableSlowNetworkMode() {
    CacheConfig.slowNetworkMode = true;
    AppLogger.i('Network: Slow network mode enabled manually');
  }

  /// Manually disable slow network mode.
  static void disableSlowNetworkMode() {
    CacheConfig.slowNetworkMode = false;
    AppLogger.i('Network: Slow network mode disabled');
  }

  /// Returns whether slow network mode is currently active.
  static bool get isSlowNetworkMode => CacheConfig.slowNetworkMode;
}
