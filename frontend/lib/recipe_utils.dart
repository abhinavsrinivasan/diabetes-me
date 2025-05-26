import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'features/recipes/models/recipe.dart';
import 'services/auth_service.dart';

class RecipeUtils {
 
static final String baseUrl = kIsWeb ? 'http://127.0.0.1:5001' : 'http://10.0.2.2:5001';
  
  static Future<String?> _getUserEmail() async {
    final token = await AuthService().getToken();
    if (token == null) return null;
    
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        return payload['sub'] ?? payload['email'];
      }
    } catch (e) {
      debugPrint('Error decoding token: $e');
    }
    return null;
  }
  
  // Add recipe nutrition to daily goals
  static Future<void> addRecipeNutrition(Recipe recipe, BuildContext context) async {
    final token = await AuthService().getToken();
    if (token == null) return;
    
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/progress'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: json.encode({
          'carbs': recipe.carbs,
          'sugar': recipe.sugar,
        }),
      );
      
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added ${recipe.carbs}g carbs and ${recipe.sugar}g sugar from ${recipe.title}!"),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding recipe nutrition: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to add nutrition. Please try again."),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
  
  // Toggle favorite status
  static Future<bool> toggleFavorite(Recipe recipe) async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorites_$userEmail');
    List<Recipe> favorites = [];
    
    if (favoritesJson != null) {
      final List<dynamic> favoritesList = json.decode(favoritesJson);
      favorites = favoritesList.map((item) => Recipe.fromJson(item)).toList();
    }
    
    bool isFavorite = favorites.any((r) => r.id == recipe.id);
    
    if (isFavorite) {
      favorites.removeWhere((r) => r.id == recipe.id);
    } else {
      favorites.add(recipe);
    }
    
    await prefs.setString(
      'favorites_$userEmail',
      json.encode(favorites.map((r) => r.toJson()).toList()),
    );
    
    return !isFavorite;
  }
  
  // Check if recipe is favorite
  static Future<bool> isFavorite(Recipe recipe) async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorites_$userEmail');
    if (favoritesJson == null) return false;
    
    final List<dynamic> favoritesList = json.decode(favoritesJson);
    final favorites = favoritesList.map((item) => Recipe.fromJson(item)).toList();
    
    return favorites.any((r) => r.id == recipe.id);
  }
  
  // Get all favorite recipes
  static Future<List<Recipe>> getFavoriteRecipes() async {
    final userEmail = await _getUserEmail();
    if (userEmail == null) return [];
    
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorites_$userEmail');
    if (favoritesJson == null) return [];
    
    final List<dynamic> favoritesList = json.decode(favoritesJson);
    return favoritesList.map((item) => Recipe.fromJson(item)).toList();
  }
}