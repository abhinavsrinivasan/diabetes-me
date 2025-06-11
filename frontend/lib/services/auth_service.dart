import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

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
        // Don't set emailRedirectTo to prevent auto-redirect issues
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
  Future<AuthResult> login(String email, String password) async {
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
        
        // Store session token
        await _storage.write(key: 'supabase_session', value: response.session!.accessToken);
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

  // Resend email confirmation
  Future<bool> resendEmailConfirmation(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return true;
    } catch (e) {
      print('Resend confirmation error: $e');
      return false;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      print('Password reset error: $e');
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

  // Update password
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

      // Get goals data
      final goalsResponse = await _supabase
          .from('goals')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // Get today's progress
      final today = DateTime.now().toIso8601String().split('T')[0];
      final progressResponse = await _supabase
          .from('daily_progress')
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      // Combine all data
      final profile = {
        'id': user.id,
        'email': profileResponse['email'],
        'name': profileResponse['name'] ?? 'User',
        'bio': profileResponse['bio'] ?? '',
        'profile_picture': profileResponse['profile_picture'] ?? '',
        'goals': goalsResponse ?? {
          'carbs': 200,
          'sugar': 50,
          'exercise': 30,
        },
        'progress': progressResponse ?? {
          'carbs': 0,
          'sugar': 0,
          'exercise': 0,
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
  Future<bool> updateGoals(Map<String, dynamic> goals) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await _supabase
          .from('goals')
          .upsert({
            'user_id': user.id,
            ...goals,
          });

      return true;
    } catch (e) {
      print('Update goals error: $e');
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

  // Reset daily progress
  Future<bool> resetProgress() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      await _supabase
          .from('daily_progress')
          .upsert({
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

  // Sign out
  Future<void> logout() async {
    await _supabase.auth.signOut();
    await _storage.delete(key: 'supabase_session');
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
  final String? email;
  final String? errorMessage;

  AuthResult._({
    required this.isSuccess,
    required this.needsEmailConfirmation,
    this.email,
    this.errorMessage,
  });

  factory AuthResult.success() {
    return AuthResult._(
      isSuccess: true,
      needsEmailConfirmation: false,
    );
  }

  factory AuthResult.emailConfirmationRequired(String email) {
    return AuthResult._(
      isSuccess: false,
      needsEmailConfirmation: true,
      email: email,
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult._(
      isSuccess: false,
      needsEmailConfirmation: false,
      errorMessage: message,
    );
  }
}