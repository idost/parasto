import 'package:shared_preferences/shared_preferences.dart';
import 'package:myna/utils/farsi_to_tajiki.dart';
import 'package:myna/services/translation_service.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Supported languages in the app
enum AppLanguage {
  fa, // Farsi (Persian) - default
  en, // English
  tg, // Tajiki
}

/// Global translation service instance for async translations
TranslationService? _translationService;

/// Simple localization class - strings are loaded based on saved language preference
/// Language is selected on login screen and persists across sessions
class AppStrings {
  static const String _languageKey = 'app_language';

  // Current language - defaults to Farsi
  static AppLanguage _currentLanguage = AppLanguage.fa;

  static AppLanguage get currentLanguage => _currentLanguage;

  /// Check if current language is Tajiki
  static bool get isTajiki => _currentLanguage == AppLanguage.tg;

  /// Check if current language is English
  static bool get isEnglish => _currentLanguage == AppLanguage.en;

  /// Check if current language is Farsi (RTL)
  static bool get isFarsi => _currentLanguage == AppLanguage.fa;

  /// Check if current language uses LTR text direction (Tajiki, English)
  static bool get isLtr => _currentLanguage != AppLanguage.fa;

  /// Initialize translation service with Azure Translator API credentials
  /// Call this during app initialization if you want to use API translation
  /// [azureKey] - Azure Cognitive Services subscription key
  /// [azureRegion] - Azure region (e.g., 'eastus', 'westeurope')
  static void initializeTranslation(String azureKey, {String azureRegion = 'eastus'}) {
    _translationService = TranslationService();
    _translationService!.initialize(azureKey, azureRegion: azureRegion);
  }

  /// Convert dynamic Farsi text to current language.
  /// Uses phonetic transliteration for Tajiki (synchronous, fast).
  /// For API-based translation, use [localizeAsync] instead.
  ///
  /// Example:
  /// ```dart
  /// Text(AppStrings.localize(book.title))
  /// ```
  static String localize(String? text) {
    if (text == null || text.isEmpty) return '';
    if (_currentLanguage == AppLanguage.tg) {
      return FarsiToTajiki.convert(text);
    }
    // For English, return original Farsi (API translation needed for proper English)
    return text;
  }

  /// Async translation using API for better quality.
  /// Falls back to [localize] if translation service unavailable.
  ///
  /// Use this for important content like book titles and descriptions
  /// where translation quality matters.
  ///
  /// Example:
  /// ```dart
  /// final title = await AppStrings.localizeAsync(book.title);
  /// ```
  static Future<String> localizeAsync(String? text) async {
    if (text == null || text.isEmpty) return '';
    if (_currentLanguage == AppLanguage.fa) return text;

    // If translation service is available, use it
    if (_translationService != null) {
      final langCode = _currentLanguage == AppLanguage.tg ? 'tg' : 'en';
      return await _translationService!.translate(text, targetLang: langCode);
    }

    // Fallback to synchronous localize
    return localize(text);
  }

  /// Batch translate multiple texts asynchronously.
  /// More efficient than calling localizeAsync for each text.
  ///
  /// Example:
  /// ```dart
  /// final titles = await AppStrings.localizeBatch(books.map((b) => b.title).toList());
  /// ```
  static Future<List<String>> localizeBatch(List<String?> texts) async {
    if (_currentLanguage == AppLanguage.fa) {
      return texts.map((t) => t ?? '').toList();
    }

    // If translation service is available, use batch translation
    if (_translationService != null) {
      final langCode = _currentLanguage == AppLanguage.tg ? 'tg' : 'en';
      return await _translationService!.translateBatch(texts, targetLang: langCode);
    }

    // Fallback to synchronous localize
    return texts.map((t) => localize(t)).toList();
  }

  /// Load saved language from SharedPreferences
  /// Call this in main() BEFORE runApp()
  static Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageKey) ?? 'fa';
    _currentLanguage = _languageFromCode(code);
  }

  /// Save language preference
  static Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _languageToCode(language));
    _currentLanguage = language;
  }

  static AppLanguage _languageFromCode(String code) {
    switch (code) {
      case 'en':
        return AppLanguage.en;
      case 'tg':
        return AppLanguage.tg;
      default:
        return AppLanguage.fa;
    }
  }

  static String _languageToCode(AppLanguage language) {
    switch (language) {
      case AppLanguage.en:
        return 'en';
      case AppLanguage.tg:
        return 'tg';
      case AppLanguage.fa:
        return 'fa';
    }
  }

  /// Get display name for language selector
  static String getLanguageDisplayName(AppLanguage language) {
    switch (language) {
      case AppLanguage.fa:
        return 'فارسی';
      case AppLanguage.en:
        return 'English';
      case AppLanguage.tg:
        return 'Тоҷикӣ';
    }
  }

  // ============================================
  // APP STRINGS - Organized by screen/feature
  // ============================================

  // --- App Name ---
  static String get appName {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرستو';
      case AppLanguage.en:
        return 'Parasto';
      case AppLanguage.tg:
        return 'Парасту';
    }
  }

  // --- Navigation ---
  static String get home {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خانه';
      case AppLanguage.en:
        return 'Home';
      case AppLanguage.tg:
        return 'Хона';
    }
  }

  static String get music {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'موسیقی';
      case AppLanguage.en:
        return 'Music';
      case AppLanguage.tg:
        return 'Мусиқӣ';
    }
  }

  static String get podcasts {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پادکست‌ها';
      case AppLanguage.en:
        return 'Podcasts';
      case AppLanguage.tg:
        return 'Подкастҳо';
    }
  }

  static String get library {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتابخانه';
      case AppLanguage.en:
        return 'Library';
      case AppLanguage.tg:
        return 'Китобхона';
    }
  }

  static String get profile {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پروفایل';
      case AppLanguage.en:
        return 'Profile';
      case AppLanguage.tg:
        return 'Профил';
    }
  }

  static String get search {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جستجو';
      case AppLanguage.en:
        return 'Search';
      case AppLanguage.tg:
        return 'Ҷустуҷӯ';
    }
  }

  // --- Login Screen ---
  static String get appTagline {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'انیس کنج تنهایی';
      case AppLanguage.en:
        return 'Companion in solitude';
      case AppLanguage.tg:
        return 'Ҳамроҳи танҳоӣ';
    }
  }

  static String get email {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ایمیل';
      case AppLanguage.en:
        return 'Email';
      case AppLanguage.tg:
        return 'Почтаи электронӣ';
    }
  }

  static String get password {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رمز عبور';
      case AppLanguage.en:
        return 'Password';
      case AppLanguage.tg:
        return 'Рамз';
    }
  }

  static String get login {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ورود';
      case AppLanguage.en:
        return 'Login';
      case AppLanguage.tg:
        return 'Вуруд';
    }
  }

  static String get forgotPassword {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'فراموشی رمز عبور؟';
      case AppLanguage.en:
        return 'Forgot password?';
      case AppLanguage.tg:
        return 'Рамзро фаромӯш кардед?';
    }
  }

  static String get noAccount {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'حساب کاربری ندارید؟';
      case AppLanguage.en:
        return "Don't have an account?";
      case AppLanguage.tg:
        return 'Ҳисоб надоред?';
    }
  }

  static String get signUp {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ثبت نام';
      case AppLanguage.en:
        return 'Sign Up';
      case AppLanguage.tg:
        return 'Бақайдгирӣ';
    }
  }

  // --- Social Login ---
  static String get orContinueWith {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'یا ورود با';
      case AppLanguage.en:
        return 'Or continue with';
      case AppLanguage.tg:
        return 'Ё идома додан тавассути';
    }
  }

  static String get continueWithGoogle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ادامه با Google';
      case AppLanguage.en:
        return 'Continue with Google';
      case AppLanguage.tg:
        return 'Идома тавассути Google';
    }
  }

  static String get continueWithApple {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ادامه با Apple';
      case AppLanguage.en:
        return 'Continue with Apple';
      case AppLanguage.tg:
        return 'Идома тавассути Apple';
    }
  }

  static String get socialLoginError {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ورود ناموفق بود. دوباره تلاش کنید.';
      case AppLanguage.en:
        return 'Sign-in failed. Please try again.';
      case AppLanguage.tg:
        return 'Вуруд муваффақ нашуд. Дубора кӯшиш кунед.';
    }
  }

  static String get selectLanguage {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'انتخاب زبان';
      case AppLanguage.en:
        return 'Select Language';
      case AppLanguage.tg:
        return 'Интихоби забон';
    }
  }

  // --- Settings Screen ---
  static String get settings {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تنظیمات';
      case AppLanguage.en:
        return 'Settings';
      case AppLanguage.tg:
        return 'Танзимот';
    }
  }

  static String get playback {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پخش';
      case AppLanguage.en:
        return 'Playback';
      case AppLanguage.tg:
        return 'Пахш';
    }
  }

  static String get download {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'دانلود';
      case AppLanguage.en:
        return 'Download';
      case AppLanguage.tg:
        return 'Боргирӣ';
    }
  }

  static String get sleepTimer {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تایمر خواب';
      case AppLanguage.en:
        return 'Sleep Timer';
      case AppLanguage.tg:
        return 'Вақтсанҷи хоб';
    }
  }

  static String get about {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'درباره';
      case AppLanguage.en:
        return 'About';
      case AppLanguage.tg:
        return 'Дар бораи';
    }
  }

  static String get appVersion {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نسخه برنامه';
      case AppLanguage.en:
        return 'App Version';
      case AppLanguage.tg:
        return 'Нусхаи барнома';
    }
  }

  static String get playbackSpeed {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'سرعت پخش';
      case AppLanguage.en:
        return 'Playback Speed';
      case AppLanguage.tg:
        return 'Суръати пахш';
    }
  }

  static String get defaultPlaybackSpeed {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'سرعت پخش پیش‌فرض';
      case AppLanguage.en:
        return 'Default Playback Speed';
      case AppLanguage.tg:
        return 'Суръати пахши пешфарз';
    }
  }

  static String get autoPlayNext {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پخش خودکار فصل بعدی';
      case AppLanguage.en:
        return 'Auto-play Next Chapter';
      case AppLanguage.tg:
        return 'Пахши худкори боби навбатӣ';
    }
  }

  static String get autoPlayNextSubtitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بعد از تمام شدن هر فصل، فصل بعدی شروع شود';
      case AppLanguage.en:
        return 'Automatically play the next chapter when current one ends';
      case AppLanguage.tg:
        return 'Пас аз анҷоми боби ҷорӣ, боби навбатӣ шурӯъ шавад';
    }
  }

  static String get skipSilence {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رد کردن سکوت‌ها';
      case AppLanguage.en:
        return 'Skip Silence';
      case AppLanguage.tg:
        return 'Гузаштан аз хомӯшӣ';
    }
  }

  static String get skipSilenceSubtitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'قسمت‌های بی‌صدا را رد کن';
      case AppLanguage.en:
        return 'Skip silent parts in audio';
      case AppLanguage.tg:
        return 'Қисмҳои бесадоро гузаронед';
    }
  }

  static String get boostVolume {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تقویت صدا';
      case AppLanguage.en:
        return 'Volume Boost';
      case AppLanguage.tg:
        return 'Баландкунии овоз';
    }
  }

  static String get boostVolumeSubtitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'افزایش میزان صدا در محتوای کم‌صدا';
      case AppLanguage.en:
        return 'Boost volume for quiet content';
      case AppLanguage.tg:
        return 'Баландкунии овоз барои мундариҷаи камсадо';
    }
  }

  static String get downloadWifiOnly {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'دانلود فقط با وای‌فای';
      case AppLanguage.en:
        return 'Download on Wi-Fi Only';
      case AppLanguage.tg:
        return 'Боргирӣ танҳо бо Wi-Fi';
    }
  }

  static String get downloadWifiOnlySubtitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'برای صرفه‌جویی در مصرف دیتا';
      case AppLanguage.en:
        return 'Save mobile data by downloading only on Wi-Fi';
      case AppLanguage.tg:
        return 'Барои сарфаи трафики мобилӣ';
    }
  }

  static String get defaultSleepTimer {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تایمر خواب پیش‌فرض';
      case AppLanguage.en:
        return 'Default Sleep Timer';
      case AppLanguage.tg:
        return 'Вақтсанҷи хоби пешфарз';
    }
  }

  // --- Timer Options ---
  static String get off {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خاموش';
      case AppLanguage.en:
        return 'Off';
      case AppLanguage.tg:
        return 'Хомӯш';
    }
  }

  static String get minutes15 {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '۱۵ دقیقه';
      case AppLanguage.en:
        return '15 minutes';
      case AppLanguage.tg:
        return '15 дақиқа';
    }
  }

  static String get minutes30 {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '۳۰ دقیقه';
      case AppLanguage.en:
        return '30 minutes';
      case AppLanguage.tg:
        return '30 дақиқа';
    }
  }

  static String get minutes45 {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '۴۵ دقیقه';
      case AppLanguage.en:
        return '45 minutes';
      case AppLanguage.tg:
        return '45 дақиқа';
    }
  }

  static String get hour1 {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '۱ ساعت';
      case AppLanguage.en:
        return '1 hour';
      case AppLanguage.tg:
        return '1 соат';
    }
  }

  static String get hour1_5 {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '۱.۵ ساعت';
      case AppLanguage.en:
        return '1.5 hours';
      case AppLanguage.tg:
        return '1.5 соат';
    }
  }

  static String get hours2 {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '۲ ساعت';
      case AppLanguage.en:
        return '2 hours';
      case AppLanguage.tg:
        return '2 соат';
    }
  }

  // --- Skip Interval Settings ---
  static String get skipForwardInterval {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بازه جلو رفتن';
      case AppLanguage.en:
        return 'Skip Forward Interval';
      case AppLanguage.tg:
        return 'Фосилаи пеш рафтан';
    }
  }

  static String get skipBackwardInterval {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بازه عقب رفتن';
      case AppLanguage.en:
        return 'Skip Backward Interval';
      case AppLanguage.tg:
        return 'Фосилаи ақиб рафтан';
    }
  }

  static String nSeconds(int n) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '$n ثانیه';
      case AppLanguage.en:
        return '$n seconds';
      case AppLanguage.tg:
        return '$n сония';
    }
  }

  static String get storageUsed {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'حجم دانلودها';
      case AppLanguage.en:
        return 'Storage Used';
      case AppLanguage.tg:
        return 'Ҳаҷми боргирӣ';
    }
  }

  static String get noDownloads {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بدون دانلود';
      case AppLanguage.en:
        return 'No downloads';
      case AppLanguage.tg:
        return 'Бе боргирӣ';
    }
  }

  // --- Content Preferences ---
  static String get contentPreferences {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نوع محتوا';
      case AppLanguage.en:
        return 'Content Types';
      case AppLanguage.tg:
        return 'Навъи мундариҷа';
    }
  }

  static String get showAudiobooksLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌های صوتی';
      case AppLanguage.en:
        return 'Audiobooks';
      case AppLanguage.tg:
        return 'Китобҳои аудиоӣ';
    }
  }

  static String get showPodcastsLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پادکست‌ها';
      case AppLanguage.en:
        return 'Podcasts';
      case AppLanguage.tg:
        return 'Подкастҳо';
    }
  }

  static String get showArticlesLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مقاله‌ها';
      case AppLanguage.en:
        return 'Articles';
      case AppLanguage.tg:
        return 'Мақолаҳо';
    }
  }

  static String get showMusicLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'موسیقی';
      case AppLanguage.en:
        return 'Music';
      case AppLanguage.tg:
        return 'Мусиқӣ';
    }
  }

  static String get contentPrefsSubtitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نمایش در صفحه اصلی';
      case AppLanguage.en:
        return 'Show on home screen';
      case AppLanguage.tg:
        return 'Нишон додан дар саҳифаи асосӣ';
    }
  }

  // --- Appearance Settings ---
  static String get appearance {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نمایش';
      case AppLanguage.en:
        return 'Appearance';
      case AppLanguage.tg:
        return 'Намоиш';
    }
  }

  static String get themeMode {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'حالت نمایش';
      case AppLanguage.en:
        return 'Theme';
      case AppLanguage.tg:
        return 'Мавзӯъ';
    }
  }

  static String get themeDark {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تاریک';
      case AppLanguage.en:
        return 'Dark';
      case AppLanguage.tg:
        return 'Торик';
    }
  }

  static String get themeLight {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'روشن';
      case AppLanguage.en:
        return 'Light';
      case AppLanguage.tg:
        return 'Равшан';
    }
  }

  static String get themeSystem {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'سیستم';
      case AppLanguage.en:
        return 'System';
      case AppLanguage.tg:
        return 'Системавӣ';
    }
  }

  // --- Common Actions ---
  static String get cancel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'انصراف';
      case AppLanguage.en:
        return 'Cancel';
      case AppLanguage.tg:
        return 'Бекор';
    }
  }

  static String get confirm {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تایید';
      case AppLanguage.en:
        return 'Confirm';
      case AppLanguage.tg:
        return 'Тасдиқ';
    }
  }

  static String get save {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ذخیره';
      case AppLanguage.en:
        return 'Save';
      case AppLanguage.tg:
        return 'Захира';
    }
  }

  static String get delete {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'حذف';
      case AppLanguage.en:
        return 'Delete';
      case AppLanguage.tg:
        return 'Нест кардан';
    }
  }

  static String get edit {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ویرایش';
      case AppLanguage.en:
        return 'Edit';
      case AppLanguage.tg:
        return 'Таҳрир';
    }
  }

  static String get retry {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تلاش مجدد';
      case AppLanguage.en:
        return 'Retry';
      case AppLanguage.tg:
        return 'Такрор';
    }
  }

  // --- Error Messages ---
  static String loginError(String error) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خطا در ورود: $error';
      case AppLanguage.en:
        return 'Login error: $error';
      case AppLanguage.tg:
        return 'Хатогии вуруд: $error';
    }
  }

  static String get networkError {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خطا در اتصال به اینترنت';
      case AppLanguage.en:
        return 'Network connection error';
      case AppLanguage.tg:
        return 'Хатогии пайвастшавӣ ба интернет';
    }
  }

  // --- Validation Messages ---
  static String get emailRequired {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ایمیل الزامی است';
      case AppLanguage.en:
        return 'Email is required';
      case AppLanguage.tg:
        return 'Почтаи электронӣ лозим аст';
    }
  }

  static String get invalidEmail {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ایمیل نامعتبر است';
      case AppLanguage.en:
        return 'Invalid email address';
      case AppLanguage.tg:
        return 'Почтаи электронӣ нодуруст аст';
    }
  }

  static String get passwordRequired {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رمز عبور الزامی است';
      case AppLanguage.en:
        return 'Password is required';
      case AppLanguage.tg:
        return 'Рамз лозим аст';
    }
  }

  static String fieldRequired(String fieldName) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '$fieldName الزامی است';
      case AppLanguage.en:
        return '$fieldName is required';
      case AppLanguage.tg:
        return '$fieldName лозим аст';
    }
  }

  // --- Notifications ---
  static String get notifications {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'اعلان‌ها';
      case AppLanguage.en:
        return 'Notifications';
      case AppLanguage.tg:
        return 'Огоҳиҳо';
    }
  }

  static String get comingSoon {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'به زودی...';
      case AppLanguage.en:
        return 'Coming Soon...';
      case AppLanguage.tg:
        return 'Ба наздикӣ...';
    }
  }

  // --- Profile Screen ---
  static String get editProfile {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ویرایش پروفایل';
      case AppLanguage.en:
        return 'Edit Profile';
      case AppLanguage.tg:
        return 'Таҳрири профил';
    }
  }

  static String get downloads {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'دانلودها';
      case AppLanguage.en:
        return 'Downloads';
      case AppLanguage.tg:
        return 'Боргириҳо';
    }
  }

  static String get support {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پشتیبانی';
      case AppLanguage.en:
        return 'Support';
      case AppLanguage.tg:
        return 'Дастгирӣ';
    }
  }

  static String get help {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'راهنما';
      case AppLanguage.en:
        return 'Help';
      case AppLanguage.tg:
        return 'Роҳнамо';
    }
  }

  static String get aboutUs {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'درباره ما';
      case AppLanguage.en:
        return 'About Us';
      case AppLanguage.tg:
        return 'Дар бораи мо';
    }
  }

  static String get logout {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خروج از حساب';
      case AppLanguage.en:
        return 'Log Out';
      case AppLanguage.tg:
        return 'Баромадан';
    }
  }

  static String get user {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کاربر';
      case AppLanguage.en:
        return 'User';
      case AppLanguage.tg:
        return 'Корбар';
    }
  }

  static String get listeningStats {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'آمار گوش دادن';
      case AppLanguage.en:
        return 'Listening Stats';
      case AppLanguage.tg:
        return 'Омори гӯшкунӣ';
    }
  }

  static String get totalTime {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'زمان کل';
      case AppLanguage.en:
        return 'Total Time';
      case AppLanguage.tg:
        return 'Вақти умумӣ';
    }
  }

  static String get activeDays {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'روز فعال';
      case AppLanguage.en:
        return 'Active Days';
      case AppLanguage.tg:
        return 'Рӯзҳои фаъол';
    }
  }

  static String get consecutiveDays {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'روز متوالی';
      case AppLanguage.en:
        return 'Streak';
      case AppLanguage.tg:
        return 'Рӯзҳои пайдарпай';
    }
  }

  static String longestStreak(int days) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بیشترین: ${FarsiUtils.toFarsiDigits(days)} روز متوالی';
      case AppLanguage.en:
        return 'Longest: $days days streak';
      case AppLanguage.tg:
        return 'Зиёдтарин: $days рӯзи пайдарпай';
    }
  }

  static String booksCompleted(int count) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '${FarsiUtils.toFarsiDigits(count)} کتاب تمام شده';
      case AppLanguage.en:
        return '$count books completed';
      case AppLanguage.tg:
        return '$count китоб анҷом шуд';
    }
  }

  static String get achievements {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'دستاوردها';
      case AppLanguage.en:
        return 'Achievements';
      case AppLanguage.tg:
        return 'Дастовардҳо';
    }
  }

  static String get becomeNarrator {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'گوینده شوید';
      case AppLanguage.en:
        return 'Become a Narrator';
      case AppLanguage.tg:
        return 'Гӯянда шавед';
    }
  }

  static String get becomeNarratorSubtitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'صدای خود را به دنیا بشنوانید';
      case AppLanguage.en:
        return 'Share your voice with the world';
      case AppLanguage.tg:
        return 'Садои худро ба ҷаҳон бирасонед';
    }
  }

  static String get narratorRequest {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'درخواست گویندگی';
      case AppLanguage.en:
        return 'Narrator Request';
      case AppLanguage.tg:
        return 'Дархости гӯяндагӣ';
    }
  }

  static String get goToNarratorDashboard {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رفتن به داشبورد راوی';
      case AppLanguage.en:
        return 'Go to Narrator Dashboard';
      case AppLanguage.tg:
        return 'Ба дошбурди гӯянда равед';
    }
  }

  // --- Home Screen ---
  static String get continueListening {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ادامه گوش دادن';
      case AppLanguage.en:
        return 'Continue Listening';
      case AppLanguage.tg:
        return 'Идома додани гӯшкунӣ';
    }
  }

  static String get recentlyPlayed {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'اخیراً شنیده شده';
      case AppLanguage.en:
        return 'Recently Played';
      case AppLanguage.tg:
        return 'Охирин гӯш дода шуда';
    }
  }

  static String get newBooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جدیدترین کتاب‌ها';
      case AppLanguage.en:
        return 'New Books';
      case AppLanguage.tg:
        return 'Китобҳои нав';
    }
  }

  static String get featuredBooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پیشنهاد کتاب‌ها';
      case AppLanguage.en:
        return 'Featured Books';
      case AppLanguage.tg:
        return 'Китобҳои пешниҳодшуда';
    }
  }

  static String get popularBooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرشنونده‌ترین کتاب‌ها';
      case AppLanguage.en:
        return 'Popular Books';
      case AppLanguage.tg:
        return 'Китобҳои маъмултарин';
    }
  }

  static String get audiobooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌های صوتی';
      case AppLanguage.en:
        return 'Audiobooks';
      case AppLanguage.tg:
        return 'Китобҳои аудиоӣ';
    }
  }

  static String get bookstore {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌فروشی';
      case AppLanguage.en:
        return 'Bookstore';
      case AppLanguage.tg:
        return 'Китобфурӯшӣ';
    }
  }

  static String get subscriptionExpiredLockMessage {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'اشتراک شما منقضی شده. برای دسترسی به محتوا اشتراک تهیه کنید.';
      case AppLanguage.en:
        return 'Your subscription has expired. Subscribe to access content.';
      case AppLanguage.tg:
        return 'Иштироки шумо ба охир расидааст. Барои дастрасӣ ба мӯҳтаво иштирок кунед.';
    }
  }

  static String get categories {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'دسته‌بندی‌ها';
      case AppLanguage.en:
        return 'Categories';
      case AppLanguage.tg:
        return 'Гурӯҳҳо';
    }
  }

  static String get seeAll {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مشاهده همه';
      case AppLanguage.en:
        return 'See All';
      case AppLanguage.tg:
        return 'Ҳамаро дидан';
    }
  }

  static String get yourListeningStats {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'آمار گوش دادن شما';
      case AppLanguage.en:
        return 'Your Listening Stats';
      case AppLanguage.tg:
        return 'Омори гӯшкунии шумо';
    }
  }

  static String get startListening {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'شروع کنید!';
      case AppLanguage.en:
        return 'Start Listening!';
      case AppLanguage.tg:
        return 'Оғоз кунед!';
    }
  }

  static String get startListeningMessage {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'اولین کتاب صوتی را انتخاب کنید و به دنیای شنیداری بپیوندید!';
      case AppLanguage.en:
        return 'Choose your first audiobook and join the world of listening!';
      case AppLanguage.tg:
        return 'Китоби овозии аввалинро интихоб кунед ва ба ҷаҳони шунидан ҳамроҳ шавед!';
    }
  }

  static String get listeningTime {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'زمان گوش دادن';
      case AppLanguage.en:
        return 'Listening Time';
      case AppLanguage.tg:
        return 'Вақти гӯшкунӣ';
    }
  }

  static String get booksFinished {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب تمام شده';
      case AppLanguage.en:
        return 'Books Finished';
      case AppLanguage.tg:
        return 'Китобҳои анҷомшуда';
    }
  }

  static String get streakRecord {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رکورد متوالی';
      case AppLanguage.en:
        return 'Streak Record';
      case AppLanguage.tg:
        return 'Рӯзҳои пайдарҳам';
    }
  }

  static String streakDays(int days) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '${FarsiUtils.toFarsiDigits(days)} روز';
      case AppLanguage.en:
        return '$days days';
      case AppLanguage.tg:
        return '$days рӯз';
    }
  }

  static String get progress {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پیشرفت';
      case AppLanguage.en:
        return 'Progress';
      case AppLanguage.tg:
        return 'Пешрафт';
    }
  }

  static String get remaining {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'باقی‌مانده';
      case AppLanguage.en:
        return 'Remaining';
      case AppLanguage.tg:
        return 'Боқимонда';
    }
  }

  static String get continueButton {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ادامه';
      case AppLanguage.en:
        return 'Continue';
      case AppLanguage.tg:
        return 'Идома';
    }
  }

  static String get free {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رایگان';
      case AppLanguage.en:
        return 'Free';
      case AppLanguage.tg:
        return 'Ройгон';
    }
  }

  static String get musicLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'موسیقی';
      case AppLanguage.en:
        return 'Music';
      case AppLanguage.tg:
        return 'Мусиқӣ';
    }
  }

  /// Singular content-type labels for micro badges on cover images
  static String get podcastLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پادکست';
      case AppLanguage.en:
        return 'Podcast';
      case AppLanguage.tg:
        return 'Подкаст';
    }
  }

  static String get articleLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مقاله';
      case AppLanguage.en:
        return 'Article';
      case AppLanguage.tg:
        return 'Мақола';
    }
  }

  static String get bookLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب';
      case AppLanguage.en:
        return 'Book';
      case AppLanguage.tg:
        return 'Китоб';
    }
  }

  static String get audiobookLabel {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌گویا';
      case AppLanguage.en:
        return 'Audiobook';
      case AppLanguage.tg:
        return 'Китоби аудиоӣ';
    }
  }

  // --- Library Screen ---
  static String get myBooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌های من';
      case AppLanguage.en:
        return 'My Books';
      case AppLanguage.tg:
        return 'Китобҳои ман';
    }
  }

  static String get myMusic {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'موسیقی من';
      case AppLanguage.en:
        return 'My Music';
      case AppLanguage.tg:
        return 'Мусиқии ман';
    }
  }

  static String get myPodcasts {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پادکست‌های من';
      case AppLanguage.en:
        return 'My Podcasts';
      case AppLanguage.tg:
        return 'Подкастҳои ман';
    }
  }

  /// Podcast host (میزبان) - the person who presents/hosts the podcast
  static String get podcastHost {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'میزبان';
      case AppLanguage.en:
        return 'Host';
      case AppLanguage.tg:
        return 'Мизбон';
    }
  }

  /// Podcast presenter (مجری) - alternative term for host
  static String get podcastPresenter {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مجری';
      case AppLanguage.en:
        return 'Presenter';
      case AppLanguage.tg:
        return 'Муҷрӣ';
    }
  }

  /// "By host" label for podcasts (equivalent to "By author" for books)
  static String get byHost {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'میزبان:';
      case AppLanguage.en:
        return 'Host:';
      case AppLanguage.tg:
        return 'Мизбон:';
    }
  }

  /// New podcast label
  static String get newPodcasts {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پادکست‌های جدید';
      case AppLanguage.en:
        return 'New Podcasts';
      case AppLanguage.tg:
        return 'Подкастҳои нав';
    }
  }

  /// Popular podcasts label
  static String get popularPodcasts {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرشنونده‌ترین پادکست‌ها';
      case AppLanguage.en:
        return 'Popular Podcasts';
      case AppLanguage.tg:
        return 'Подкастҳои маъмул';
    }
  }

  // ============================================
  // ARTICLE STRINGS (مقاله)
  // ============================================

  static String get articles {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مقاله‌ها';
      case AppLanguage.en:
        return 'Articles';
      case AppLanguage.tg:
        return 'Мақолаҳо';
    }
  }

  static String get myArticles {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مقاله‌های من';
      case AppLanguage.en:
        return 'My Articles';
      case AppLanguage.tg:
        return 'Мақолаҳои ман';
    }
  }

  static String get newArticles {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مقاله‌های جدید';
      case AppLanguage.en:
        return 'New Articles';
      case AppLanguage.tg:
        return 'Мақолаҳои нав';
    }
  }

  static String get popularArticles {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرشنونده‌ترین مقاله‌ها';
      case AppLanguage.en:
        return 'Popular Articles';
      case AppLanguage.tg:
        return 'Мақолаҳои маъмул';
    }
  }

  static String get noArticlesYet {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'هنوز مقاله‌ای خریداری نکرده‌اید';
      case AppLanguage.en:
        return 'No articles purchased yet';
      case AppLanguage.tg:
        return 'Ҳанӯз мақолае нахаридаед';
    }
  }

  static String get articlesWillAppearHere {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مقاله‌های خریداری شده اینجا نمایش داده می‌شوند';
      case AppLanguage.en:
        return 'Purchased articles will appear here';
      case AppLanguage.tg:
        return 'Мақолаҳои харидашуда дар ин ҷо пайдо мешаванд';
    }
  }

  static String get searchArticles {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جستجوی مقاله';
      case AppLanguage.en:
        return 'Search Articles';
      case AppLanguage.tg:
        return 'Ҷустуҷӯи мақола';
    }
  }

  /// Article narrator (گوینده مقاله)
  static String get articleNarrator {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'گوینده';
      case AppLanguage.en:
        return 'Narrator';
      case AppLanguage.tg:
        return 'Гӯянда';
    }
  }

  static String get wishlist {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'علاقه‌مندی';
      case AppLanguage.en:
        return 'Wishlist';
      case AppLanguage.tg:
        return 'Рӯйхати дӯстдошта';
    }
  }

  static String get books {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌ها';
      case AppLanguage.en:
        return 'Books';
      case AppLanguage.tg:
        return 'Китобҳо';
    }
  }

  static String get all {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'همه';
      case AppLanguage.en:
        return 'All';
      case AppLanguage.tg:
        return 'Ҳама';
    }
  }

  static String get notStarted {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'شروع نشده';
      case AppLanguage.en:
        return 'Not Started';
      case AppLanguage.tg:
        return 'Оғоз нашуда';
    }
  }

  static String get inProgress {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'در حال گوش دادن';
      case AppLanguage.en:
        return 'In Progress';
      case AppLanguage.tg:
        return 'Дар ҷараён';
    }
  }

  static String get finished {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تمام شده';
      case AppLanguage.en:
        return 'Finished';
      case AppLanguage.tg:
        return 'Анҷом шуда';
    }
  }

  static String get sortByRecentlyPlayed {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'آخرین پخش شده';
      case AppLanguage.en:
        return 'Recently Played';
      case AppLanguage.tg:
        return 'Охирин пахш шуда';
    }
  }

  static String get sortByTitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'عنوان (الف-ی)';
      case AppLanguage.en:
        return 'Title (A-Z)';
      case AppLanguage.tg:
        return 'Унвон (А-Я)';
    }
  }

  static String get sortByDateAdded {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'تاریخ اضافه شدن';
      case AppLanguage.en:
        return 'Date Added';
      case AppLanguage.tg:
        return 'Санаи илова';
    }
  }

  static String get sortByDuration {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'مدت زمان';
      case AppLanguage.en:
        return 'Duration';
      case AppLanguage.tg:
        return 'Давомнокӣ';
    }
  }

  static String get searchInLibrary {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جستجو در کتابخانه...';
      case AppLanguage.en:
        return 'Search in library...';
      case AppLanguage.tg:
        return 'Ҷустуҷӯ дар китобхона...';
    }
  }

  static String get listView {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نمایش لیستی';
      case AppLanguage.en:
        return 'List View';
      case AppLanguage.tg:
        return 'Намоиши рӯйхат';
    }
  }

  static String get gridView {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نمایش شبکه‌ای';
      case AppLanguage.en:
        return 'Grid View';
      case AppLanguage.tg:
        return 'Намоиши шабака';
    }
  }

  static String get noBooksYet {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'هنوز کتابی خریداری نکرده‌اید';
      case AppLanguage.en:
        return 'No books purchased yet';
      case AppLanguage.tg:
        return 'Ҳанӯз китобе нахаридаед';
    }
  }

  static String get noMusicYet {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'هنوز موسیقی خریداری نکرده‌اید';
      case AppLanguage.en:
        return 'No music purchased yet';
      case AppLanguage.tg:
        return 'Ҳанӯз мусиқие нахаридаед';
    }
  }

  static String get noPodcastsYet {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'هنوز پادکستی خریداری نکرده‌اید';
      case AppLanguage.en:
        return 'No podcasts purchased yet';
      case AppLanguage.tg:
        return 'Ҳанӯз подкасте нахаридаед';
    }
  }

  static String get booksWillAppearHere {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌های خریداری شده اینجا نمایش داده می‌شوند';
      case AppLanguage.en:
        return 'Purchased books will appear here';
      case AppLanguage.tg:
        return 'Китобҳои харидашуда дар ин ҷо пайдо мешаванд';
    }
  }

  static String get musicWillAppearHere {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'موسیقی‌های خریداری شده اینجا نمایش داده می‌شوند';
      case AppLanguage.en:
        return 'Purchased music will appear here';
      case AppLanguage.tg:
        return 'Мусиқиҳои харидашуда дар ин ҷо пайдо мешаванд';
    }
  }

  static String get podcastsWillAppearHere {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پادکست‌های خریداری شده اینجا نمایش داده می‌شوند';
      case AppLanguage.en:
        return 'Purchased podcasts will appear here';
      case AppLanguage.tg:
        return 'Подкастҳои харидашуда дар ин ҷо пайдо мешаванд';
    }
  }

  static String get searchBooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جستجوی کتاب';
      case AppLanguage.en:
        return 'Search Books';
      case AppLanguage.tg:
        return 'Ҷустуҷӯи китоб';
    }
  }

  static String get searchPodcasts {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جستجوی پادکست';
      case AppLanguage.en:
        return 'Search Podcasts';
      case AppLanguage.tg:
        return 'Ҷустуҷӯи подкаст';
    }
  }

  static String get searchMusic {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'جستجوی موسیقی';
      case AppLanguage.en:
        return 'Search Music';
      case AppLanguage.tg:
        return 'Ҷустуҷӯи мусиқӣ';
    }
  }

  static String get noResults {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نتیجه‌ای یافت نشد';
      case AppLanguage.en:
        return 'No results found';
      case AppLanguage.tg:
        return 'Натиҷае ёфт нашуд';
    }
  }

  static String searchQuery(String query) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'عبارت جستجو: "$query"';
      case AppLanguage.en:
        return 'Search query: "$query"';
      case AppLanguage.tg:
        return 'Дархости ҷустуҷӯ: "$query"';
    }
  }

  static String chapterOf(int current, int total) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'فصل $current از $total';
      case AppLanguage.en:
        return 'Chapter $current of $total';
      case AppLanguage.tg:
        return 'Боби $current аз $total';
    }
  }

  static String trackOf(int current, int total) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'قطعه $current از $total';
      case AppLanguage.en:
        return 'Track $current of $total';
      case AppLanguage.tg:
        return 'Оҳанги $current аз $total';
    }
  }

  static String chapters(int count) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '${FarsiUtils.toFarsiDigits(count)} فصل';
      case AppLanguage.en:
        return '$count chapters';
      case AppLanguage.tg:
        return '$count боб';
    }
  }

  static String tracks(int count) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '${FarsiUtils.toFarsiDigits(count)} قطعه';
      case AppLanguage.en:
        return '$count tracks';
      case AppLanguage.tg:
        return '$count оҳанг';
    }
  }

  static String get wishlistEmpty {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'لیست علاقه‌مندی خالی است';
      case AppLanguage.en:
        return 'Wishlist is empty';
      case AppLanguage.tg:
        return 'Рӯйхати дӯстдошта холӣ аст';
    }
  }

  static String get addBooksToWishlist {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌های مورد علاقه را به این لیست اضافه کنید';
      case AppLanguage.en:
        return 'Add your favorite books to this list';
      case AppLanguage.tg:
        return 'Китобҳои дӯстдоштаро ба ин рӯйхат илова кунед';
    }
  }

  static String get addMusicToWishlist {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'موسیقی‌های مورد علاقه را به این لیست اضافه کنید';
      case AppLanguage.en:
        return 'Add your favorite music to this list';
      case AppLanguage.tg:
        return 'Мусиқиҳои дӯстдоштаро ба ин рӯйхат илова кунед';
    }
  }

  static String get tapHeartToAdd {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'روی آیکون قلب در صفحه کتاب کلیک کنید تا به لیست اضافه شود';
      case AppLanguage.en:
        return 'Tap the heart icon on book page to add to this list';
      case AppLanguage.tg:
        return 'Ба нишони дил дар саҳифаи китоб занед, то ба рӯйхат илова шавад';
    }
  }

  static String get exploreBooks {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کاوش کتاب‌ها';
      case AppLanguage.en:
        return 'Explore Books';
      case AppLanguage.tg:
        return 'Кашфи китобҳо';
    }
  }

  static String get exploreMusic {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کاوش موسیقی‌ها';
      case AppLanguage.en:
        return 'Explore Music';
      case AppLanguage.tg:
        return 'Кашфи мусиқӣ';
    }
  }

  static String get create {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ایجاد';
      case AppLanguage.en:
        return 'Create';
      case AppLanguage.tg:
        return 'Эҷод';
    }
  }

  static String items(int count) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return '$count مورد';
      case AppLanguage.en:
        return '$count items';
      case AppLanguage.tg:
        return '$count мавод';
    }
  }

  // --- Errors ---
  static String errorLoading(String item) {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خطا در بارگذاری $item';
      case AppLanguage.en:
        return 'Error loading $item';
      case AppLanguage.tg:
        return 'Хатогии боркунии $item';
    }
  }

  static String get errorLoadingLibrary {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خطا در بارگذاری کتابخانه';
      case AppLanguage.en:
        return 'Error loading library';
      case AppLanguage.tg:
        return 'Хатогии боркунии китобхона';
    }
  }

  static String get errorLoadingMusic {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خطا در بارگذاری موسیقی';
      case AppLanguage.en:
        return 'Error loading music';
      case AppLanguage.tg:
        return 'Хатогии боркунии мусиқӣ';
    }
  }

  static String get errorLoadingWishlist {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خطا در بارگذاری لیست علاقه‌مندی';
      case AppLanguage.en:
        return 'Error loading wishlist';
      case AppLanguage.tg:
        return 'Хатогии боркунии рӯйхати дӯстдошта';
    }
  }

  // --- Close/Dismiss ---
  static String get close {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بستن';
      case AppLanguage.en:
        return 'Close';
      case AppLanguage.tg:
        return 'Пӯшидан';
    }
  }

  // --- About Dialog ---
  static String get version {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'نسخه';
      case AppLanguage.en:
        return 'Version';
      case AppLanguage.tg:
        return 'Нусха';
    }
  }

  static String get audioBookApp {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'اپلیکیشن کتاب صوتی فارسی';
      case AppLanguage.en:
        return 'Persian Audiobook App';
      case AppLanguage.tg:
        return 'Барномаи китобҳои садоии форсӣ';
    }
  }

  // --- Purchase / Buy Screen ---
  static String get addToLibrary {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'افزودن';
      case AppLanguage.en:
        return 'Add';
      case AppLanguage.tg:
        return 'Илова';
    }
  }

  static String get buy {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خرید';
      case AppLanguage.en:
        return 'Buy';
      case AppLanguage.tg:
        return 'Харидан';
    }
  }

  static String get purchaseOnceForever {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'یک‌بار خرید، برای همیشه';
      case AppLanguage.en:
        return 'Buy once, own forever';
      case AppLanguage.tg:
        return 'Як бор харед, барои ҳамеша';
    }
  }

  static String get subscribe {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'اشتراک';
      case AppLanguage.en:
        return 'Subscribe';
      case AppLanguage.tg:
        return 'Обуна';
    }
  }

  static String get freeWithActiveSubscription {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'رایگان با اشتراک فعال';
      case AppLanguage.en:
        return 'Free with active subscription';
      case AppLanguage.tg:
        return 'Ройгон бо обунаи фаъол';
    }
  }

  static String get iapUnavailable {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خرید درون‌برنامه‌ای در دسترس نیست. لطفاً بعداً تلاش کنید.';
      case AppLanguage.en:
        return 'In-app purchases are not available. Please try again later.';
      case AppLanguage.tg:
        return 'Хариди дарун-барномавӣ дастрас нест. Лутфан баъдтар кӯшиш кунед.';
    }
  }

  static String get purchaseSuccess {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خرید با موفقیت انجام شد!';
      case AppLanguage.en:
        return 'Purchase successful!';
      case AppLanguage.tg:
        return 'Харид бомуваффақият анҷом шуд!';
    }
  }

  static String get play {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پخش';
      case AppLanguage.en:
        return 'Play';
      case AppLanguage.tg:
        return 'Пахш';
    }
  }

  static String get listen {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'گوش دادن';
      case AppLanguage.en:
        return 'Listen';
      case AppLanguage.tg:
        return 'Гӯш додан';
    }
  }

  // --- About Parasto ---
  static String get aboutParasto {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'درباره پرستو';
      case AppLanguage.en:
        return 'About Parasto';
      case AppLanguage.tg:
        return 'Дар бораи Парасту';
    }
  }

  static String get parastaAppName {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب‌خوان پرستو';
      case AppLanguage.en:
        return 'Parasto Audiobook';
      case AppLanguage.tg:
        return 'Китобхони Парасту';
    }
  }

  static String get parastoTagline {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'کتاب صوتی، موسیقی و پادکست فارسی';
      case AppLanguage.en:
        return 'Persian Audiobooks, Music & Podcasts';
      case AppLanguage.tg:
        return 'Китоби садоӣ, мусиқӣ ва подкасти форсӣ';
    }
  }

  static String get aboutParastoTitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرستو';
      case AppLanguage.en:
        return 'Parasto';
      case AppLanguage.tg:
        return 'Парасту';
    }
  }

  static String get aboutParastoContent {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرستو نام پرنده‌ای کوچک با پشت تیره و شکمی روشن و نوکی نارنجی‌رنگ است که در فرهنگ‌های گوناگون نماد بهار، تجدید حیات و خوش‌شانسی به‌شمار می‌رود. این پرنده در میان فارسی‌زبانان افغانستان با نام «غُچی» و در تاجیکستان با نام «фараштурук» شناخته می‌شود و در زبان انگلیسی به آن Swallow می‌گویند.\n\nبرنامه‌ی کتاب‌خوان پرستو به‌منظور ارائه‌ی کتاب‌های صوتی، موسیقی و پادکست برای فارسی‌زبانان راه‌اندازی شده است. این برنامه با طراحی ساده، کاربردی و بدون زواید، از نخستین اپلیکیشن‌هایی است که با هدف ایجاد پیوند فرهنگی میان ایران، افغانستان و تاجیکستان طراحی شده است.';
      case AppLanguage.en:
        return 'Parasto is the Persian name for a small bird with a dark back, light belly, and orange beak - the Swallow. In various cultures, it symbolizes spring, renewal, and good fortune. In Afghanistan, it\'s called "Ghuchi" and in Tajikistan "Farashturuk".\n\nThe Parasto app was created to provide audiobooks, music, and podcasts for Persian speakers. With its simple, functional design, it\'s one of the first apps designed to create cultural connections between Iran, Afghanistan, and Tajikistan.';
      case AppLanguage.tg:
        return 'Парасту номи паррандаи хурде бо пушти торик ва шиками равшан ва нӯки норанҷӣ аст, ки дар фарҳангҳои гуногун рамзи баҳор, эҳёи ҳаёт ва хушбахтӣ ба шумор меравад. Ин парранда дар Афғонистон бо номи «Ғучӣ» ва дар Тоҷикистон бо номи «фараштурук» маъруф аст.\n\nБарномаи Парасту барои пешниҳоди китобҳои садоӣ, мусиқӣ ва подкаст барои форсизабонон таъсис ёфтааст. Ин барнома бо тарроҳии содда ва корӣ яке аз нахустин барномаҳоест, ки бо ҳадафи эҷоди пайванди фарҳангӣ миёни Эрон, Афғонистон ва Тоҷикистон сохта шудааст.';
    }
  }

  static String get whyParastoTitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'چرا پرستو؟';
      case AppLanguage.en:
        return 'Why Parasto?';
      case AppLanguage.tg:
        return 'Чаро Парасту?';
    }
  }

  static String get whyParastoContent {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'با توجه به وضعیت زبان فارسی در افغانستان، تأثیر تحریم‌های جهانی بر ایران و پیامدهای آن بر تولید و توزیع فرهنگی، و نیز استفاده از خط سیریلیک در تاجیکستان، زبان فارسی امروز با چالش‌های گوناگونی در سطح جهانی روبه‌رو است.\n\nپرستو می‌کوشد با ایجاد یک بایگانی دیجیتالِ منسجم و در دسترس، کتاب‌ها، موسیقی و پادکست‌های فارسی را گردآوری کند و آن‌ها را در اختیار علاقه‌مندان در سراسر جهان قرار دهد؛ تا زبان و فرهنگ فارسی، در تنوع جغرافیایی و تاریخی خود، حفظ و تقویت شود.';
      case AppLanguage.en:
        return 'Given the challenges facing the Persian language in Afghanistan, the impact of international sanctions on Iran\'s cultural production and distribution, and the use of Cyrillic script in Tajikistan, Persian faces various global challenges today.\n\nParasto strives to create a comprehensive digital archive that collects Persian books, music, and podcasts, making them accessible to enthusiasts worldwide - preserving and strengthening Persian language and culture in all its geographic and historical diversity.';
      case AppLanguage.tg:
        return 'Бо назардошти вазъияти забони форсӣ дар Афғонистон, таъсири таҳримҳои ҷаҳонӣ ба Эрон ва оқибатҳои он ба истеҳсол ва паҳнкунии фарҳангӣ ва истифодаи хатти сириллик дар Тоҷикистон, забони форсӣ имрӯз бо мушкилоти гуногун дар сатҳи ҷаҳонӣ рӯ ба рӯ аст.\n\nПарасту мекӯшад бо эҷоди як бойгонии рақамии муназзам ва дастрас, китобҳо, мусиқӣ ва подкастҳои форсиро ҷамъоварӣ кунад ва онҳоро дар ихтиёри алоқамандон дар саросари ҷаҳон гузорад.';
    }
  }

  static String get featuresTitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'ویژگی‌های پرستو';
      case AppLanguage.en:
        return 'Features';
      case AppLanguage.tg:
        return 'Хусусиятҳои Парасту';
    }
  }

  static String get featuresIntro {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'پرستو در عین سادگی، امکاناتی هدفمند و کارآمد دارد که تجربه‌ی شنیدن را پایدار، شخصی‌سازی‌شده و دلپذیر می‌سازد.';
      case AppLanguage.en:
        return 'While simple, Parasto offers purposeful and efficient features that make the listening experience sustainable, personalized, and enjoyable.';
      case AppLanguage.tg:
        return 'Парасту дар айни соддагӣ, имконоти ҳадафманд ва самаранок дорад, ки таҷрибаи шуниданро устувор, шахсисозишуда ва дилпазир мегардонад.';
    }
  }

  static List<String> get featuresList {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return [
          'کتابخانه‌ی شخصی و حفظ پیشرفت شنیدن - پرستو به‌طور خودکار محل آخرین شنیدن هر کتاب را ذخیره می‌کند.',
          'دانلود و استفاده‌ی آفلاین - محتوا را دانلود کنید و بدون اینترنت گوش دهید.',
          'تنظیمات پیشرفته‌ی پخش - سرعت پخش، تایمر خواب و پرش هوشمند.',
          'جستجو و دسته‌بندی دقیق محتوا - بر اساس موضوع، نویسنده، راوی و قالب.',
          'پشتیبانی از سه گونه‌ی زبان فارسی - فارسی ایران، افغانستان و تاجیکی (سیریلیک).',
          'رابط کاربری ساده، سبک و بدون تبلیغات مزاحم.',
          'نشان‌گذاری و فهرست علاقه‌مندی‌ها.',
          'همگام‌سازی میان دستگاه‌ها.',
          'محتوای گزینش‌شده و باکیفیت.',
          'بخش ویژه کودک و نوجوان.',
          'بارگذاری کتاب توسط کاربران - هر کسی می‌تواند کتابی را با صدای خود روایت کند.',
        ];
      case AppLanguage.en:
        return [
          'Personal library with progress tracking - automatically saves your listening position.',
          'Offline downloads - download content and listen without internet.',
          'Advanced playback settings - speed control, sleep timer, and smart skip.',
          'Precise search and categorization - by topic, author, narrator, and format.',
          'Support for three Persian variants - Iranian, Afghan, and Tajik (Cyrillic).',
          'Simple, lightweight interface with no intrusive ads.',
          'Bookmarks and favorites lists.',
          'Cross-device synchronization.',
          'Curated, high-quality content.',
          'Dedicated children\'s section.',
          'User uploads - anyone can narrate and upload books.',
        ];
      case AppLanguage.tg:
        return [
          'Китобхонаи шахсӣ ва нигоҳдории пешрафт - ҷои охирини шунидан худкор захира мешавад.',
          'Боргирӣ ва истифодаи офлайн - муҳтаворо боргирӣ кунед ва бе интернет гӯш диҳед.',
          'Танзимоти пешрафтаи пахш - суръати пахш, вақтсанҷи хоб ва ҷаҳиши ҳушманд.',
          'Ҷустуҷӯ ва гурӯҳбандии дақиқ - аз рӯи мавзӯъ, муаллиф, ровӣ ва шакл.',
          'Дастгирии се навъи забони форсӣ - форсии Эрон, Афғонистон ва тоҷикӣ (сириллик).',
          'Интерфейси содда, сабук ва бе таблиғоти ноҳанҷор.',
          'Нишонагузорӣ ва рӯйхати дӯстдошта.',
          'Ҳамоҳангсозӣ миёни дастгоҳҳо.',
          'Мӯҳтавои интихобшуда ва бокифият.',
          'Бахши махсуси кӯдакон ва наврасон.',
          'Боркунии китоб аз ҷониби корбарон.',
        ];
    }
  }

  static String get userUploadTitle {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'بارگذاری کتاب توسط کاربران';
      case AppLanguage.en:
        return 'User Uploads';
      case AppLanguage.tg:
        return 'Боркунии китоб аз ҷониби корбарон';
    }
  }

  // ============================================
  // CAR MODE (حالت رانندگی)
  // ============================================

  static String get carMode {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'حالت رانندگی';
      case AppLanguage.en:
        return 'Car Mode';
      case AppLanguage.tg:
        return 'Ҳолати ронандагӣ';
    }
  }

  static String get carModeExit {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'خروج';
      case AppLanguage.en:
        return 'Exit';
      case AppLanguage.tg:
        return 'Баромадан';
    }
  }

  static String get carModeNoAudio {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'هیچ محتوایی در حال پخش نیست';
      case AppLanguage.en:
        return 'No audio is playing';
      case AppLanguage.tg:
        return 'Ҳеҷ мундариҷае пахш намешавад';
    }
  }

  static String get userUploadContent {
    switch (_currentLanguage) {
      case AppLanguage.fa:
        return 'یکی از ویژگی‌های متمایز پرستو، فراهم‌کردن امکان بارگذاری کتاب‌های صوتی توسط کاربران است. هر کسی که تمایل دارد می‌تواند کتابی را با صدای خود روایت کرده و در برنامه بارگذاری کند. این امکان به شنوندگان اجازه می‌دهد میان خوانش‌های مختلف یک اثر، بهترین روایت را انتخاب کنند.';
      case AppLanguage.en:
        return 'One of Parasto\'s distinctive features is allowing users to upload audiobooks. Anyone can narrate a book in their own voice and upload it to the app. This allows listeners to choose the best narration among different readings of the same work.';
      case AppLanguage.tg:
        return 'Яке аз хусусиятҳои фарқкунандаи Парасту, фароҳам овардани имконияти боркунии китобҳои садоӣ аз ҷониби корбарон аст. Ҳар касе ки мехоҳад метавонад китобро бо садои худ ривоят кунад ва дар барнома бор кунад.';
    }
  }
}
