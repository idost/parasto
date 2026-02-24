import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application logger that only outputs in debug mode.
///
/// Usage:
/// ```dart
/// AppLogger.d('Debug message');
/// AppLogger.i('Info message');
/// AppLogger.w('Warning message');
/// AppLogger.e('Error message', error: e, stackTrace: stack);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.off,
  );

  /// Log a debug message (only in debug mode)
  static void d(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log an info message (only in debug mode)
  static void i(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log a warning message (only in debug mode)
  static void w(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log an error message (only in debug mode)
  static void e(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log auth-related events (sanitized - no sensitive data)
  static void auth(String event, {bool? hasSession, String? userId}) {
    if (kDebugMode) {
      final sanitizedUserId = userId != null
          ? '${userId.substring(0, 8)}...'
          : 'null';
      _logger.i('AUTH: $event | session: $hasSession | user: $sanitizedUserId');
    }
  }

  /// Log network/API events
  static void api(String endpoint, {String? method, int? statusCode}) {
    if (kDebugMode) {
      _logger.d('API: ${method ?? 'GET'} $endpoint ${statusCode != null ? '[$statusCode]' : ''}');
    }
  }

  /// Log audio player events
  static void audio(String event, {String? chapter, Duration? position}) {
    if (kDebugMode) {
      final posStr = position != null
          ? '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}'
          : '';
      _logger.d('AUDIO: $event ${chapter ?? ''} $posStr');
    }
  }

  /// Log Android notification diagnostic events.
  /// Uses [AUDIO_NOTIF] tag for easy logcat filtering:
  ///   adb logcat | grep AUDIO_NOTIF
  ///
  /// This is specifically for debugging why Android media notifications
  /// or lockscreen controls might not appear.
  static void audioNotif(String message) {
    // Always print with [AUDIO_NOTIF] tag for logcat filtering, even in release
    // ignore: avoid_print
    print('[AUDIO_NOTIF] $message');
    // Also log via logger in debug mode for pretty output
    if (kDebugMode) {
      _logger.i('[AUDIO_NOTIF] $message');
    }
  }
}
