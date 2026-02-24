import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/services/social_auth_service.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/validators.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/screens/auth/signup_screen.dart';
import 'package:myna/screens/auth/reset_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSocialLoading = false; // separate flag so email form stays tappable
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Email / password ────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Navigation handled by auth state listener in main.dart
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = AppStrings.loginError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Social auth ─────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSocialLoading = true;
      _error = null;
    });
    try {
      final result = await SocialAuthService.instance.signInWithGoogle();
      if (result == SocialAuthResult.cancelled && mounted) {
        return; // user tapped back — not an error
      }
      // success: main.dart auth listener navigates away
    } on SocialAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = AppStrings.socialLoginError);
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isSocialLoading = true;
      _error = null;
    });
    try {
      final result = await SocialAuthService.instance.signInWithApple();
      if (result == SocialAuthResult.cancelled && mounted) {
        return;
      }
    } on SocialAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = AppStrings.socialLoginError);
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  // ── Language ─────────────────────────────────────────────────────────────────

  Future<void> _selectLanguage(AppLanguage language) async {
    if (AppStrings.currentLanguage != language) {
      await AppStrings.setLanguage(language);
      if (mounted) setState(() {});
    }
  }

  Widget _buildLanguageButton(AppLanguage language, String label) {
    final isSelected = AppStrings.currentLanguage == language;
    return TextButton(
      onPressed: () => _selectLanguage(language),
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? AppColors.primary : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final anyLoading = _isLoading || _isSocialLoading;

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLanguageButton(AppLanguage.fa, 'فارسی'),
                      const Text('|', style: TextStyle(color: AppColors.textTertiary)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Тоҷикӣ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // App name
                  Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    AppStrings.appTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !anyLoading,
                    decoration: InputDecoration(
                      labelText: AppStrings.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !anyLoading,
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) =>
                        Validators.required(value, fieldName: AppStrings.password),
                  ),
                  const SizedBox(height: 8),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: anyLoading
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const ResetPasswordScreen(),
                                ),
                              ),
                      child: Text(
                        AppStrings.forgotPassword,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Login button
                  ElevatedButton(
                    onPressed: anyLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppStrings.login,
                            style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 24),

                  // ── Social divider ─────────────────────────────────────────
                  _OrDivider(label: AppStrings.orContinueWith),
                  const SizedBox(height: 16),

                  // Google
                  _GoogleSignInButton(
                    label: AppStrings.continueWithGoogle,
                    onPressed: anyLoading ? null : _signInWithGoogle,
                    isLoading: _isSocialLoading,
                  ),
                  const SizedBox(height: 12),

                  // Apple (only on platforms where Apple Sign-In is available)
                  FutureBuilder<bool>(
                    future: SignInWithApple.isAvailable(),
                    builder: (context, snap) {
                      if (snap.data != true) return const SizedBox.shrink();
                      return SignInWithAppleButton(
                        text: AppStrings.continueWithApple,
                        onPressed: anyLoading ? () {} : _signInWithApple,
                        style: SignInWithAppleButtonStyle.black,
                        borderRadius: BorderRadius.circular(10),
                        height: 50,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sign up row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.noAccount,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: anyLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                ),
                        child: Text(AppStrings.signUp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

/// "── یا ورود با ──" divider with label centred.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

/// Custom Google sign-in button matching the dark theme.
/// Draws the Google "G" logo in-canvas — no SVG package required.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const _GoogleLogo(size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the Google "G" logo using four brand-coloured arcs.
/// No SVG dependency — pure CustomPainter canvas arcs.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _GoogleLogoPainter(),
      );
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final sw = size.width * 0.18;
    final hs = sw / 2;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    final arc = Rect.fromCircle(center: c, radius: r - hs);

    p.color = const Color(0xFFEA4335); // red
    canvas.drawArc(arc, -1.25, 1.1, false, p);

    p.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(arc, -0.15, 1.65, false, p);

    p.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(arc, 1.5, 1.15, false, p);

    p.color = const Color(0xFF34A853); // green
    canvas.drawArc(arc, 2.65, 0.6, false, p);

    // Horizontal bar of the "G"
    p
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(c.dx, c.dy), Offset(c.dx + r - hs, c.dy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
