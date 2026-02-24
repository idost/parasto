/// Helper functions for Farsi/Persian text in EPUB reader
/// This is local to cosmos_epub package to avoid external dependencies
class FarsiHelper {
  FarsiHelper._();

  /// Persian/Farsi digits
  static const List<String> _farsiDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  /// Convert Latin digits (0-9) to Persian/Farsi digits (۰-۹)
  /// Example: "123" -> "۱۲۳"
  static String toFarsiDigits(dynamic input) {
    return input.toString().split('').map((char) {
      final digit = int.tryParse(char);
      return digit != null ? _farsiDigits[digit] : char;
    }).join();
  }

  /// Format page indicator: "صفحه ۱۲ از ۱۴۰"
  static String formatPageIndicator(int current, int total) {
    return 'صفحه ${toFarsiDigits(current)} از ${toFarsiDigits(total)}';
  }

  /// Format percentage with Farsi digits and Persian percent sign
  /// Example: 35 -> "۳۵٪"
  static String formatPercent(int percent) {
    return '${toFarsiDigits(percent)}٪';
  }

  /// Normalize Farsi text for search (handle Arabic/Farsi character variations)
  static String normalizeForSearch(String text) {
    if (text.isEmpty) return text;

    String normalized = text.toLowerCase();

    // Replace Arabic characters with Farsi equivalents
    // Arabic Yeh (ي) -> Farsi Yeh (ی)
    normalized = normalized.replaceAll('\u064A', '\u06CC');
    // Arabic Kaf (ك) -> Farsi Kaf (ک)
    normalized = normalized.replaceAll('\u0643', '\u06A9');

    // Normalize Alef variations
    // Alef with Hamza above (أ) -> Alef (ا)
    normalized = normalized.replaceAll('\u0623', '\u0627');
    // Alef with Hamza below (إ) -> Alef (ا)
    normalized = normalized.replaceAll('\u0625', '\u0627');

    // Handle zero-width characters
    normalized = normalized.replaceAll('\u200C', ' '); // ZWNJ / half-space
    normalized = normalized.replaceAll('\u200D', ''); // ZWJ
    normalized = normalized.replaceAll('\u200B', ''); // Zero-Width Space
    normalized = normalized.replaceAll('\uFEFF', ''); // BOM

    // Normalize spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.trim();

    return normalized;
  }
}
