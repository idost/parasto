import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/models.dart';
import 'package:myna/utils/app_logger.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseProvider).auth.currentUser;
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (response == null) return null;
  return Profile.fromJson(response);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Request a password reset email.
  ///
  /// NOTE(Issue 4): Password reset requires proper Supabase Dashboard configuration:
  /// 1. Go to Authentication > Email Templates in Supabase Dashboard
  /// 2. Configure the "Reset Password" email template
  /// 3. Set the "Site URL" in Authentication > URL Configuration
  /// 4. Add the app's deep link URL to "Redirect URLs" if using deep links
  ///
  /// The email is sent by Supabase, not by this app. If users don't receive
  /// emails, check:
  /// - Supabase email provider settings (default has rate limits)
  /// - Spam/junk folder
  /// - Email template configuration
  Future<void> resetPassword(String email) async {
    AppLogger.d('AuthService: Requesting password reset for email: ${email.substring(0, 3)}***');
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.parasto://reset-callback',
      );
      AppLogger.d('AuthService: Password reset request sent successfully');
    } catch (e, st) {
      AppLogger.e('AuthService: Password reset request failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
