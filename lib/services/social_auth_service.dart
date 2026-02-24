import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a social sign-in attempt.
enum SocialAuthResult {
  success,
  cancelled, // user tapped "Cancel" — not an error, just dismiss
  error,
}

class SocialAuthException implements Exception {
  const SocialAuthException(this.message);
  final String message;
  @override
  String toString() => 'SocialAuthException: $message';
}

/// Thin service that handles Google and Apple sign-in flows.
///
/// Architecture contract:
/// - This service performs the native SDK handshake and hands the JWT
///   to Supabase.  It does NOT navigate or update any UI state.
/// - Callers (LoginScreen) own error display and navigation.
/// - All methods return [SocialAuthResult]; the caller decides what to do
///   with [SocialAuthResult.cancelled] vs [SocialAuthResult.error].
class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  // ── Google ──────────────────────────────────────────────────────────────────

  /// Whether [initializeGoogle] has been called yet.
  bool _googleInitialized = false;

  /// Call once from main() before using [signInWithGoogle].
  ///
  /// [clientId] is the iOS OAuth client ID from Google Cloud Console.
  /// The reversed form of this ID is registered as a URL scheme in
  /// ios/Runner/Info.plist so iOS can redirect back after OAuth.
  Future<void> initializeGoogle({
    String clientId =
        '828781701952-sk3ikg8r68ve5m61kgsm8o21sp4m3l8e.apps.googleusercontent.com',
  }) async {
    if (kIsWeb) return; // Web uses Supabase OAuth redirect, not native SDK
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(clientId: clientId);
    _googleInitialized = true;
  }

  /// Signs in via Google.
  ///
  /// **Web:** Uses Supabase OAuth redirect (page navigates to Google, then
  /// back; [onAuthStateChange] in main.dart handles the session).
  ///
  /// **Native (iOS/Android):** Uses google_sign_in v7 SDK.  Requires
  /// [initializeGoogle] to have been called at app startup.
  Future<SocialAuthResult> signInWithGoogle() async {
    if (kIsWeb) return _signInWithGoogleWeb();
    return _signInWithGoogleNative();
  }

  Future<SocialAuthResult> _signInWithGoogleWeb() async {
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
      );
      if (!launched) {
        throw const SocialAuthException('Could not launch Google sign-in.');
      }
      // Page redirects to Google — auth completes via onAuthStateChange.
      return SocialAuthResult.success;
    } on SocialAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[SocialAuth] Google OAuth error: $e');
      throw SocialAuthException(e.toString());
    }
  }

  Future<SocialAuthResult> _signInWithGoogleNative() async {
    assert(_googleInitialized,
        'Call SocialAuthService.instance.initializeGoogle() before signing in.');
    try {
      // v7: authenticate() throws GoogleSignInException on cancel — never null.
      final account = await GoogleSignIn.instance.authenticate();

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const SocialAuthException('Google did not return an ID token.');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      return SocialAuthResult.success;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return SocialAuthResult.cancelled;
      }
      debugPrint('[SocialAuth] Google error: ${e.code} — ${e.description}');
      throw SocialAuthException(e.description ?? e.code.toString());
    } on SocialAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[SocialAuth] Google unexpected error: $e');
      throw SocialAuthException(e.toString());
    }
  }

  // ── Apple ───────────────────────────────────────────────────────────────────

  /// Signs in via Apple.
  ///
  /// **Web:** Uses Supabase OAuth redirect (same pattern as Google).
  ///
  /// **Native (iOS 13+):** Uses Sign in with Apple SDK with a cryptographically
  /// random nonce.  Requires "Sign in with Apple" capability in App Store
  /// Connect + Runner.entitlements.
  Future<SocialAuthResult> signInWithApple() async {
    if (kIsWeb) return _signInWithAppleWeb();
    return _signInWithAppleNative();
  }

  Future<SocialAuthResult> _signInWithAppleWeb() async {
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
      );
      if (!launched) {
        throw const SocialAuthException('Could not launch Apple sign-in.');
      }
      return SocialAuthResult.success;
    } on SocialAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[SocialAuth] Apple OAuth error: $e');
      throw SocialAuthException(e.toString());
    }
  }

  Future<SocialAuthResult> _signInWithAppleNative() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw const SocialAuthException(
            'Apple did not return an identity token.');
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      return SocialAuthResult.success;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialAuthResult.cancelled;
      }
      debugPrint('[SocialAuth] Apple auth error: ${e.code} — ${e.message}');
      throw SocialAuthException(e.message);
    } on SocialAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[SocialAuth] Apple unexpected error: $e');
      throw SocialAuthException(e.toString());
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
            length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
