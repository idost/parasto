import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration loaded from environment variables.
///
/// Usage:
/// ```dart
/// await AppConfig.load(); // Call once in main()
/// final url = AppConfig.supabaseUrl;
/// ```
class AppConfig {
  static bool _isLoaded = false;

  /// Load environment variables from .env file.
  /// Must be called before accessing any configuration values.
  static Future<void> load() async {
    if (_isLoaded) return;

    await dotenv.load(fileName: '.env');
    _isLoaded = true;
  }

  /// Ensure config is loaded before accessing values.
  static void _ensureLoaded() {
    if (!_isLoaded) {
      throw StateError(
        'AppConfig not loaded. Call AppConfig.load() in main() before accessing configuration.',
      );
    }
  }

  // Supabase Configuration
  static String get supabaseUrl {
    _ensureLoaded();
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL not found in environment');
    }
    return url;
  }

  static String get supabaseAnonKey {
    _ensureLoaded();
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY not found in environment');
    }
    return key;
  }

  // App Configuration
  static String get appName {
    _ensureLoaded();
    return dotenv.env['APP_NAME'] ?? 'Parasto';
  }

  static String get appNameFa {
    _ensureLoaded();
    return dotenv.env['APP_NAME_FA'] ?? 'پرستو';
  }

  // Storage Buckets
  static String get audioBucket {
    _ensureLoaded();
    return dotenv.env['AUDIO_BUCKET'] ?? 'audiobook-audio';
  }

  static String get coversBucket {
    _ensureLoaded();
    return dotenv.env['COVERS_BUCKET'] ?? 'audiobook-covers';
  }

  static String get profileImagesBucket {
    _ensureLoaded();
    return dotenv.env['PROFILE_IMAGES_BUCKET'] ?? 'profile-images';
  }

  // Audio Configuration
  static int get audioUrlExpiry {
    _ensureLoaded();
    final expiry = dotenv.env['AUDIO_URL_EXPIRY'];
    return int.tryParse(expiry ?? '3600') ?? 3600;
  }

  // Stripe Configuration
  static String get stripePublishableKey {
    _ensureLoaded();
    return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  }

  static String get stripeMerchantId {
    _ensureLoaded();
    return dotenv.env['STRIPE_MERCHANT_ID'] ?? 'merchant.com.myna';
  }

  /// Check if Stripe is configured
  static bool get isStripeConfigured {
    _ensureLoaded();
    final key = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    return key != null && key.isNotEmpty && key != 'your_stripe_publishable_key';
  }

  // Azure Translator API (Microsoft Cognitive Services)
  static String get azureTranslatorKey {
    _ensureLoaded();
    return dotenv.env['AZURE_TRANSLATOR_KEY'] ?? '';
  }

  static String get azureTranslatorRegion {
    _ensureLoaded();
    return dotenv.env['AZURE_TRANSLATOR_REGION'] ?? 'eastus';
  }

  /// Check if Azure Translator API is configured
  static bool get isTranslationConfigured {
    _ensureLoaded();
    final key = dotenv.env['AZURE_TRANSLATOR_KEY'];
    return key != null && key.isNotEmpty;
  }
}
