/// Utility functions for handling Farsi/Persian text
class FarsiUtils {
  FarsiUtils._();

  /// Normalize a Farsi search query for better matching
  /// Handles common character variations and spacing issues
  static String normalizeSearchQuery(String query) {
    if (query.isEmpty) return query;

    String normalized = query;

    // 1. Replace Arabic characters with Farsi equivalents
    // Arabic Yeh (ي) -> Farsi Yeh (ی)
    normalized = normalized.replaceAll('\u064A', '\u06CC');
    // Arabic Kaf (ك) -> Farsi Kaf (ک)
    normalized = normalized.replaceAll('\u0643', '\u06A9');
    // Arabic Heh (ه) variations - keep as is, they're usually compatible

    // 2. Normalize Alef variations
    // Alef with Hamza above (أ) -> Alef (ا)
    normalized = normalized.replaceAll('\u0623', '\u0627');
    // Alef with Hamza below (إ) -> Alef (ا)
    normalized = normalized.replaceAll('\u0625', '\u0627');
    // Alef with Madda (آ) -> keep as is, it's meaningful in Farsi

    // 3. Handle zero-width characters
    // Remove Zero-Width Non-Joiner (ZWNJ / half-space) - common in Farsi compound words
    normalized = normalized.replaceAll('\u200C', ' ');
    // Remove Zero-Width Joiner
    normalized = normalized.replaceAll('\u200D', '');
    // Remove other zero-width characters
    normalized = normalized.replaceAll('\u200B', ''); // Zero-Width Space
    normalized = normalized.replaceAll('\uFEFF', ''); // BOM

    // 4. Normalize spaces
    // Replace multiple spaces with single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    // Trim leading/trailing whitespace
    normalized = normalized.trim();

    return normalized;
  }

  /// Generate search variations for a query
  /// Returns a list of possible search patterns
  static List<String> getSearchVariations(String query) {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) return [];

    final variations = <String>{normalized};

    // Add variation with Alef-Madda (آ) replaced with Alef (ا)
    // Useful when users type without the madda
    if (normalized.contains('\u0622')) {
      variations.add(normalized.replaceAll('\u0622', '\u0627'));
    }
    // Also add reverse: if they typed Alef, also search Alef-Madda
    if (normalized.contains('\u0627') && !normalized.contains('\u0622')) {
      // Only for word-initial Alef that might be Alef-Madda
      variations.add(normalized.replaceAll(RegExp(r'(^|\s)\u0627'), r'$1\u0622'));
    }

    return variations.toList();
  }

  /// Format a number in Farsi digits
  static String toFarsiDigits(dynamic number) {
    const farsiDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return number.toString().split('').map((char) {
      final digit = int.tryParse(char);
      return digit != null ? farsiDigits[digit] : char;
    }).join();
  }

  /// Format price in Farsi with Toman suffix
  static String formatPriceFarsi(int priceToman) {
    if (priceToman <= 0) return 'رایگان';

    // Add thousand separators
    final formatted = priceToman.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}٬',
    );

    return '$formatted تومان';
  }

  /// Format duration as MM:SS with Farsi digits
  static String formatDurationFarsi(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${toFarsiDigits(m.toString().padLeft(2, '0'))}:${toFarsiDigits(s.toString().padLeft(2, '0'))}';
  }

  /// Format duration as HH:MM:SS with Farsi digits (for longer durations)
  static String formatDurationLongFarsi(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${toFarsiDigits(h.toString().padLeft(2, '0'))}:${toFarsiDigits(m.toString().padLeft(2, '0'))}:${toFarsiDigits(s.toString().padLeft(2, '0'))}';
    }
    return '${toFarsiDigits(m.toString().padLeft(2, '0'))}:${toFarsiDigits(s.toString().padLeft(2, '0'))}';
  }

  /// Format Duration object as MM:SS with Farsi digits
  static String formatDurationFromDurationFarsi(Duration duration) {
    return formatDurationFarsi(duration.inSeconds);
  }

  /// Format Duration object as HH:MM:SS with Farsi digits
  static String formatDurationFromDurationLongFarsi(Duration duration) {
    return formatDurationLongFarsi(duration.inSeconds);
  }

  /// Localize a string to Farsi — converts any Western/Arabic digits to Farsi digits.
  /// Used for display strings that may contain mixed numerals.
  static String localizeFarsi(String input) => toFarsiDigits(input);

  /// Format a number with Farsi digits and thousand separators
  static String formatNumberFarsi(int number) {
    final formatted = number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}٬',
    );
    return toFarsiDigits(formatted);
  }
}
