/// Input validators for form fields.
///
/// All validators return null if valid, or an error message string if invalid.
class Validators {
  /// Validate email address format
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'ایمیل را وارد کنید';
    }

    // Trim whitespace
    final trimmed = value.trim();

    // Check basic format with regex
    // This regex validates:
    // - At least one character before @
    // - @ symbol
    // - At least one character after @ and before .
    // - A dot
    // - At least 2 characters for TLD
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    );

    if (!emailRegex.hasMatch(trimmed)) {
      return 'فرمت ایمیل نامعتبر است';
    }

    // Check length
    if (trimmed.length > 254) {
      return 'ایمیل بیش از حد طولانی است';
    }

    return null;
  }

  /// Validate password strength
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'رمز عبور را وارد کنید';
    }

    if (value.length < minLength) {
      return 'رمز عبور باید حداقل $minLength کاراکتر باشد';
    }

    // Check for at least one letter and one number for stronger passwords
    // Uncomment for stricter validation:
    // if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
    //   return 'رمز عبور باید شامل حداقل یک حرف باشد';
    // }
    // if (!RegExp(r'[0-9]').hasMatch(value)) {
    //   return 'رمز عبور باید شامل حداقل یک عدد باشد';
    // }

    return null;
  }

  /// Validate password confirmation matches
  static String? passwordConfirm(String? value, String? original) {
    if (value == null || value.isEmpty) {
      return 'تکرار رمز عبور را وارد کنید';
    }

    if (value != original) {
      return 'رمز عبور مطابقت ندارد';
    }

    return null;
  }

  /// Validate required field is not empty
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName را وارد کنید' : 'این فیلد الزامی است';
    }
    return null;
  }

  /// Validate name field (Persian or English letters, spaces)
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'نام را وارد کنید';
    }

    final trimmed = value.trim();

    // Allow Persian, Arabic, and English letters, spaces, and common punctuation
    // Persian Unicode range: \u0600-\u06FF (Arabic/Persian)
    // Also allowing \u0750-\u077F (Arabic Supplement)
    final nameRegex = RegExp(
      r'^[\u0600-\u06FF\u0750-\u077Fa-zA-Z\s\.\-]+$',
    );

    if (!nameRegex.hasMatch(trimmed)) {
      return 'نام فقط می‌تواند شامل حروف باشد';
    }

    if (trimmed.length < 2) {
      return 'نام باید حداقل ۲ کاراکتر باشد';
    }

    if (trimmed.length > 100) {
      return 'نام بیش از حد طولانی است';
    }

    return null;
  }

  /// Validate price (must be positive integer)
  static String? price(String? value, {bool allowZero = true}) {
    if (value == null || value.isEmpty) {
      return 'قیمت را وارد کنید';
    }

    final price = int.tryParse(value);
    if (price == null) {
      return 'قیمت باید عدد باشد';
    }

    if (!allowZero && price <= 0) {
      return 'قیمت باید بزرگتر از صفر باشد';
    }

    if (price < 0) {
      return 'قیمت نمی‌تواند منفی باشد';
    }

    return null;
  }

  /// Validate text length
  static String? length(
    String? value, {
    int? min,
    int? max,
    String? fieldName,
  }) {
    if (value == null) return null;

    final trimmed = value.trim();

    if (min != null && trimmed.length < min) {
      return '${fieldName ?? 'متن'} باید حداقل $min کاراکتر باشد';
    }

    if (max != null && trimmed.length > max) {
      return '${fieldName ?? 'متن'} نباید بیشتر از $max کاراکتر باشد';
    }

    return null;
  }

  /// Sanitize text input (remove potentially dangerous characters)
  static String sanitize(String input) {
    // Remove control characters
    var sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Trim excessive whitespace
    sanitized = sanitized.trim();

    // Replace multiple spaces with single space
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    return sanitized;
  }

  /// Sanitize for display (escape HTML-like content)
  static String sanitizeForDisplay(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
}
