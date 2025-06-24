import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

  // Add this flag to track password reset sessions
  static bool _isPasswordResetFlow = false;
  
  // Call this when starting password reset flow
  static void setPasswordResetFlow(bool isReset) {
    _isPasswordResetFlow = isReset;
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;
  
  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Sign up with email and password - Always requires email confirmation
  Future<AuthResult> signup(String email, String password, {String? name}) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
        emailRedirectTo: 'com.abhinavsrinivasan.diabetesme://login-callback',
      );

      if (response.user != null) {
        // Email confirmation is always required now
        return AuthResult.emailConfirmationRequired(email);
      }
      return AuthResult.error('Failed to create account');
    } catch (e) {
      print('Signup error: $e');
      return AuthResult.error('Failed to create account: ${e.toString()}');
    }
  }

  // Create user profile after successful email confirmation
  Future<void> _createUserProfile(User user, String email, String? name) async {
    try {
      await _supabase.from('profiles').insert({
        'id': user.id,
        'email': email,
        'name': name ?? '',
      });

      await _supabase.from('goals').insert({
        'user_id': user.id,
      });
    } catch (e) {
      print('Error creating user profile: $e');
      // Don't throw here, profile creation can be retried later
    }
  }

  // Sign in with email and password - Checks email confirmation
  Future<AuthResult> login(String email, String password, {bool rememberMe = false}) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null && response.session != null) {
        // Check if email is confirmed
        if (response.user!.emailConfirmedAt == null) {
          return AuthResult.emailConfirmationRequired(email);
        }
        
        // Create profile if it doesn't exist (for users who confirmed email outside app)
        await _ensureUserProfileExists(response.user!, email);
        
        // Store session token and remember me preference
        await _storage.write(key: 'supabase_session', value: response.session!.accessToken);
        
        // Handle Remember Me functionality
        if (rememberMe) {
          await _storage.write(key: 'remember_email', value: email);
          await _storage.write(key: 'remember_me', value: 'true');
        } else {
          await _storage.delete(key: 'remember_email');
          await _storage.delete(key: 'remember_me');
        }
        
        return AuthResult.success();
      }
      return AuthResult.error('Invalid email or password');
    } catch (e) {
      print('Login error: $e');
      if (e.toString().contains('Email not confirmed')) {
        return AuthResult.emailConfirmationRequired(email);
      } else if (e.toString().contains('Invalid login credentials')) {
        return AuthResult.error('Invalid email or password');
      }
      return AuthResult.error('Login failed: ${e.toString()}');
    }
  }

  // Get remembered email for auto-fill
  Future<String?> getRememberedEmail() async {
    final rememberMe = await _storage.read(key: 'remember_me');
    if (rememberMe == 'true') {
      return await _storage.read(key: 'remember_email');
    }
    return null;
  }

  // Check if user has remember me enabled
  Future<bool> hasRememberMe() async {
    final rememberMe = await _storage.read(key: 'remember_me');
    return rememberMe == 'true';
  }

  // Ensure user profile exists (helper method)
  Future<void> _ensureUserProfileExists(User user, String email) async {
    try {
      // Check if profile exists
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        // Create profile
        await _createUserProfile(user, email, user.userMetadata?['name']);
      }
    } catch (e) {
      print('Error ensuring profile exists: $e');
    }
  }

  // Resend email confirmation with proper redirect
  Future<bool> resendEmailConfirmation(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'com.abhinavsrinivasan.diabetesme://login-callback',
      );
      return true;
    } catch (e) {
      print('Resend confirmation error: $e');
      return false;
    }
  }

  // FIXED: Send password reset email with proper redirect
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.abhinavsrinivasan.diabetesme://password-reset',
      );
      return true;
    } catch (e) {
      print('Password reset error: $e');
      return false;
    }
  }

  // UPDATED: Check if current session is a password reset session
  bool isPasswordResetSession() {
    return _isPasswordResetFlow;
  }

  // UPDATED: Update password during password reset flow
  Future<bool> updatePasswordFromReset(String newPassword) async {
    try {
      if (!isPasswordResetSession()) {
        throw Exception('Not in password reset session');
      }
      
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      // Clear the password reset flag after successful update
      _isPasswordResetFlow = false;
      
      return true;
    } catch (e) {
      print('Update password error: $e');
      return false;
    }
  }

  // Verify OTP (for password reset or email confirmation)
  Future<bool> verifyOTP(String email, String token, {OtpType type = OtpType.recovery}) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: type,
      );
      return response.user != null;
    } catch (e) {
      print('OTP verification error: $e');
      return false;
    }
  }

  // Update password (general method)
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      print('Update password error: $e');
      return false;
    }
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get user profile
  // Replace the getProfile method in lib/services/auth_service.dart

Future<Map<String, dynamic>?> getProfile() async {
  try {
    final user = currentUser;
    if (user == null) return null;

    // Get profile data
    final profileResponse = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    // Get goals data with fallback creation
    Map<String, dynamic> goalsData;
    try {
      final goalsResponse = await _supabase
          .from('goals')
          .select()
          .eq('user_id', user.id)
          .single();
      goalsData = goalsResponse;
    } catch (e) {
      // Goals don't exist, create default ones
      debugPrint('Goals not found, creating defaults: $e');
      final defaultGoals = {
        'user_id': user.id,
        'carbs': 200,
        'sugar': 50,
        'exercise': 30,
      };
      
      try {
        await _supabase.from('goals').insert(defaultGoals);
        goalsData = defaultGoals;
      } catch (insertError) {
        debugPrint('Failed to create default goals: $insertError');
        goalsData = {'carbs': 200, 'sugar': 50, 'exercise': 30};
      }
    }

    // Get today's progress with fallback creation
    final today = DateTime.now().toIso8601String().split('T')[0];
    Map<String, dynamic> progressData;
    try {
      final progressResponse = await _supabase
          .from('daily_progress')
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .single();
      progressData = progressResponse;
    } catch (e) {
      // Progress doesn't exist for today, create default
      debugPrint('Daily progress not found, creating defaults: $e');
      final defaultProgress = {
        'user_id': user.id,
        'date': today,
        'carbs': 0,
        'sugar': 0,
        'exercise': 0,
      };
      
      try {
        await _supabase.from('daily_progress').insert(defaultProgress);
        progressData = defaultProgress;
      } catch (insertError) {
        debugPrint('Failed to create default progress: $insertError');
        progressData = {'carbs': 0, 'sugar': 0, 'exercise': 0};
      }
    }

    // Combine all data
    final profile = {
      'id': user.id,
      'email': profileResponse['email'],
      'name': profileResponse['name'] ?? 'User',
      'bio': profileResponse['bio'] ?? '',
      'profile_picture': profileResponse['profile_picture'] ?? '',
      'profile_picture_url': profileResponse['profile_picture_url'] ?? '', // Add this for the new profile picture system
      'goals': {
        'carbs': goalsData['carbs'] ?? 200,
        'sugar': goalsData['sugar'] ?? 50,
        'exercise': goalsData['exercise'] ?? 30,
      },
      'progress': {
        'carbs': progressData['carbs'] ?? 0,
        'sugar': progressData['sugar'] ?? 0,
        'exercise': progressData['exercise'] ?? 0,
      },
      'lastUpdated': today,
    };

    return profile;
  } catch (e) {
    print('Get profile error: $e');
    return null;
  }
}

  // Update profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id);

      return true;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  // Update goals
  // Updated AuthService methods in lib/services/auth_service.dart

// Replace the updateGoals method with this fixed version:
Future<bool> updateGoals(Map<String, dynamic> goals) async {
  try {
    final user = currentUser;
    if (user == null) return false;

    // First, check if goals record exists
    final existingGoals = await _supabase
        .from('goals')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingGoals != null) {
      // Update existing record
      await _supabase
          .from('goals')
          .update(goals)
          .eq('user_id', user.id);
    } else {
      // Insert new record
      await _supabase
          .from('goals')
          .insert({
            'user_id': user.id,
            ...goals,
          });
    }

    return true;
  } catch (e) {
    print('Update goals error: $e');
    return false;
  }
}

// Replace the resetProgress method with this fixed version:
Future<bool> resetProgress() async {
  try {
    final user = currentUser;
    if (user == null) return false;

    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Delete existing progress for today and insert fresh record
    await _supabase
        .from('daily_progress')
        .delete()
        .eq('user_id', user.id)
        .eq('date', today);
    
    // Insert fresh progress with zeros
    await _supabase
        .from('daily_progress')
        .insert({
          'user_id': user.id,
          'date': today,
          'carbs': 0,
          'sugar': 0,
          'exercise': 0,
        });

    return true;
  } catch (e) {
    print('Reset progress error: $e');
    return false;
  }
}

  // Update daily progress
  Future<bool> updateProgress(Map<String, dynamic> progress) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Get current progress
      final currentProgress = await _supabase
          .from('daily_progress')
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      if (currentProgress != null) {
        // Update existing progress
        final updatedProgress = {
          'carbs': (currentProgress['carbs'] ?? 0) + (progress['carbs'] ?? 0),
          'sugar': (currentProgress['sugar'] ?? 0) + (progress['sugar'] ?? 0),
          'exercise': (currentProgress['exercise'] ?? 0) + (progress['exercise'] ?? 0),
        };

        await _supabase
            .from('daily_progress')
            .update(updatedProgress)
            .eq('user_id', user.id)
            .eq('date', today);
      } else {
        // Create new progress entry
        await _supabase
            .from('daily_progress')
            .insert({
              'user_id': user.id,
              'date': today,
              ...progress,
            });
      }

      return true;
    } catch (e) {
      print('Update progress error: $e');
      return false;
    }
  }

  

  // UPDATED: Sign out with password reset flag clearing
  Future<void> logout() async {
    await _supabase.auth.signOut();
    await _storage.delete(key: 'supabase_session');
    _isPasswordResetFlow = false; // Clear flag
    // Keep remember me data unless user explicitly logs out
  }

  // Clear all stored data (for complete logout)
  Future<void> logoutAndClearAll() async {
    await _supabase.auth.signOut();
    await _storage.delete(key: 'supabase_session');
    await _storage.delete(key: 'remember_email');
    await _storage.delete(key: 'remember_me');
    _isPasswordResetFlow = false; // Clear flag
  }

  // Get stored token (for compatibility)
  Future<String?> getToken() async {
    final session = _supabase.auth.currentSession;
    return session?.accessToken;
  }

  // Restore session on app start
  Future<void> restoreSession() async {
    try {
      final storedToken = await _storage.read(key: 'supabase_session');
      if (storedToken != null) {
        // Supabase automatically handles session restoration
        // This is just for backward compatibility
      }
    } catch (e) {
      print('Session restore error: $e');
    }
  }
}

// Auth result class to handle different outcomes
class AuthResult {
  final bool isSuccess;
  final bool needsEmailConfirmation;
  final bool needsPasswordReset;
  final String? email;
  final String? errorMessage;

  AuthResult._({
    required this.isSuccess,
    required this.needsEmailConfirmation,
    required this.needsPasswordReset,
    this.email,
    this.errorMessage,
  });

  factory AuthResult.success() {
    return AuthResult._(
      isSuccess: true,
      needsEmailConfirmation: false,
      needsPasswordReset: false,
    );
  }

  factory AuthResult.emailConfirmationRequired(String email) {
    return AuthResult._(
      isSuccess: false,
      needsEmailConfirmation: true,
      needsPasswordReset: false,
      email: email,
    );
  }

  factory AuthResult.passwordResetRequired(String email) {
    return AuthResult._(
      isSuccess: false,
      needsEmailConfirmation: false,
      needsPasswordReset: true,
      email: email,
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult._(
      isSuccess: false,
      needsEmailConfirmation: false,
      needsPasswordReset: false,
      errorMessage: message,
    );
  }
}