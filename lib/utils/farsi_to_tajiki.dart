/// Farsi (Persian) to Tajiki (Cyrillic) transliteration utility.
///
/// Tajiki is linguistically very close to Farsi but uses Cyrillic script.
/// This utility converts Persian/Arabic script text to Tajiki Cyrillic.
///
/// Note: This is phonetic transliteration, not translation.
/// The meaning stays the same, only the script changes.
class FarsiToTajiki {
  /// Character mapping from Farsi/Arabic to Tajiki Cyrillic
  static const Map<String, String> _charMap = {
    // Vowels and semi-vowels
    'ا': 'а',    // alef -> a
    'آ': 'о',    // alef with madda -> o (often 'ā')
    'ی': 'ӣ',    // ye -> i (with macron for long i)
    'ي': 'ӣ',    // Arabic ye
    'و': 'ӯ',    // vav -> u (with macron for long u) or 'в' as consonant
    'ە': 'а',    // Kurdish he -> a
    'ئ': 'ъ',    // hamza on ye -> glottal stop
    'أ': 'а',    // alef with hamza above
    'إ': 'и',    // alef with hamza below
    'ؤ': 'ӯ',    // hamza on vav

    // Consonants
    'ب': 'б',    // be
    'پ': 'п',    // pe
    'ت': 'т',    // te
    'ث': 'с',    // se (Arabic th, pronounced as 's' in Tajiki)
    'ج': 'ҷ',    // jim -> j with descender
    'چ': 'ч',    // che
    'ح': 'ҳ',    // he (pharyngeal) -> h with descender
    'خ': 'х',    // khe
    'د': 'д',    // dal
    'ذ': 'з',    // zal (Arabic dh, pronounced as 'z' in Tajiki)
    'ر': 'р',    // re
    'ز': 'з',    // ze
    'ژ': 'ж',    // zhe
    'س': 'с',    // sin
    'ش': 'ш',    // shin
    'ص': 'с',    // sad (emphatic s, same as sin in Tajiki)
    'ض': 'з',    // zad (emphatic d, pronounced as 'z' in Tajiki)
    'ط': 'т',    // ta (emphatic t, same as te in Tajiki)
    'ظ': 'з',    // za (emphatic z)
    'ع': 'ъ',    // ain -> hard sign (glottal)
    'غ': 'ғ',    // ghain -> g with stroke
    'ف': 'ф',    // fe
    'ق': 'қ',    // qaf -> q with descender
    'ک': 'к',    // kaf
    'ك': 'к',    // Arabic kaf
    'گ': 'г',    // gaf
    'ل': 'л',    // lam
    'م': 'м',    // mim
    'ن': 'н',    // nun
    'ه': 'ҳ',    // he -> h with descender (or 'а' at end of words)
    'ھ': 'ҳ',    // do-chashmi he

    // Special characters
    'ء': 'ъ',    // hamza -> hard sign
    'ة': 'а',    // teh marbuta -> a
    'ى': 'ӣ',    // alef maksura -> i

    // Persian-specific
    'ـ': '',     // tatweel (kashida) - remove

    // Numerals (Persian to standard)
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',

    // Arabic numerals (in case they appear)
    '٠': '0',
    '٩': '9',
    '٨': '8',
    '٧': '7',
    '٦': '6',
    '٥': '5',
    '٤': '4',
    '٣': '3',
    '٢': '2',
    '١': '1',
  };

  /// Common word replacements for better Tajiki
  /// These handle cases where simple transliteration isn't enough
  static const Map<String, String> _wordMap = {
    // Common words that need special handling
    'است': 'аст',
    'این': 'ин',
    'آن': 'он',
    'که': 'ки',
    'را': 'ро',
    'از': 'аз',
    'به': 'ба',
    'در': 'дар',
    'با': 'бо',
    'برای': 'барои',
    'می': 'ме',
    'هم': 'ҳам',
    'یک': 'як',
    'دو': 'ду',
    'سه': 'се',
    'چهار': 'чор',
    'پنج': 'панҷ',
    'شش': 'шаш',
    'هفت': 'ҳафт',
    'هشت': 'ҳашт',
    'نه': 'нӯҳ',
    'ده': 'даҳ',
    'کتاب': 'китоб',
    'صوتی': 'садоӣ',
    'خانه': 'хона',
    'موسیقی': 'мусиқӣ',
    'کتابخانه': 'китобхона',
    'پروفایل': 'профил',
    'جستجو': 'ҷустуҷӯ',
    'تنظیمات': 'танзимот',
    'زبان': 'забон',
    'فارسی': 'форсӣ',
    'تاجیکی': 'тоҷикӣ',
    'انگلیسی': 'англисӣ',
    'ورود': 'ворид',
    'خروج': 'хуруҷ',
    'نام': 'ном',
    'رمز': 'рамз',
    'عبور': 'убур',
    'ایمیл': 'почта',
    'ثبت': 'сабт',
    'ثبت‌نام': 'сабтном',
    'گوینده': 'гӯянда',
    'نویسنده': 'нависанда',
    'داستان': 'достон',
    'رمان': 'роман',
    'شعر': 'шеър',
    'ساعت': 'соат',
    'دقیقه': 'дақиқа',
    'صفحه': 'саҳифа',
    'فصل': 'боб',
    'بخش': 'бахш',
    'قسمت': 'қисмат',
    'پخش': 'пахш',
    'دانلود': 'боргирӣ',
    'بارگذاری': 'боркунӣ',
    'خطا': 'хатогӣ',
    'موفق': 'муваффақ',
    'انجام': 'анҷом',
    'شروع': 'оғоз',
    'پایان': 'поён',
    'ادامه': 'идома',
    'توقف': 'истода',
    'بعدی': 'навбатӣ',
    'قبلی': 'қаблӣ',
    'همه': 'ҳама',
    'هیچ': 'ҳеҷ',
    'جدید': 'нав',
    'قدیمی': 'қадимӣ',
  };

  /// Convert Farsi text to Tajiki Cyrillic
  ///
  /// [text] - The Farsi/Persian text to convert
  /// Returns the text in Tajiki Cyrillic script
  static String convert(String? text) {
    if (text == null || text.isEmpty) return '';

    String result = text;

    // First, replace known words
    _wordMap.forEach((farsi, tajiki) {
      result = result.replaceAll(farsi, tajiki);
    });

    // Then, transliterate remaining characters
    final buffer = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final char = result[i];

      // Handle special cases for 'و' (vav)
      if (char == 'و') {
        // Check if it's at the start of a word or after certain consonants -> 'в'
        // Otherwise it's likely a vowel 'у' or 'ӯ'
        final prevChar = i > 0 ? result[i - 1] : '';

        if (prevChar == ' ' || prevChar.isEmpty || i == 0) {
          // Start of word - consonant 'в'
          buffer.write('в');
        } else if (_isVowel(prevChar)) {
          // After vowel - consonant 'в'
          buffer.write('в');
        } else {
          // After consonant - vowel 'ӯ'
          buffer.write('ӯ');
        }
        continue;
      }

      // Handle 'ه' at end of words (becomes 'а' not 'ҳ')
      if (char == 'ه' || char == 'ە') {
        final nextChar = i < result.length - 1 ? result[i + 1] : '';
        if (nextChar == ' ' || nextChar.isEmpty || i == result.length - 1) {
          buffer.write('а');
          continue;
        }
      }

      // Handle 'ی' based on position
      if (char == 'ی' || char == 'ي') {
        final prevChar = i > 0 ? result[i - 1] : '';
        final nextChar = i < result.length - 1 ? result[i + 1] : '';

        if (prevChar == ' ' || prevChar.isEmpty || i == 0) {
          // Start of word - 'й' or 'я'
          buffer.write('й');
        } else if (nextChar == ' ' || nextChar.isEmpty || i == result.length - 1) {
          // End of word - 'ӣ' (long i)
          buffer.write('ӣ');
        } else {
          // Middle of word
          buffer.write('и');
        }
        continue;
      }

      // Standard character mapping
      buffer.write(_charMap[char] ?? char);
    }

    return buffer.toString();
  }

  /// Check if a Farsi character is a vowel
  static bool _isVowel(String char) {
    return ['ا', 'آ', 'و', 'ی', 'ي', 'ە', 'ٰ'].contains(char);
  }

  /// Convert text based on current language setting
  /// If Tajiki is selected, converts Farsi to Cyrillic
  /// Otherwise returns the original text
  static String convertIfTajiki(String? text, bool isTajiki) {
    if (!isTajiki || text == null) return text ?? '';
    return convert(text);
  }
}
