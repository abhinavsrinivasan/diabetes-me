// lib/services/spoonacular_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../features/recipes/models/recipe.dart';

class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  static const String _apiKey = 'dd6b4d10cbf0480c8c0e6fc7f5e9a317'; // Replace with your actual API key
  
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

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        return results.map((recipeData) => _convertSpoonacularToRecipe(recipeData)).toList();
      } else {
        debugPrint('Spoonacular API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching recipes: $e');
      rethrow;
    }
  }

  // Get detailed recipe information
  static Future<Recipe?> getRecipeDetails(int spoonacularId) async {
    try {
      final uri = Uri.parse('$_baseUrl/recipes/$spoonacularId/information')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'includeNutrition': 'true',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _convertSpoonacularToRecipe(data);
      } else {
        debugPrint('Failed to get recipe details: ${response.statusCode}');
        return null;
      }
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
    } catch (e) {
      debugPrint('Error getting diabetic-friendly recipes: $e');
      return [];
    }
  }

  // Search recipes by ingredients (for pantry-based cooking)
  static Future<List<Recipe>> searchByIngredients(List<String> ingredients) async {
    try {
      final ingredientsString = ingredients.join(',+');
      
      final uri = Uri.parse('$_baseUrl/recipes/findByIngredients')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'ingredients': ingredientsString,
        'number': '20',
        'ranking': '2', // Maximize used ingredients
        'ignorePantry': 'false',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Get full recipe details for each result
        List<Recipe> recipes = [];
        for (var item in data.take(10)) { // Limit to avoid too many API calls
          final recipe = await getRecipeDetails(item['id']);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
        
        return recipes;
      } else {
        throw Exception('Failed to search by ingredients: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching by ingredients: $e');
      return [];
    }
  }

  // Get nutritional analysis for a recipe
  static Future<Map<String, dynamic>?> getRecipeNutrition(int spoonacularId) async {
    try {
      final uri = Uri.parse('$_baseUrl/recipes/$spoonacularId/nutritionWidget.json')
          .replace(queryParameters: {'apiKey': _apiKey});

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting nutrition data: $e');
      return null;
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

    return Recipe(
      id: spoonacularData['id'] ?? 0,
      title: spoonacularData['title'] ?? 'Unknown Recipe',
      image: spoonacularData['image'] ?? '',
      carbs: carbs.round(),
      sugar: sugar.round(),
      calories: findNutrientValue('calories').round(),
      category: category,
      cuisine: cuisine,
      glycemicIndex: estimatedGI,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  // Get random diabetes-friendly recipes
  static Future<List<Recipe>> getRandomDiabeticRecipes({int number = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/recipes/random')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'number': number.toString(),
        'tags': 'diabetic,healthy,low-carb',
        'include-nutrition': 'true',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> recipes = data['recipes'] ?? [];
        
        return recipes.map((recipeData) => _convertSpoonacularToRecipe(recipeData)).toList();
      } else {
        throw Exception('Failed to get random recipes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting random recipes: $e');
      return [];
    }
  }

  // Search for recipe substitutions
  static Future<List<Map<String, String>>> getIngredientSubstitutes(String ingredient) async {
    try {
      final uri = Uri.parse('$_baseUrl/food/ingredients/substitutes')
          .replace(queryParameters: {
        'apiKey': _apiKey,
        'ingredientName': ingredient,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final substitutes = data['substitutes'] as List<dynamic>? ?? [];
        
        return substitutes.map((sub) => {
          'name': sub.toString(),
          'description': 'Substitute for $ingredient',
        }).cast<Map<String, String>>().toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting substitutes: $e');
      return [];
    }
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
}