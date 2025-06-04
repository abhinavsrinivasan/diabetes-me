// lib/services/spoonacular_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../features/recipes/models/recipe.dart';

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
  static const String _baseUrl = 'https://api.spoonacular.com';
  
  // API Key management - prioritize environment variable
  static String get _apiKey {
    const apiKey = String.fromEnvironment('SPOONACULAR_API_KEY');
    if (apiKey.isNotEmpty) {
      return apiKey;
    }
    
    // Fallback to hardcoded key for development (replace with your actual key)
    const fallbackKey = 'dd6b4d10cbf0480c8c0e6fc7f5e9a317';
    if (fallbackKey.isEmpty || fallbackKey == 'your-api-key-here') {
      throw Exception('SPOONACULAR_API_KEY not configured. Please set environment variable or update fallback key.');
    }
    
    return fallbackKey;
  }
  
  // Rate limiting properties
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 100); // 10 requests/second max
  static int _requestCount = 0;
  static DateTime _windowStart = DateTime.now();
  static const int _maxRequestsPerHour = 150; // Spoonacular free tier limit
  
  // Caching
  static final Map<String, CacheEntry> _recipeCache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  // Rate limiting check
  static Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    
    // Reset hourly counter if needed
    if (now.difference(_windowStart).inHours >= 1) {
      _requestCount = 0;
      _windowStart = now;
      debugPrint('Spoonacular rate limit counter reset');
    }
    
    // Check hourly limit
    if (_requestCount >= _maxRequestsPerHour) {
      throw SpoonacularException(
        SpoonacularError.quotaExceeded,
        'Spoonacular API hourly limit reached ($_maxRequestsPerHour requests). Please try again later.',
      );
    }
    
    // Check request interval
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - timeSinceLastRequest);
      }
    }
    
    _lastRequestTime = DateTime.now();
    _requestCount++;
    
    debugPrint('Spoonacular API call #$_requestCount this hour');
  }

  // Enhanced error handling
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
      case 403:
        return SpoonacularException(
          SpoonacularError.quotaExceeded,
          'Daily quota exceeded. Please try again tomorrow.',
          statusCode,
        );
      default:
        return SpoonacularException(
          SpoonacularError.unknownError,
          'API request failed with status $statusCode: $body',
          statusCode,
        );
    }
  }

  // Cache management
  static String _generateCacheKey(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    return sortedKeys.map((key) => '$key:${params[key]}').join('|');
  }

  static List<Recipe>? _getCachedRecipes(String cacheKey) {
    final entry = _recipeCache[cacheKey];
    if (entry != null && !entry.isExpired) {
      debugPrint('Using cached recipes for: $cacheKey');
      return entry.recipes;
    }
    
    if (entry != null && entry.isExpired) {
      _recipeCache.remove(cacheKey);
      debugPrint('Removed expired cache entry: $cacheKey');
    }
    
    return null;
  }

  static void _cacheRecipes(String cacheKey, List<Recipe> recipes) {
    _recipeCache[cacheKey] = CacheEntry(recipes, DateTime.now());
    debugPrint('Cached ${recipes.length} recipes for: $cacheKey');
    
    // Clean up old cache entries if we have too many
    if (_recipeCache.length > 50) {
      final oldestKey = _recipeCache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _recipeCache.remove(oldestKey);
      debugPrint('Removed oldest cache entry: $oldestKey');
    }
  }

  // Search recipes with diabetes-friendly filters
  static Future<List<Recipe>> searchRecipes({
    String? query,
    String? diet,
    String? intolerances,
    int maxCarbs = 50,
    int maxSugar = 20,
    int number = 20,
    int offset = 0,
  }) async {
    try {
      // Check cache first
      final cacheKey = _generateCacheKey({
        'search': query ?? '',
        'diet': diet ?? 'diabetic',
        'maxCarbs': maxCarbs,
        'maxSugar': maxSugar,
        'number': number,
        'offset': offset,
      });
      
      final cachedRecipes = _getCachedRecipes(cacheKey);
      if (cachedRecipes != null) {
        return cachedRecipes;
      }

      await _checkRateLimit();

      final Map<String, dynamic> queryParams = {
        'apiKey': _apiKey,
        'query': query ?? '',
        'diet': diet ?? 'diabetic',
        'intolerances': intolerances ?? '',
        'maxCarbs': maxCarbs.toString(),
        'maxSugar': maxSugar.toString(),
        'number': number.toString(),
        'offset': offset.toString(),
        'addRecipeInformation': 'true',
        'fillIngredients': 'true',
        'addRecipeNutrition': 'true',
        'instructionsRequired': 'true',
      };

      final uri = Uri.parse('$_baseUrl/recipes/complexSearch')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        final recipes = results.map((recipeData) => _convertSpoonacularToRecipe(recipeData)).toList();
        
        // Cache the results
        _cacheRecipes(cacheKey, recipes);
        
        return recipes;
      } else {
        throw _handleApiError(response.statusCode, response.body);
      }
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      throw SpoonacularException(
        SpoonacularError.networkError,
        'Network error: $e',
      );
    }
  }

  // Get detailed recipe information
  static Future<Recipe?> getRecipeDetails(int spoonacularId) async {
    try {
      final cacheKey = _generateCacheKey({'details': spoonacularId});
      final cachedRecipes = _getCachedRecipes(cacheKey);
      if (cachedRecipes != null && cachedRecipes.isNotEmpty) {
        return cachedRecipes.first;
      }

      await _checkRateLimit();

      final uri = Uri.parse('$_baseUrl/recipes/$spoonacularId/information')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'includeNutrition': 'true',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recipe = _convertSpoonacularToRecipe(data);
        
        // Cache single recipe
        _cacheRecipes(cacheKey, [recipe]);
        
        return recipe;
      } else {
        debugPrint('Failed to get recipe details: ${response.statusCode}');
        return null;
      }
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting recipe details: $e');
      return null;
    }
  }

  // Get recipe suggestions based on dietary restrictions
  static Future<List<Recipe>> getDiabeticFriendlyRecipes({
    String category = '',
    int number = 20,
  }) async {
    try {
      return await searchRecipes(
        diet: 'diabetic',
        query: category,
        maxCarbs: 30,
        maxSugar: 15,
        number: number,
      );
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting diabetic-friendly recipes: $e');
      return [];
    }
  }

  // Search recipes by ingredients (for pantry-based cooking)
  static Future<List<Recipe>> searchByIngredients(List<String> ingredients) async {
    try {
      final cacheKey = _generateCacheKey({'ingredients': ingredients.join(',')});
      final cachedRecipes = _getCachedRecipes(cacheKey);
      if (cachedRecipes != null) {
        return cachedRecipes;
      }

      await _checkRateLimit();

      final ingredientsString = ingredients.join(',+');
      
      final uri = Uri.parse('$_baseUrl/recipes/findByIngredients')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'ingredients': ingredientsString,
        'number': '20',
        'ranking': '2', // Maximize used ingredients
        'ignorePantry': 'false',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Get full recipe details for each result (limit to avoid too many API calls)
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
        
        // Cache the results
        _cacheRecipes(cacheKey, recipes);
        
        return recipes;
      } else {
        throw _handleApiError(response.statusCode, response.body);
      }
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error searching by ingredients: $e');
      return [];
    }
  }

  // Get nutritional analysis for a recipe
  static Future<Map<String, dynamic>?> getRecipeNutrition(int spoonacularId) async {
    try {
      await _checkRateLimit();

      final uri = Uri.parse('$_baseUrl/recipes/$spoonacularId/nutritionWidget.json')
          .replace(queryParameters: {'apiKey': _apiKey});

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting nutrition data: $e');
      return null;
    }
  }

  // Get random diabetes-friendly recipes
  static Future<List<Recipe>> getRandomDiabeticRecipes({int number = 10}) async {
    try {
      final cacheKey = _generateCacheKey({'random': number, 'timestamp': DateTime.now().hour});
      final cachedRecipes = _getCachedRecipes(cacheKey);
      if (cachedRecipes != null) {
        return cachedRecipes;
      }

      await _checkRateLimit();

      final uri = Uri.parse('$_baseUrl/recipes/random')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'number': number.toString(),
        'tags': 'diabetic,healthy,low-carb',
        'include-nutrition': 'true',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> recipesList = data['recipes'] ?? [];
        
        final recipes = recipesList.map((recipeData) => _convertSpoonacularToRecipe(recipeData)).toList();
        
        // Cache results
        _cacheRecipes(cacheKey, recipes);
        
        return recipes;
      } else {
        throw _handleApiError(response.statusCode, response.body);
      }
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting random recipes: $e');
      return [];
    }
  }

  // Search for recipe substitutions
  static Future<List<Map<String, String>>> getIngredientSubstitutes(String ingredient) async {
    try {
      await _checkRateLimit();

      final uri = Uri.parse('$_baseUrl/food/ingredients/substitutes')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'ingredientName': ingredient,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final substitutes = data['substitutes'] as List<dynamic>? ?? [];
        
        return substitutes.map((sub) => {
          'name': sub.toString(),
          'description': 'Substitute for $ingredient',
        }).cast<Map<String, String>>().toList();
      }
      return [];
    } on SpoonacularException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting substitutes: $e');
      return [];
    }
  }

  // Convert Spoonacular recipe data to your Recipe model
  static Recipe _convertSpoonacularToRecipe(Map<String, dynamic> spoonacularData) {
    // Extract nutrition information
    final nutrition = spoonacularData['nutrition'] ?? {};
    final nutrients = nutrition['nutrients'] as List<dynamic>? ?? [];
    
    // Helper function to find nutrient value
    double findNutrientValue(String name) {
      try {
        final nutrient = nutrients.firstWhere(
          (n) => n['name'].toString().toLowerCase().contains(name.toLowerCase()),
          orElse: () => {'amount': 0.0},
        );
        return (nutrient['amount'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        return 0.0;
      }
    }

    // Calculate glycemic index estimate based on fiber and carbs
    final carbs = findNutrientValue('carbohydrates');
    final fiber = findNutrientValue('fiber');
    final sugar = findNutrientValue('sugar');
    
    // Simple GI estimation (this is approximate)
    int estimatedGI = 55; // Medium GI as default
    if (fiber > 5 && carbs > 0) {
      estimatedGI = ((carbs - fiber) / carbs * 70).round().clamp(25, 85);
    }

    // Extract ingredients
    final extendedIngredients = spoonacularData['extendedIngredients'] as List<dynamic>? ?? [];
    final ingredients = extendedIngredients.map((ing) => ing['original'].toString()).toList();

    // Extract instructions
    final analyzedInstructions = spoonacularData['analyzedInstructions'] as List<dynamic>? ?? [];
    List<String> instructions = [];
    
    if (analyzedInstructions.isNotEmpty) {
      final steps = analyzedInstructions[0]['steps'] as List<dynamic>? ?? [];
      instructions = steps.map((step) => step['step'].toString()).toList();
    }

    // If no analyzed instructions, try the summary or fall back to basic instructions
    if (instructions.isEmpty) {
      final summary = spoonacularData['summary']?.toString() ?? '';
      if (summary.isNotEmpty) {
        instructions = ['Follow the recipe summary: $summary'];
      } else {
        instructions = ['Prepare according to ingredients listed above.'];
      }
    }

    // Determine category based on dish types or meal type
    String category = 'Other';
    final dishTypes = spoonacularData['dishTypes'] as List<dynamic>? ?? [];
    if (dishTypes.isNotEmpty) {
      final dishType = dishTypes.first.toString().toLowerCase();
      if (dishType.contains('breakfast')) category = 'Breakfast';
      else if (dishType.contains('lunch') || dishType.contains('main')) category = 'Lunch';
      else if (dishType.contains('dinner')) category = 'Dinner';
      else if (dishType.contains('snack') || dishType.contains('appetizer')) category = 'Snacks';
      else if (dishType.contains('dessert')) category = 'Dessert';
    }

    // Determine cuisine
    final cuisines = spoonacularData['cuisines'] as List<dynamic>? ?? [];
    String cuisine = cuisines.isNotEmpty ? cuisines.first.toString() : 'American';

    // Get image URL
    String imageUrl = spoonacularData['image'] ?? '';
    if (imageUrl.isEmpty) {
      // Fallback to a placeholder image
      imageUrl = 'https://images.unsplash.com/photo-1546548970-71785318a17b?w=400&h=400&fit=crop';
    }

    return Recipe(
      id: spoonacularData['id'] ?? 0,
      title: spoonacularData['title'] ?? 'Unknown Recipe',
      image: imageUrl,
      carbs: carbs.round(),
      sugar: sugar.round(),
      calories: findNutrientValue('calories').round(),
      category: category,
      cuisine: cuisine,
      glycemicIndex: estimatedGI,
      ingredients: ingredients.isNotEmpty ? ingredients : ['No ingredients available'],
      instructions: instructions,
    );
  }

  // Analyze recipe for diabetes-friendliness
  static Future<Map<String, dynamic>> analyzeDiabetesFriendliness(Recipe recipe) async {
    // This is a local analysis since Spoonacular doesn't have a specific diabetes API
    int score = 100;
    List<String> pros = [];
    List<String> cons = [];
    
    // Analyze carbs
    if (recipe.carbs <= 15) {
      pros.add('Low carbohydrate content (${recipe.carbs}g)');
      score += 10;
    } else if (recipe.carbs <= 30) {
      pros.add('Moderate carbohydrate content (${recipe.carbs}g)');
    } else {
      cons.add('High carbohydrate content (${recipe.carbs}g)');
      score -= 20;
    }
    
    // Analyze sugar
    if (recipe.sugar <= 5) {
      pros.add('Low sugar content (${recipe.sugar}g)');
      score += 10;
    } else if (recipe.sugar <= 15) {
      pros.add('Moderate sugar content (${recipe.sugar}g)');
    } else {
      cons.add('High sugar content (${recipe.sugar}g)');
      score -= 25;
    }
    
    // Analyze glycemic index
    if (recipe.glycemicIndex <= 55) {
      pros.add('Low to medium glycemic index (${recipe.glycemicIndex})');
      score += 5;
    } else {
      cons.add('High glycemic index (${recipe.glycemicIndex})');
      score -= 15;
    }
    
    // Check for diabetes-friendly ingredients
    final friendlyIngredients = ['quinoa', 'brown rice', 'oats', 'sweet potato', 
                                'berries', 'nuts', 'seeds', 'olive oil', 'avocado'];
    final recipeIngredients = recipe.ingredients.join(' ').toLowerCase();
    
    for (String ingredient in friendlyIngredients) {
      if (recipeIngredients.contains(ingredient)) {
        pros.add('Contains diabetes-friendly ingredient: $ingredient');
        score += 5;
      }
    }
    
    score = score.clamp(0, 100);
    
    String rating;
    if (score >= 80) rating = 'Excellent';
    else if (score >= 60) rating = 'Good';
    else if (score >= 40) rating = 'Fair';
    else rating = 'Poor';
    
    return {
      'score': score,
      'rating': rating,
      'pros': pros,
      'cons': cons,
      'recommendation': score >= 60 
          ? 'This recipe is suitable for people with diabetes'
          : 'Consider modifications or eat in smaller portions',
    };
  }

  // Utility methods for cache and rate limit management
  static void clearCache() {
    _recipeCache.clear();
    debugPrint('Spoonacular recipe cache cleared');
  }

  static Map<String, dynamic> getApiStats() {
    return {
      'requests_this_hour': _requestCount,
      'cache_entries': _recipeCache.length,
      'rate_limit_remaining': _maxRequestsPerHour - _requestCount,
      'cache_size_mb': (_recipeCache.length * 0.1).toStringAsFixed(2), // Rough estimate
    };
  }

  static void resetRateLimit() {
    _requestCount = 0;
    _windowStart = DateTime.now();
    debugPrint('Spoonacular rate limit manually reset');
  }
}