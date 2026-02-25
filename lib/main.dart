import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myna/config/app_config.dart';
import 'package:myna/config/env.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/auth/login_screen.dart';
import 'package:myna/screens/listener/main_shell.dart';
import 'package:myna/screens/narrator/narrator_main_shell.dart';
import 'package:myna/screens/admin/admin_shell.dart';
import 'package:myna/services/audio_handler.dart';
import 'package:myna/services/payment_service.dart';
import 'package:myna/services/download_service.dart';
import 'package:myna/services/social_auth_service.dart';

import 'package:myna/providers/audio_provider.dart';
import 'package:myna/providers/user_providers.dart';
import 'package:myna/providers/app_mode_provider.dart';
import 'package:myna/screens/listener/settings_screen.dart' show settingsProvider;
import 'package:myna/screens/splash_screen.dart';
import 'package:myna/screens/auth/set_new_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode only (no landscape rotation)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables first (required for other services)
  await AppConfig.load();
  AppLogger.i('Environment loaded');

  // Load saved language preference before building UI
  await AppStrings.loadSavedLanguage();
  AppLogger.i('Language loaded: ${AppStrings.currentLanguage}');

  // Initialize translation service if Azure Translator API key is configured
  if (AppConfig.isTranslationConfigured) {
    AppStrings.initializeTranslation(
      AppConfig.azureTranslatorKey,
      azureRegion: AppConfig.azureTranslatorRegion,
    );
    AppLogger.i('Azure Translation service initialized');
  }

  // Initialize Supabase with config from environment (required for other services)
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  AppLogger.i('Supabase initialized');

  // PERFORMANCE: Only await critical services before runApp
  // Non-critical services init in background after app starts

  // Audio service is critical for playback - must await
  if (!kIsWeb) {
    await _initAudioService();
  }

  // Start app immediately - other services init in background
  runApp(const ProviderScope(child: MynaApp()));

  // PERFORMANCE: Initialize non-critical services AFTER runApp (background)
  // This allows the UI to render while these services load
  if (!kIsWeb) {
    _initDownloadService(); // Downloads can wait
    _initSocialAuth(); // Google Sign-In SDK init (native only; web uses OAuth redirect)
  }
  _initPaymentService(); // Payment init can happen in background
}

Future<void> _initAudioService() async {
  AppLogger.audioNotif('STARTUP: _initAudioService() called from main()');
  try {
    final audioHandler = await initAudioService();
    setGlobalAudioHandler(audioHandler);
    AppLogger.audioNotif('STARTUP: AudioService initialized and handler set globally');
    AppLogger.i('Audio service initialized');
  } catch (e, st) {
    AppLogger.audioNotif('STARTUP: AudioService initialization FAILED: $e');
    AppLogger.e('Failed to initialize audio service', error: e, stackTrace: st);
    // Continue without background audio - will use fallback
  }
}

Future<void> _initDownloadService() async {
  try {
    await DownloadService().init();
    AppLogger.i('Download service initialized');
  } catch (e) {
    AppLogger.e('Failed to initialize download service', error: e);
  }
}

Future<void> _initSocialAuth() async {
  try {
    await SocialAuthService.instance.initializeGoogle();
    AppLogger.i('Google Sign-In initialized');
  } catch (e) {
    AppLogger.e('Failed to initialize Google Sign-In', error: e);
  }
}

Future<void> _initPaymentService() async {
  try {
    await PaymentService().initialize();
    AppLogger.i('Payment service initialized');
  } catch (e) {
    AppLogger.e('Failed to initialize payment service', error: e);
  }
}

class MynaApp extends ConsumerStatefulWidget {
  const MynaApp({super.key});

  @override
  ConsumerState<MynaApp> createState() => _MynaAppState();
}

class _MynaAppState extends ConsumerState<MynaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _role;
  String? _lastUserId;
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final newUserId = data.session?.user.id;

      AppLogger.auth('Auth state changed: $event', userId: newUserId);

      // NOTE(Issue 5 fix): Invalidate user providers when:
      // 1. User signs out - clear old user's data
      // 2. User signs in - refresh to get fresh data for this user
      // 3. User changes (different user signs in) - refresh for new user
      // This fixes the issue where "Continue Listening" disappeared after
      // logout/login because providers weren't refreshed on sign-in.
      if (event == AuthChangeEvent.signedOut) {
        AppLogger.i('User signed out - invalidating providers');
        invalidateUserProviders(ref);
        _lastUserId = null; // Clear last user ID on logout
      } else if (event == AuthChangeEvent.passwordRecovery) {
        // Deep link from password reset email opened the app.
        // supabase_flutter has already exchanged the recovery token.
        AppLogger.i('Password recovery event - navigating to set new password');
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => const SetNewPasswordScreen(),
          ),
        );
      } else if (event == AuthChangeEvent.signedIn && newUserId != null) {
        AppLogger.i('User signed in - refreshing providers for user');
        invalidateUserProviders(ref);
        _lastUserId = newUserId;
      } else if (newUserId != null && _lastUserId != null && newUserId != _lastUserId) {
        AppLogger.i('Different user detected - invalidating providers');
        invalidateUserProviders(ref);
        _lastUserId = newUserId;
      }

      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    AppLogger.auth(
      'Auth check',
      hasSession: session != null,
      userId: user?.id,
    );

    if (user == null) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
      return;
    }

    // Track user ID for change detection
    if (_lastUserId == null) {
      _lastUserId = user.id;
    } else if (_lastUserId != user.id) {
      // Different user - invalidate all cached data
      AppLogger.i('Different user detected - invalidating providers');
      invalidateUserProviders(ref);
      _lastUserId = user.id;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role, is_disabled')
          .eq('id', user.id)
          .maybeSingle();

      // Handle case where profile doesn't exist yet
      if (response == null) {
        AppLogger.w('No profile found for user: ${user.id}');
        setState(() {
          _isLoggedIn = true;
          _role = null;
          _isLoading = false;
        });
        return;
      }

      // NOTE(Issue 10 fix): Check if user is disabled by admin
      // If so, sign them out and show an error message
      final isDisabled = response['is_disabled'] == true;
      if (isDisabled) {
        AppLogger.w('User is disabled - signing out: userId=${user.id}');
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          _showDisabledAccountDialog();
        }
        return;
      }

      final newRole = response['role'] as String?;
      AppLogger.auth('Role fetched: $newRole', userId: user.id);

      // NOTE(Issue 7 fix): Check if user's role was upgraded
      // and show a notification dialog if so
      await _checkRoleUpgrade(user.id, newRole);

      setState(() {
        _isLoggedIn = true;
        _role = newRole;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('Failed to fetch user role', error: e);
      setState(() {
        _isLoggedIn = true;
        _role = null;
        _isLoading = false;
      });
    }
  }

  /// NOTE(Issue 7 fix): Check if user's role was upgraded and show notification.
  /// Persists last known role per user in SharedPreferences.
  Future<void> _checkRoleUpgrade(String userId, String? newRole) async {
    if (newRole == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final roleKey = 'last_role_$userId';
      final lastRole = prefs.getString(roleKey);

      // Save current role for next time
      await prefs.setString(roleKey, newRole);

      // Check if role was upgraded from listener to narrator
      if (lastRole == 'listener' && newRole == 'narrator') {
        AppLogger.i('Role upgrade detected: listener -> narrator');

        // Show dialog after a short delay to ensure the app is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showRoleUpgradeDialog();
          }
        });
      }
    } catch (e) {
      AppLogger.e('Error checking role upgrade', error: e);
    }
  }

  /// NOTE(Issue 10 fix): Show dialog when user account is disabled
  void _showDisabledAccountDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block, color: AppColors.error, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'حساب غیرفعال',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'حساب کاربری شما غیرفعال شده است.\n\n'
            'برای اطلاعات بیشتر با پشتیبانی تماس بگیرید.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'متوجه شدم',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a dialog notifying user of their role upgrade
  void _showRoleUpgradeDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.celebration, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تبریک! 🎉',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'حساب شما به نقش راوی ارتقا یافت!\n\n'
            'اکنون می‌توانید کتاب‌های صوتی خود را ثبت و مدیریت کنید. '
            'برای دسترسی به پنل راوی، از منوی پروفایل گزینه «حالت راوی» را انتخاب کنید.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'متوجه شدم',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.resolvedThemeMode,
      // RTL support for Farsi
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // AnimatedSwitcher prevents flash on splash→home transition
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    // Show splash screen while loading OR until splash animation completes
    if (_isLoading || !_splashComplete) {
      return SplashScreen(
        key: const ValueKey('splash'),
        onComplete: () {
          if (mounted) {
            setState(() => _splashComplete = true);
          }
        },
      );
    }

    if (!_isLoggedIn) {
      return const LoginScreen(key: ValueKey('login'));
    }

    // Admin always sees AdminShell
    if (_role == 'admin') {
      return const AdminShell(key: ValueKey('admin'));
    }

    // Narrator users can switch between listener and narrator mode
    if (_role == 'narrator') {
      final appMode = ref.watch(appModeProvider);
      if (appMode == AppMode.narrator) {
        return const NarratorMainShell(key: ValueKey('narrator'));
      }
      // Narrator in listener mode sees MainShell
      return const MainShell(key: ValueKey('listener'));
    }

    // Regular listeners always see MainShell
    return const MainShell(key: ValueKey('listener'));
  }
}