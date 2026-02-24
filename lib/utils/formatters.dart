// Shared formatting utilities for the Myna app

class Formatters {
  /// Format seconds into MM:SS format
  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format seconds into HH:MM:SS format for longer durations
  static String formatDurationLong(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format Duration object into MM:SS format
  static String formatDurationFromDuration(Duration duration) {
    return formatDuration(duration.inSeconds);
  }

  /// Format Duration object into HH:MM:SS format for longer durations
  static String formatDurationFromDurationLong(Duration duration) {
    return formatDurationLong(duration.inSeconds);
  }

  /// Format file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format price with Persian formatting
  /// If currencyLabel is null, only returns the formatted number
  static String formatPrice(int price, {String? currencyLabel}) {
    if (price == 0) return 'رایگان';

    // Add thousand separators
    final formatted = price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    if (currencyLabel != null && currencyLabel.isNotEmpty) {
      return '$formatted $currencyLabel';
    }
    return formatted;
  }

  /// Format number with thousand separators
  static String formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
