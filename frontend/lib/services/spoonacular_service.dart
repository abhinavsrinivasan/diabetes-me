// Spoonacular API Service with enhanced features
// This service provides methods to interact with the Spoonacular API for diabetes-friendly recipes.
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../features/recipes/models/recipe.dart';
import '../config/env_config.dart';
import 'recipe_cleaner_service.dart';

// Custom exceptions for better error handling
enum SpoonacularError {
  rateLimitExceeded,
  quotaExceeded,
  invalidApiKey,
  networkError,
  unknownError
}

class SpoonacularException implements Exception {
  final SpoonacularError type;
  final String message;
  final int? statusCode;

  SpoonacularException(this.type, this.message, [this.statusCode]);

  @override
  String toString() => 'SpoonacularException: $message';
}

// Cache entry for storing recipes with timestamp
class CacheEntry {
  final List<Recipe> recipes;
  final DateTime timestamp;

  CacheEntry(this.recipes, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(hours: 1);
}

class SpoonacularService {
  // Base URL for Spoonacular API
  static const String _baseUrl = 'https://api.spoonacular.com';
  
  static String get _apiKey {
    // Validate on first use
    EnvConfig.validateApiKeys();
    return EnvConfig.spoonacularApiKey;
  }
  
  // Rate limiting
  static DateTime? _lastRequestTime;
  static int _requestCount = 0;
  static DateTime _windowStart = DateTime.now();
  static const int _maxRequestsPerHour = 150;
  static const Duration _minRequestInterval = Duration(milliseconds: 100);
  
  // Enhanced caching with TTL
  static final Map<String, CacheEntry> _recipeCache = {};
  
  static Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    
    if (now.difference(_windowStart).inHours >= 1) {
      _requestCount = 0;
      _windowStart = now;
    }
    
    if (_requestCount >= _maxRequestsPerHour) {
      throw SpoonacularException(
        SpoonacularError.quotaExceeded,
        'Spoonacular API hourly limit reached',
      );
    }
    
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - timeSinceLastRequest);
      }
    }
    
    _lastRequestTime = DateTime.now();
    _requestCount++;
  }

  /// Generate consistent cache keys
  static String _generateCacheKey({
    String? query,
    String? diet,
    String? mealType,
    int maxCarbs = 30,
    int maxSugar = 15,
    int number = 20,
    int offset = 0,
  }) {
    return 'search_${query ?? ''}_${diet ?? ''}_${mealType ?? ''}_${maxCarbs}_${maxSugar}_${number}_$offset';
  }

  /// Search for diabetes-friendly recipes with enhanced filtering
  static Future<List<Recipe>> searchRecipes({
    String? query,
    String? diet,
    String? mealType,
    int maxCarbs = 30,
    int maxSugar = 15,
    int number = 20,
    int offset = 0,
  }) async {
    // Generate cache key
    final cacheKey = _generateCacheKey(
      query: query,
      diet: diet,
      mealType: mealType,
      maxCarbs: maxCarbs,
      maxSugar: maxSugar,
      number: number,
      offset: offset,
    );

    // Check cache first
    if (_recipeCache.containsKey(cacheKey)) {
      final cacheEntry = _recipeCache[cacheKey]!;
      if (!cacheEntry.isExpired) {
        debugPrint('🎯 Using cached recipes for: $cacheKey');
        return cacheEntry.recipes;
      } else {
        // Remove expired entry
        _recipeCache.remove(cacheKey);
      }
    }

    try {
      await _checkRateLimit();

      final queryParams = {
        'apiKey': _apiKey,
        'query': query ?? '',
        'type': mealType ?? '',
        'diet': diet ?? 'diabetic',
        'maxCarbs': maxCarbs.toString(),
        'maxSugar': maxSugar.toString(),
        'minFiber': '3',
        'number': number.toString(),
        'offset': offset.toString(),
        'addRecipeInformation': 'true',
        'fillIngredients': 'true',
        'addRecipeNutrition': 'true',
        'instructionsRequired': 'true',
        'sort': 'healthiness',
        'sortDirection': 'desc',
      };

      final uri = Uri.parse('$_baseUrl/recipes/complexSearch')
          .replace(queryParameters: queryParams);

      debugPrint('🌐 Making API request to Spoonacular...');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        final recipes = <Recipe>[];
        int filteredCount = 0;
        
        for (final recipeData in results) {
          try {
            final recipe = _convertAndCleanSpoonacularRecipe(recipeData);
            if (_isHighQualityRecipe(recipe)) {
              recipes.add(recipe);
            }
          } catch (e) {
            filteredCount++;
            debugPrint('Filtered out recipe: $e');
            continue;
          }
        }
        
        debugPrint('✅ Processed ${results.length} recipes, kept ${recipes.length}, filtered $filteredCount');
        
        // Store in cache
        _recipeCache[cacheKey] = CacheEntry(recipes, DateTime.now());
        debugPrint('💾 Cached ${recipes.length} recipes for: $cacheKey');
        
        return recipes;
      } else {
        throw _handleApiError(response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      rethrow;
    }
  }

  /// Get diabetes-friendly recipes
  static Future<List<Recipe>> getDiabeticFriendlyRecipes({
    String? category,
    int number = 50,
  }) async {
    final cacheKey = 'diabetic_friendly_${category ?? 'all'}_$number';
    
    // Check cache first
    if (_recipeCache.containsKey(cacheKey)) {
      final cacheEntry = _recipeCache[cacheKey]!;
      if (!cacheEntry.isExpired) {
        debugPrint('🎯 Using cached diabetic recipes');
        return cacheEntry.recipes;
      } else {
        _recipeCache.remove(cacheKey);
      }
    }

    final List<Recipe> allRecipes = [];
    
    final searchTerms = [
      'low carb breakfast',
      'diabetic lunch', 
      'sugar free dessert',
      'high fiber dinner',
      'diabetic snacks',
      'low glycemic',
      'whole grain',
      'lean protein',
    ];
    
    for (final term in searchTerms) {
      try {
        final recipes = await searchRecipes(
          query: term,
          number: (number / searchTerms.length).ceil(),
        );
        allRecipes.addAll(recipes);
        
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('Error fetching recipes for "$term": $e');
        continue;
      }
    }
    
    final uniqueRecipes = _removeDuplicateRecipes(allRecipes);
    uniqueRecipes.shuffle();
    final finalRecipes = uniqueRecipes.take(number).toList();
    
    // Store in cache
    _recipeCache[cacheKey] = CacheEntry(finalRecipes, DateTime.now());
    debugPrint('💾 Cached ${finalRecipes.length} diabetic-friendly recipes');
    
    return finalRecipes;
  }

  /// Search by ingredients
  static Future<List<Recipe>> searchByIngredients(List<String> ingredients) async {
    try {
      await _checkRateLimit();

      final ingredientsString = ingredients.join(',+');
      
      final uri = Uri.parse('$_baseUrl/recipes/findByIngredients')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'ingredients': ingredientsString,
        'number': '20',
        'ranking': '2',
        'ignorePantry': 'false',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        List<Recipe> recipes = [];
        for (var item in data.take(10)) {
          try {
            final recipe = await getRecipeDetails(item['id']);
            if (recipe != null) {
              recipes.add(recipe);
            }
          } catch (e) {
            debugPrint('Skipping recipe ${item['id']} due to error: $e');
            continue;
          }
        }
        
        return recipes;
      } else {
        throw _handleApiError(response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint('Error searching by ingredients: $e');
      return [];
    }
  }

  /// Get detailed recipe information
  static Future<Recipe?> getRecipeDetails(int spoonacularId) async {
    try {
      await _checkRateLimit();

      final uri = Uri.parse('$_baseUrl/recipes/$spoonacularId/information')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'includeNutrition': 'true',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _convertAndCleanSpoonacularRecipe(data);
      } else {
        debugPrint('Failed to get recipe details: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting recipe details: $e');
      return null;
    }
  }

  /// Convert Spoonacular data to cleaned Recipe model
  static Recipe _convertAndCleanSpoonacularRecipe(Map<String, dynamic> spoonacularData) {
    // Extract enhanced nutrition information
    final nutrition = _extractNutritionInfo(spoonacularData);
    
    // Extract raw ingredients and instructions (before cleaning)
    final rawIngredients = _extractRawIngredients(spoonacularData);
    final rawInstructions = _extractRawInstructions(spoonacularData);
    
    // Determine accurate category and cuisine
    final category = _determineCategory(spoonacularData);
    final cuisine = _determineCuisine(spoonacularData);
    
    // Get high-quality image
    final imageUrl = _getOptimalImageUrl(spoonacularData);
    
    // Create raw recipe with unprocessed data
    final rawRecipe = Recipe(
      id: spoonacularData['id'] ?? Random().nextInt(999999),
      title: spoonacularData['title'] ?? 'Unknown Recipe',
      image: imageUrl,
      carbs: nutrition['carbs']?.round() ?? 0,
      sugar: nutrition['sugar']?.round() ?? 0,
      calories: nutrition['calories']?.round() ?? 0,
      category: category,
      cuisine: cuisine,
      ingredients: rawIngredients,
      instructions: rawInstructions,
    );
    
    // Now clean it using RecipeCleanerService
    try {
      final cleanedRecipe = RecipeCleanerService.cleanRecipe(rawRecipe);
      return cleanedRecipe;
    } catch (e) {
      debugPrint('Recipe filtered out: ${rawRecipe.title} - $e');
      throw Exception('Recipe contains problematic content');
    }
  }

  /// Extract comprehensive nutrition information
  static Map<String, double> _extractNutritionInfo(Map<String, dynamic> data) {
    final nutrition = <String, double>{
      'calories': 0.0,
      'carbs': 0.0,
      'sugar': 0.0,
      'fiber': 0.0,
      'protein': 0.0,
      'fat': 0.0,
      'sodium': 0.0,
    };

    final nutrients = data['nutrition']?['nutrients'] as List<dynamic>? ?? [];
    for (final nutrient in nutrients) {
      final name = nutrient['name']?.toString().toLowerCase() ?? '';
      final amount = (nutrient['amount'] as num?)?.toDouble() ?? 0.0;
      
      if (name.contains('calorie')) nutrition['calories'] = amount;
      else if (name.contains('carbohydrate')) nutrition['carbs'] = amount;
      else if (name.contains('sugar') && !name.contains('added')) nutrition['sugar'] = amount;
      else if (name.contains('fiber')) nutrition['fiber'] = amount;
      else if (name.contains('protein')) nutrition['protein'] = amount;
      else if (name.contains('fat') && !name.contains('trans')) nutrition['fat'] = amount;
      else if (name.contains('sodium')) nutrition['sodium'] = amount / 1000;
    }
    
    // Fallback to summary nutrition
    if (nutrition['calories'] == 0.0) {
      final summary = data['nutrition'] ?? {};
      nutrition['calories'] = (summary['calories'] as num?)?.toDouble() ?? 0.0;
      nutrition['carbs'] = (summary['carbs'] as num?)?.toDouble() ?? 0.0;
      nutrition['protein'] = (summary['protein'] as num?)?.toDouble() ?? 0.0;
      nutrition['fat'] = (summary['fat'] as num?)?.toDouble() ?? 0.0;
    }
    
    return nutrition;
  }

  /// Extract raw ingredients (before cleaning)
  static List<String> _extractRawIngredients(Map<String, dynamic> data) {
    final extendedIngredients = data['extendedIngredients'] as List<dynamic>? ?? [];
    
    if (extendedIngredients.isEmpty) {
      final simple = data['ingredients'] as List<dynamic>? ?? [];
      return simple.map((ing) => ing.toString()).toList();
    }
    
    final ingredients = <String>[];
    for (final ingredient in extendedIngredients) {
      String name = ingredient['original']?.toString() ?? 
                   ingredient['name']?.toString() ?? '';
      
      if (name.isNotEmpty) {
        ingredients.add(name); // Keep original, let cleaner handle it
      }
    }
    
    return ingredients.isEmpty ? ['No ingredients available'] : ingredients;
  }

  /// Extract raw instructions (before cleaning)
  static List<String> _extractRawInstructions(Map<String, dynamic> data) {
    final analyzedInstructions = data['analyzedInstructions'] as List<dynamic>? ?? [];
    
    if (analyzedInstructions.isEmpty) {
      final summary = data['summary']?.toString() ?? '';
      final instructions = data['instructions']?.toString() ?? '';
      
      if (instructions.isNotEmpty) {
        return _parseInstructionsText(instructions);
      } else if (summary.isNotEmpty) {
        return _parseInstructionsText(summary);
      } else {
        return ['Follow recipe with provided ingredients.'];
      }
    }
    
    final rawInstructions = <String>[];
    
    for (final instructionGroup in analyzedInstructions) {
      final steps = instructionGroup['steps'] as List<dynamic>? ?? [];
      
      for (final step in steps) {
        final stepText = step['step']?.toString() ?? '';
        if (stepText.isNotEmpty) {
          rawInstructions.add(stepText); // Keep raw, let cleaner handle it
        }
      }
    }
    
    return rawInstructions.isEmpty 
        ? ['Prepare according to ingredients listed above.']
        : rawInstructions;
  }

  /// Parse instructions from text
  static List<String> _parseInstructionsText(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final steps = cleaned
        .split(RegExp(r'[.!]\s+|\d+\.\s+'))
        .where((step) => step.trim().length > 10)
        .map((step) => step.trim())
        .toList();
    
    return steps.isEmpty ? ['Follow recipe as described.'] : steps;
  }

  /// Determine category
  static String _determineCategory(Map<String, dynamic> data) {
    final dishTypes = (data['dishTypes'] as List<dynamic>? ?? [])
        .map((type) => type.toString().toLowerCase())
        .toList();
    
    for (final dishType in dishTypes) {
      if (dishType.contains('breakfast') || dishType.contains('brunch')) return 'Breakfast';
      if (dishType.contains('lunch') || dishType.contains('main course')) return 'Lunch';
      if (dishType.contains('dinner') || dishType.contains('supper')) return 'Dinner';
      if (dishType.contains('snack') || dishType.contains('appetizer')) return 'Snacks';
      if (dishType.contains('dessert') || dishType.contains('sweet')) return 'Dessert';
    }
    
    final readyInMinutes = data['readyInMinutes'] as int? ?? 30;
    if (readyInMinutes <= 15) return 'Snacks';
    if (readyInMinutes <= 30) return 'Breakfast';
    
    return 'Lunch';
  }

  /// Determine cuisine
  static String _determineCuisine(Map<String, dynamic> data) {
    final cuisines = (data['cuisines'] as List<dynamic>? ?? [])
        .map((cuisine) => cuisine.toString())
        .toList();
    
    if (cuisines.isNotEmpty) {
      return cuisines.first;
    }
    
    final title = data['title']?.toString().toLowerCase() ?? '';
    if (title.contains('italian') || title.contains('pasta')) return 'Italian';
    if (title.contains('mexican') || title.contains('taco')) return 'Mexican';
    if (title.contains('asian') || title.contains('stir fry')) return 'Asian';
    if (title.contains('mediterranean')) return 'Mediterranean';
    if (title.contains('indian') || title.contains('curry')) return 'Indian';
    
    return 'American';
  }

  /// Get optimal image URL
  static String _getOptimalImageUrl(Map<String, dynamic> data) {
    String imageUrl = data['image']?.toString() ?? '';
    
    if (imageUrl.isNotEmpty) {
      if (!imageUrl.contains('312x231') && !imageUrl.contains('556x370')) {
        imageUrl = imageUrl.replaceAll(RegExp(r'\d+x\d+'), '556x370');
      }
      return imageUrl;
    }
    
    final category = _determineCategory(data).toLowerCase();
    final placeholders = {
      'breakfast': 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=400&h=400&fit=crop',
      'lunch': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=400&fit=crop',
      'dinner': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400&h=400&fit=crop',
      'snacks': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=400&fit=crop',
      'dessert': 'https://images.unsplash.com/photo-1488900128323-21503983a07e?w=400&h=400&fit=crop',
    };
    
    return placeholders[category] ?? 'https://images.unsplash.com/photo-1546548970-71785318a17b?w=400&h=400&fit=crop';
  }

  /// Check recipe quality (after cleaning)
  static bool _isHighQualityRecipe(Recipe recipe) {
    if (recipe.calories == 0 && recipe.carbs == 0) return false;
    if (recipe.ingredients.length < 2 || recipe.ingredients.length > 25) return false;
    if (recipe.instructions.length < 2 || recipe.instructions.length > 20) return false;
    if (recipe.carbs > 45 || recipe.sugar > 25) return false;
    if (recipe.title.length < 5 || recipe.title.toLowerCase().contains('unknown')) return false;
    
    // Additional validation using RecipeCleanerService
    return RecipeCleanerService.isValidRecipe(recipe);
  }

  /// Remove duplicates
  static List<Recipe> _removeDuplicateRecipes(List<Recipe> recipes) {
    final uniqueRecipes = <Recipe>[];
    final seenTitles = <String>{};
    
    for (final recipe in recipes) {
      final normalizedTitle = recipe.title.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      if (!seenTitles.contains(normalizedTitle)) {
        seenTitles.add(normalizedTitle);
        uniqueRecipes.add(recipe);
      }
    }
    
    return uniqueRecipes;
  }

  // Error handling
  static SpoonacularException _handleApiError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return SpoonacularException(
          SpoonacularError.invalidApiKey,
          'Invalid API key. Please check your Spoonacular API key.',
          statusCode,
        );
      case 402:
        return SpoonacularException(
          SpoonacularError.quotaExceeded,
          'API quota exceeded. Please upgrade your plan or try again tomorrow.',
          statusCode,
        );
      case 429:
        return SpoonacularException(
          SpoonacularError.rateLimitExceeded,
          'Rate limit exceeded. Please wait a moment before making more requests.',
          statusCode,
        );
      default:
        return SpoonacularException(
          SpoonacularError.unknownError,
          'API request failed with status $statusCode',
          statusCode,
        );
    }
  }
  
  /// Clear cache
  static void clearCache() {
    _recipeCache.clear();
  }
  
  /// Get API usage statistics
  static Map<String, dynamic> getApiStats() {
    return {
      'requests_this_hour': _requestCount,
      'cache_entries': _recipeCache.length,
      'rate_limit_remaining': _maxRequestsPerHour - _requestCount,
    };
  }
}