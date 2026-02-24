import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:myna/utils/app_logger.dart';

/// Service to handle notification permission for Android 13+ (API 33+).
/// On Android 13+, POST_NOTIFICATIONS must be requested at runtime for
/// the media notification (background audio controls) to appear.
class NotificationPermissionService {
  static final NotificationPermissionService _instance = NotificationPermissionService._();
  factory NotificationPermissionService() => _instance;
  NotificationPermissionService._();

  /// MethodChannel for native Android notification diagnostics
  static const _diagChannel = MethodChannel('com.myna.audiobook/notification_diagnostics');

  bool _hasRequestedPermission = false;

  /// Request notification permission on Android 13+.
  /// Returns true if permission was granted or not needed (iOS, older Android).
  /// Should be called BEFORE starting background audio playback.
  Future<bool> ensureNotificationPermission() async {
    AppLogger.audioNotif('PERMISSION: ensureNotificationPermission() called');
    AppLogger.audioNotif('PERMISSION: Platform.operatingSystem=${Platform.operatingSystem}, '
        'Platform.version=${Platform.version}');

    // Only needed on Android
    if (!Platform.isAndroid) {
      AppLogger.audioNotif('PERMISSION: Not Android - permission not needed, returning true');
      return true;
    }

    // Don't ask multiple times in the same session
    if (_hasRequestedPermission) {
      final status = await Permission.notification.status;
      AppLogger.audioNotif('PERMISSION: Already requested this session - current status: '
          'isGranted=${status.isGranted}, isDenied=${status.isDenied}, '
          'isPermanentlyDenied=${status.isPermanentlyDenied}, isRestricted=${status.isRestricted}');
      return status.isGranted;
    }

    _hasRequestedPermission = true;

    // Check current status
    final status = await Permission.notification.status;
    AppLogger.audioNotif('PERMISSION: Initial status check - '
        'isGranted=${status.isGranted}, isDenied=${status.isDenied}, '
        'isPermanentlyDenied=${status.isPermanentlyDenied}, isRestricted=${status.isRestricted}, '
        'isLimited=${status.isLimited}, isProvisional=${status.isProvisional}');

    if (status.isGranted) {
      AppLogger.audioNotif('PERMISSION: Already granted - returning true');
      return true;
    }

    if (status.isPermanentlyDenied) {
      AppLogger.audioNotif('PERMISSION: PERMANENTLY DENIED - user must enable in Settings > Apps > Parasto > Notifications');
      // Don't request again, it won't show a dialog
      return false;
    }

    if (status.isRestricted) {
      AppLogger.audioNotif('PERMISSION: RESTRICTED (device policy) - cannot request');
      return false;
    }

    // Request the permission
    AppLogger.audioNotif('PERMISSION: Requesting notification permission from user...');
    final result = await Permission.notification.request();
    AppLogger.audioNotif('PERMISSION: Request result - '
        'isGranted=${result.isGranted}, isDenied=${result.isDenied}, '
        'isPermanentlyDenied=${result.isPermanentlyDenied}');

    if (result.isGranted) {
      AppLogger.audioNotif('PERMISSION: SUCCESS - user granted notification permission');
    } else if (result.isPermanentlyDenied) {
      AppLogger.audioNotif('PERMISSION: FAILED - user permanently denied (chose "Don\'t ask again")');
    } else {
      AppLogger.audioNotif('PERMISSION: FAILED - user denied permission');
    }

    // Log diagnostics after permission request to capture current state
    await logNotificationDiagnostics('PERMISSION');

    return result.isGranted;
  }

  /// Check if notification permission is granted without requesting.
  Future<bool> isNotificationPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    AppLogger.audioNotif('PERMISSION: Check (no request) - isGranted=${status.isGranted}');
    return status.isGranted;
  }

  /// Log notification diagnostics from native Android.
  /// Call this at key points to debug notification/lockscreen issues.
  /// [tag] is appended to the log line (e.g., STARTUP, PERMISSION, PLAYBACK)
  Future<void> logNotificationDiagnostics(String tag) async {
    if (!Platform.isAndroid) {
      AppLogger.audioNotif('DIAG[$tag] Skipped - not Android');
      return;
    }

    try {
      final result = await _diagChannel.invokeMethod<Map<dynamic, dynamic>>('getNotificationDiagnostics');
      if (result == null) {
        AppLogger.audioNotif('DIAG[$tag] ERROR: null result from native');
        return;
      }

      // Extract values with safe defaults
      final sdkInt = result['sdkInt'] as int? ?? -1;
      final notifEnabled = result['notifEnabled'] as bool? ?? false;
      final postNotifGranted = result['postNotifGranted'] as bool? ?? false;
      final channelExists = result['channelExists'] as bool? ?? false;
      final channelImportance = result['channelImportance'] as int? ?? -1;
      final channelImportanceName = result['channelImportanceName'] as String? ?? 'unknown';
      final channelBlocked = result['channelBlocked'] as bool? ?? false;
      final channelLockscreenVisibility = result['channelLockscreenVisibility'] as int? ?? -999;
      final channelCanShowBadge = result['channelCanShowBadge'] as bool? ?? false;

      // Log single structured line for easy parsing
      AppLogger.audioNotif(
        'DIAG[$tag] sdk=$sdkInt notifEnabled=$notifEnabled postNotif=$postNotifGranted '
        'channelExists=$channelExists importance=$channelImportance($channelImportanceName) '
        'blocked=$channelBlocked lockscreen=$channelLockscreenVisibility badge=$channelCanShowBadge'
      );

      // Log warnings for common issues
      if (!notifEnabled) {
        AppLogger.audioNotif('DIAG[$tag] WARNING: App notifications DISABLED at system level');
      }
      if (sdkInt >= 33 && !postNotifGranted) {
        AppLogger.audioNotif('DIAG[$tag] WARNING: POST_NOTIFICATIONS permission NOT granted (Android 13+)');
      }
      if (!channelExists) {
        AppLogger.audioNotif('DIAG[$tag] WARNING: Notification channel "app.myna.audio" does NOT exist');
      }
      if (channelBlocked) {
        AppLogger.audioNotif('DIAG[$tag] WARNING: Channel is BLOCKED by user');
      }
      if (channelImportance == 0) {
        AppLogger.audioNotif('DIAG[$tag] WARNING: Channel importance is NONE (0) - notifications hidden');
      }
      if (channelImportance == 1) {
        AppLogger.audioNotif('DIAG[$tag] WARNING: Channel importance is MIN (1) - no sound/vibration, may be hidden');
      }
    } on PlatformException catch (e) {
      AppLogger.audioNotif('DIAG[$tag] PlatformException: ${e.message}');
    } on MissingPluginException catch (e) {
      AppLogger.audioNotif('DIAG[$tag] MissingPluginException: ${e.message} (expected on non-Android or hot restart)');
    } catch (e) {
      AppLogger.audioNotif('DIAG[$tag] ERROR: $e');
    }
  }

  /// Get notification diagnostics as a structured map for UI display.
  /// Returns null on non-Android or if the call fails.
  Future<NotificationDiagnostics?> getNotificationDiagnostics() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final result = await _diagChannel.invokeMethod<Map<dynamic, dynamic>>('getNotificationDiagnostics');
      if (result == null) {
        return null;
      }

      return NotificationDiagnostics(
        sdkInt: result['sdkInt'] as int? ?? -1,
        notifEnabled: result['notifEnabled'] as bool? ?? false,
        postNotifGranted: result['postNotifGranted'] as bool? ?? false,
        channelExists: result['channelExists'] as bool? ?? false,
        channelImportance: result['channelImportance'] as int? ?? -1,
        channelImportanceName: result['channelImportanceName'] as String? ?? 'unknown',
        channelBlocked: result['channelBlocked'] as bool? ?? false,
        channelLockscreenVisibility: result['channelLockscreenVisibility'] as int? ?? -999,
        channelCanShowBadge: result['channelCanShowBadge'] as bool? ?? false,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Open the system notification channel settings for the audio channel.
  /// Falls back to app notification settings if channel settings aren't available.
  /// Returns true if settings were opened successfully.
  Future<bool> openChannelSettings({String channelId = 'app.myna.audio'}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _diagChannel.invokeMethod<bool>(
        'openChannelSettings',
        {'channelId': channelId},
      );
      return result ?? false;
    } catch (e) {
      AppLogger.audioNotif('openChannelSettings error: $e');
      return false;
    }
  }

  /// Open the system app notification settings.
  /// Returns true if settings were opened successfully.
  Future<bool> openAppNotificationSettings() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _diagChannel.invokeMethod<bool>('openAppNotificationSettings');
      return result ?? false;
    } catch (e) {
      AppLogger.audioNotif('openAppNotificationSettings error: $e');
      return false;
    }
  }
}

/// Data class for notification diagnostics
class NotificationDiagnostics {
  final int sdkInt;
  final bool notifEnabled;
  final bool postNotifGranted;
  final bool channelExists;
  final int channelImportance;
  final String channelImportanceName;
  final bool channelBlocked;
  final int channelLockscreenVisibility;
  final bool channelCanShowBadge;

  const NotificationDiagnostics({
    required this.sdkInt,
    required this.notifEnabled,
    required this.postNotifGranted,
    required this.channelExists,
    required this.channelImportance,
    required this.channelImportanceName,
    required this.channelBlocked,
    required this.channelLockscreenVisibility,
    required this.channelCanShowBadge,
  });

  /// Format as a single line for copying/logging
  String toFormattedString() {
    return 'sdk=$sdkInt notifEnabled=$notifEnabled postNotif=$postNotifGranted '
        'channelExists=$channelExists importance=$channelImportance($channelImportanceName) '
        'blocked=$channelBlocked lockscreen=$channelLockscreenVisibility badge=$channelCanShowBadge';
  }

  /// Check if notifications should work (all critical fields OK)
  bool get isHealthy =>
      notifEnabled &&
      (sdkInt < 33 || postNotifGranted) &&
      channelExists &&
      !channelBlocked &&
      channelImportance > 0;

  /// Get a list of detected issues
  List<String> get issues {
    final result = <String>[];
    if (!notifEnabled) {
      result.add('App notifications disabled');
    }
    if (sdkInt >= 33 && !postNotifGranted) {
      result.add('POST_NOTIFICATIONS not granted');
    }
    if (!channelExists) {
      result.add('Audio channel does not exist');
    }
    if (channelBlocked) {
      result.add('Channel blocked by user');
    }
    if (channelImportance == 0) {
      result.add('Channel importance is NONE');
    }
    if (channelImportance == 1) {
      result.add('Channel importance is MIN');
    }
    return result;
  }
}
