import 'package:myna/config/app_config.dart';

/// Environment configuration wrapper.
///
/// This class provides access to environment variables loaded via AppConfig.
/// For backward compatibility, it maintains the same interface as the original
/// hardcoded Env class.
///
/// IMPORTANT: AppConfig.load() must be called before accessing these values.
class Env {
  // Supabase Configuration
  static String get supabaseUrl => AppConfig.supabaseUrl;
  static String get supabaseAnonKey => AppConfig.supabaseAnonKey;

  // App Configuration
  static String get appName => AppConfig.appName;
  static String get appNameFa => AppConfig.appNameFa;

  // Storage Buckets
  static String get audioBucket => AppConfig.audioBucket;
  static String get coversBucket => AppConfig.coversBucket;
  static String get profileImagesBucket => AppConfig.profileImagesBucket;

  // Audio Configuration
  static int get audioUrlExpiry => AppConfig.audioUrlExpiry;

  // Stripe Configuration
  static String get stripePublishableKey => AppConfig.stripePublishableKey;
  static String get stripeMerchantId => AppConfig.stripeMerchantId;
  static bool get isStripeConfigured => AppConfig.isStripeConfigured;
}
