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

  // Sign up with email and password
  Future<bool> signup(String email, String password, {String? name}) async {
  try {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: name != null ? {'name': name} : null,
    );

    if (response.user != null) {
      // ✅ Add this after successful signup
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'email': email,
        'name': name ?? '',
      });

      await _supabase.from('goals').insert({
        'user_id': response.user!.id,
      });

      await _storage.write(
        key: 'supabase_session',
        value: response.session?.accessToken,
      );
      return true;
    }
    return false;
  } catch (e) {
    print('Signup error: $e');
    return false;
  }
}



  // Sign in with email and password
  Future<bool> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null && response.session != null) {
        // Store session token
        await _storage.write(key: 'supabase_session', value: response.session!.accessToken);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

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

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.diabetesandme.app://reset-password',
      );
      return true;
    } catch (e) {
      print('Password reset error: $e');
      return false;
    }
  }

  // Verify OTP (for password reset)
  Future<bool> verifyOTP(String email, String token) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
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