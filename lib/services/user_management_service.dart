import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Result of user creation operation
class CreateUserResult {
  final bool success;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? role;
  final String? error;
  final String? message;

  const CreateUserResult({
    required this.success,
    this.userId,
    this.email,
    this.displayName,
    this.role,
    this.error,
    this.message,
  });

  factory CreateUserResult.fromJson(Map<String, dynamic> json) {
    if (json['success'] == true && json['user'] != null) {
      final user = json['user'] as Map<String, dynamic>;
      return CreateUserResult(
        success: true,
        userId: user['id'] as String?,
        email: user['email'] as String?,
        displayName: user['display_name'] as String?,
        role: user['role'] as String?,
        message: json['message'] as String?,
      );
    } else {
      return CreateUserResult(
        success: false,
        error: json['error'] as String? ?? 'Unknown error',
      );
    }
  }

  factory CreateUserResult.error(String errorMessage) {
    return CreateUserResult(
      success: false,
      error: errorMessage,
    );
  }
}

/// Service for admin user management operations
class UserManagementService {
  static final _supabase = Supabase.instance.client;

  /// Create a new user with specified role (admin only)
  /// Calls the create-user Edge Function which sends an invitation email
  static Future<CreateUserResult> createUser({
    required String email,
    required String displayName,
    required String role,
  }) async {
    try {
      AppLogger.i('Creating user: $email with role: $role');

      final response = await _supabase.functions.invoke(
        'create-user',
        body: {
          'email': email.trim().toLowerCase(),
          'display_name': displayName.trim(),
          'role': role,
        },
      );

      if (response.status == 201) {
        final data = response.data as Map<String, dynamic>;
        AppLogger.i('User created successfully: ${data['user']?['id']}');
        return CreateUserResult.fromJson(data);
      } else {
        final error = response.data?['error'] as String? ?? 'Failed to create user';
        AppLogger.e('User creation failed: $error (status: ${response.status})');
        return CreateUserResult.error(_translateError(error));
      }
    } on FunctionException catch (e) {
      AppLogger.e('Edge Function error', error: e);
      final errorMessage = e.details?['error'] as String? ?? e.reasonPhrase ?? 'خطا در اتصال به سرور';
      return CreateUserResult.error(_translateError(errorMessage));
    } catch (e) {
      AppLogger.e('Error creating user', error: e);
      return CreateUserResult.error('خطای غیرمنتظره: $e');
    }
  }

  /// Translate common error messages to Persian
  static String _translateError(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('unauthorized') || errorLower.contains('invalid token')) {
      return 'نشست شما منقضی شده است. لطفاً دوباره وارد شوید.';
    }
    if (errorLower.contains('forbidden') || errorLower.contains('admin')) {
      return 'شما مجوز ایجاد کاربر را ندارید.';
    }
    if (errorLower.contains('already exists') || errorLower.contains('duplicate')) {
      return 'کاربری با این ایمیل قبلاً وجود دارد.';
    }
    if (errorLower.contains('invalid email')) {
      return 'آدرس ایمیل نامعتبر است.';
    }
    if (errorLower.contains('invalid role')) {
      return 'نقش انتخاب شده نامعتبر است.';
    }
    if (errorLower.contains('display name')) {
      return 'نام نمایشی الزامی است.';
    }

    return error;
  }

  /// Check if current user can create users (is admin)
  static Future<bool> canCreateUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return response?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }
}
