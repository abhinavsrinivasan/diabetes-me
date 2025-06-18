import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/recipes/models/recipe.dart';
import 'services/auth_service.dart';
import 'dart:io' show Platform;

class RecipeUtils {
  static final _supabase = Supabase.instance.client;
  
  // Fixed: Use consistent port 5001 across all platforms
  static final String baseUrl = kIsWeb 
    ? 'http://127.0.0.1:5001' 
    : Platform.isIOS
        ? 'http://192.168.1.248:5001'  // Use your actual IP
        : 'http://10.0.2.2:5001';      // Android emulator
  
  static Future<String?> _getUserId() async {
    final user = _supabase.auth.currentUser;
    return user?.id;
  }
  
  // Add recipe nutrition to daily goals
  static Future<void> addRecipeNutrition(Recipe recipe, BuildContext context) async {
    try {
      final success = await AuthService().updateProgress({
        'carbs': recipe.carbs,
        'sugar': recipe.sugar,
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added ${recipe.carbs}g carbs and ${recipe.sugar}g sugar from ${recipe.title}!"),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        throw Exception('Failed to update progress');
      }
    } catch (e) {
      debugPrint('Error adding recipe nutrition: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to add nutrition to daily goals"),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
  
  // Toggle favorite status - now uses Supabase
  static Future<bool> toggleFavorite(Recipe recipe) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        debugPrint('Error: User not logged in');
        return false;
      }
      
      // Check if recipe is already favorited
      final existingFavorite = await _supabase
          .from('user_favorite_recipes')
          .select()
          .eq('user_id', userId)
          .eq('recipe_id', recipe.id)
          .maybeSingle();
      
      if (existingFavorite != null) {
        // Remove from favorites
        await _supabase
            .from('user_favorite_recipes')
            .delete()
            .eq('user_id', userId)
            .eq('recipe_id', recipe.id);
        
        debugPrint('✅ Removed recipe ${recipe.title} from favorites');
        return false;
      } else {
        // Add to favorites
        await _supabase
            .from('user_favorite_recipes')
            .insert({
              'user_id': userId,
              'recipe_id': recipe.id,
              'recipe_data': recipe.toJson(),
            });
        
        debugPrint('✅ Added recipe ${recipe.title} to favorites');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      return false;
    }
  }
  
  // Check if recipe is favorite - now uses Supabase
  static Future<bool> isFavorite(Recipe recipe) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return false;
      
      final favorite = await _supabase
          .from('user_favorite_recipes')
          .select()
          .eq('user_id', userId)
          .eq('recipe_id', recipe.id)
          .maybeSingle();
      
      return favorite != null;
    } catch (e) {
      debugPrint('❌ Error checking if favorite: $e');
      return false;
    }
  }
  
  // Get all favorite recipes - now uses Supabase
  static Future<List<Recipe>> getFavoriteRecipes() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return [];
      
      final response = await _supabase
          .from('user_favorite_recipes')
          .select('recipe_data')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return response
          .map<Recipe>((item) => Recipe.fromJson(item['recipe_data']))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching favorite recipes: $e');
      return [];
    }
  }

  // Remove specific favorite recipe
  static Future<bool> removeFavorite(int recipeId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return false;
      
      await _supabase
          .from('user_favorite_recipes')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
      
      debugPrint('✅ Removed recipe from favorites');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing favorite: $e');
      return false;
    }
  }

  // Clear all favorite recipes
  static Future<bool> clearAllFavorites() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return false;
      
      await _supabase
          .from('user_favorite_recipes')
          .delete()
          .eq('user_id', userId);
      
      debugPrint('✅ Cleared all favorite recipes');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing favorites: $e');
      return false;
    }
  }

  // Get favorites count
  static Future<int> getFavoritesCount() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return 0;
      
      final response = await _supabase
          .from('user_favorite_recipes')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', userId);
      
      return response.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting favorites count: $e');
      return 0;
    }
  }
}