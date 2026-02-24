// Audio file validation for narrator uploads.
//
// Requirements:
// - Accepted formats: MP3, M4A (AAC) only
// - Recommended: Mono, 44.1 kHz, 64-96 kbps
// - Max chapter length: 240 minutes (4 hours)
// - Max file size: 500 MB per chapter (Supabase Pro plan)
//
// NOTE: The file size limit is determined by Supabase Storage configuration.
// If you change the limit in Supabase dashboard, update kServerMaxFileSizeMB below.

/// Result of audio file validation.
class AudioValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? warningMessage;

  const AudioValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
  });

  factory AudioValidationResult.valid({String? warning}) {
    return AudioValidationResult(isValid: true, warningMessage: warning);
  }

  factory AudioValidationResult.invalid(String error) {
    return AudioValidationResult(isValid: false, errorMessage: error);
  }
}

class AudioValidator {
  // ==========================================================================
  // UPLOAD LIMITS - Single source of truth
  // ==========================================================================
  // These limits MUST match your Supabase Storage configuration.
  // Supabase Pro plan allows up to 5GB. We set 500 MB as the app limit.
  // If you change the limit in Supabase dashboard, update kServerMaxFileSizeMB.
  // ==========================================================================

  /// Server-side file size limit in MB (matches Supabase Storage config)
  /// IMPORTANT: Update this if you change Supabase Storage file size limit
  static const int kServerMaxFileSizeMB = 500;

  /// Maximum file size in bytes (derived from kServerMaxFileSizeMB)
  static const int maxFileSizeBytes = kServerMaxFileSizeMB * 1024 * 1024;

  /// Warning threshold - show warning for files above this size (400 MB = 80% of limit)
  static const int warnFileSizeBytes = 400 * 1024 * 1024;

  /// Maximum chapter duration in seconds (240 minutes = 4 hours)
  static const int maxDurationSeconds = 240 * 60;

  /// Recommended bitrate for optimal file size
  static const int recommendedBitrateKbps = 64; // 64-96 kbps recommended

  // Accepted formats
  static const List<String> acceptedExtensions = ['mp3', 'm4a'];
  static const List<String> acceptedMimeTypes = [
    'audio/mpeg',
    'audio/mp3',
    'audio/mp4',
    'audio/m4a',
    'audio/x-m4a',
    'audio/aac',
  ];

  /// Validate an audio file for narrator upload.
  /// Returns a validation result with error/warning messages in Farsi.
  static AudioValidationResult validate({
    required String fileName,
    required int fileSizeBytes,
    String? mimeType,
    int? durationSeconds,
  }) {
    // 1. Check file extension
    final extension = _getExtension(fileName);
    if (!acceptedExtensions.contains(extension)) {
      return AudioValidationResult.invalid(
        'فرمت فایل پشتیبانی نمی‌شود.\n\n'
        'فرمت‌های مجاز: MP3، M4A (AAC)\n\n'
        'لطفاً فایل صوتی خود را با یکی از فرمت‌های بالا ذخیره کنید.',
      );
    }

    // 2. Check MIME type if provided
    if (mimeType != null && mimeType.isNotEmpty) {
      final normalizedMime = mimeType.toLowerCase();
      if (!acceptedMimeTypes.any((m) => normalizedMime.contains(m) || m.contains(normalizedMime))) {
        // Only reject if it's clearly not audio
        if (!normalizedMime.startsWith('audio/')) {
          return AudioValidationResult.invalid(
            'این فایل یک فایل صوتی معتبر نیست.\n\n'
            'فرمت‌های مجاز: MP3، M4A (AAC)',
          );
        }
      }
    }

    // 3. Check file size against server limit
    if (fileSizeBytes > maxFileSizeBytes) {
      final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return AudioValidationResult.invalid(
        'حجم فایل از حد مجاز بیشتر است ($sizeMB مگابایت).\n\n'
        'حداکثر حجم مجاز: $kServerMaxFileSizeMB مگابایت\n\n'
        'برای کاهش حجم فایل:\n'
        '• فرمت: MP3 یا M4A\n'
        '• کانال: مونو (Mono)\n'
        '• نرخ نمونه‌برداری: 44.1 kHz\n'
        '• بیت‌ریت: 64-96 kbps\n\n'
        'یا فصل را به چند بخش کوچک‌تر تقسیم کنید.',
      );
    }

    // 4. Check duration if provided
    if (durationSeconds != null && durationSeconds > maxDurationSeconds) {
      final durationMin = (durationSeconds / 60).toStringAsFixed(0);
      return AudioValidationResult.invalid(
        'مدت زمان فصل بیش از حد مجاز است ($durationMin دقیقه).\n\n'
        'حداکثر مدت هر فصل: ۲۴۰ دقیقه (۴ ساعت)\n\n'
        'لطفاً فصل‌های طولانی‌تر را به بخش‌های کوچک‌تر تقسیم کنید.',
      );
    }

    // 5. Warning for files approaching the limit
    // Large files may take longer to upload and could fail on slow connections
    if (fileSizeBytes > warnFileSizeBytes) {
      final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return AudioValidationResult.valid(
        warning: 'حجم فایل شما $sizeMB مگابایت است (حداکثر $kServerMaxFileSizeMB مگابایت). '
            'آپلود ممکن است زمان‌بر باشد.',
      );
    }

    return AudioValidationResult.valid();
  }

  /// Get file extension in lowercase
  static String _getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  /// Check if file extension is accepted
  static bool isAcceptedFormat(String fileName) {
    return acceptedExtensions.contains(_getExtension(fileName));
  }

  /// Get human-readable max file size
  static String getMaxFileSizeFormatted() {
    return '${maxFileSizeBytes ~/ (1024 * 1024)} مگابایت';
  }

  /// Get human-readable max duration
  static String getMaxDurationFormatted() {
    return '${maxDurationSeconds ~/ 60} دقیقه';
  }

  /// Get recommended settings as a list for display
  static List<String> getRecommendedSettings() {
    return [
      'فرمت: MP3 یا M4A (AAC)',
      'کانال: مونو (Mono)',
      'نرخ نمونه‌برداری: 44.1 kHz',
      'بیت‌ریت: 64-96 kbps',
      'حداکثر مدت هر فصل: ${maxDurationSeconds ~/ 60} دقیقه',
      'حداکثر حجم هر فصل: $kServerMaxFileSizeMB مگابایت',
    ];
  }

  /// Get file picker allowed extensions
  static List<String> getAllowedExtensions() {
    return acceptedExtensions;
  }

  /// Parse upload error and return a user-friendly Farsi message.
  /// Handles 413 Payload Too Large and other common storage errors.
  static String getUploadErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    // Check for 413 Payload Too Large (file size exceeded server limit)
    if (errorStr.contains('413') ||
        errorStr.contains('payload too large') ||
        errorStr.contains('exceeded the maximum allowed size') ||
        errorStr.contains('entity too large')) {
      return 'حجم فایل از حد مجاز سرور بیشتر است.\n\n'
          'حداکثر حجم مجاز: $kServerMaxFileSizeMB مگابایت\n\n'
          'لطفاً فایل را با حجم کمتر آپلود کنید.';
    }

    // Check for network/timeout errors
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'زمان آپلود به پایان رسید.\n\n'
          'لطفاً اتصال اینترنت خود را بررسی کرده و دوباره تلاش کنید.';
    }

    // Check for connection errors
    if (errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return 'خطا در اتصال به سرور.\n\n'
          'لطفاً اتصال اینترنت خود را بررسی کرده و دوباره تلاش کنید.';
    }

    // Check for authentication errors
    if (errorStr.contains('unauthorized') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('forbidden')) {
      return 'خطا در احراز هویت.\n\n'
          'لطفاً از برنامه خارج شده و دوباره وارد شوید.';
    }

    // Default error message - don't expose raw error to user
    return 'خطا در آپلود فایل.\n\n'
        'لطفاً دوباره تلاش کنید. اگر مشکل ادامه داشت، با پشتیبانی تماس بگیرید.';
  }
}
