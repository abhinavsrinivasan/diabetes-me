import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IngredientInsight {
  final String ingredient;
  final String quickInsight;
  final String diabetesContext;
  final List<IngredientSubstitute> substitutions;

  IngredientInsight({
    required this.ingredient,
    required this.quickInsight,
    required this.diabetesContext,
    required this.substitutions,
  });

  factory IngredientInsight.fromJson(Map<String, dynamic> json) {
    return IngredientInsight(
      ingredient: json['ingredient'] ?? '',
      quickInsight: json['quickInsight'] ?? '',
      diabetesContext: json['diabetesContext'] ?? '',
      substitutions: (json['substitutions'] as List<dynamic>?)
          ?.map((sub) => IngredientSubstitute.fromJson(sub))
          .toList() ?? [],
    );
  }
}

class IngredientSubstitute {
  final String name;
  final String icon;
  final String description;
  final String benefit;

  IngredientSubstitute({
    required this.name,
    required this.icon,
    required this.description,
    required this.benefit,
  });

  factory IngredientSubstitute.fromJson(Map<String, dynamic> json) {
    return IngredientSubstitute(
      name: json['name'] ?? '',
      icon: json['icon'] ?? '🥄',
      description: json['description'] ?? '',
      benefit: json['benefit'] ?? '',
    );
  }
}

class IngredientIntelligenceService {
  static const String _openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const _storage = FlutterSecureStorage();
  
  // Cache for API responses to save costs and improve performance
  static final Map<String, IngredientInsight> _cache = {};
  
  static Future<IngredientInsight> getIngredientInsight({
    required String ingredient,
    required String recipeTitle,
    String? recipeCategory,
  }) async {
    try {
      // Check cache first
      final cacheKey = '${ingredient.toLowerCase()}_${recipeTitle.toLowerCase()}';
      if (_cache.containsKey(cacheKey)) {
        debugPrint('Using cached insight for $ingredient');
        return _cache[cacheKey]!;
      }

      IngredientInsight insight;
      
      // Check if we have an API key and should use real OpenAI
      final hasApiKey = await hasOpenAIApiKey();
      
      if (hasApiKey) {
        debugPrint('Using OpenAI API for $ingredient');
        insight = await _getOpenAIInsight(ingredient, recipeTitle, recipeCategory);
      } else {
        debugPrint('Using mock data for $ingredient');
        insight = await _getMockInsight(ingredient, recipeTitle);
      }
      
      // Cache the result
      _cache[cacheKey] = insight;
      return insight;
      
    } catch (e) {
      debugPrint('Error getting ingredient insight: $e');
      // Fallback to mock data if OpenAI fails
      return await _getMockInsight(ingredient, recipeTitle);
    }
  }

  static Future<IngredientInsight> _getOpenAIInsight(
    String ingredient, 
    String recipeTitle, 
    String? recipeCategory
  ) async {
    final apiKey = await _getOpenAIApiKey();
    if (apiKey == null) {
      throw Exception('OpenAI API key not found');
    }

    final systemPrompt = '''You are a diabetes-friendly cooking assistant. Analyze ingredients and provide helpful substitutions for people managing diabetes.

Always respond with valid JSON in exactly this format:
{
  "ingredient": "ingredient name",
  "quickInsight": "Brief explanation of what this ingredient does in the recipe (flavor, texture, nutrition) - 1-2 sentences max, friendly tone",
  "diabetesContext": "How this ingredient affects blood sugar and diabetes management - 1-2 sentences, educational but not medical advice",
  "substitutions": [
    {
      "name": "Substitute name",
      "icon": "appropriate single emoji like 🧀🥑🌿🥜🍄",
      "description": "Brief description of the substitute - how it compares",
      "benefit": "Why it's better for diabetes/health - be specific"
    }
  ]
}

Provide exactly 3 practical substitutions that are:
1. Diabetes-friendly (lower carbs/sugar/glycemic index)
2. Available in most grocery stores  
3. Similar cooking behavior or flavor profile

Keep all text concise, friendly, and health-literate. No medical advice, just nutritional information.''';

    final userPrompt = '''Analyze the ingredient "$ingredient" in the recipe "$recipeTitle"${recipeCategory != null ? ' (category: $recipeCategory)' : ''}.

Provide insights about its role in the recipe and 3 diabetes-friendly substitutions.''';

    try {
      final response = await http.post(
        Uri.parse(_openAIUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'max_tokens': 800,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Clean up the response (remove markdown formatting if present)
        final cleanContent = content.replaceAll('```json', '').replaceAll('```', '').trim();
        
        try {
          final insightData = jsonDecode(cleanContent);
          return IngredientInsight.fromJson(insightData);
        } catch (parseError) {
          debugPrint('Error parsing OpenAI response: $parseError');
          debugPrint('Response content: $cleanContent');
          throw Exception('Failed to parse OpenAI response');
        }
      } else {
        final errorBody = response.body;
        debugPrint('OpenAI API error: ${response.statusCode} - $errorBody');
        
        // Handle specific error cases
        if (response.statusCode == 401) {
          throw Exception('Invalid API key. Please check your OpenAI API key.');
        } else if (response.statusCode == 429) {
          throw Exception('Rate limit exceeded. Please try again later.');
        } else {
          throw Exception('OpenAI API request failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Network error calling OpenAI: $e');
      throw Exception('Failed to connect to OpenAI: $e');
    }
  }

  // API Key Management
  static Future<String?> _getOpenAIApiKey() async {
    return await _storage.read(key: 'openai_api_key');
  }

  static Future<void> setOpenAIApiKey(String apiKey) async {
    await _storage.write(key: 'openai_api_key', value: apiKey.trim());
    // Clear cache when API key changes
    _cache.clear();
  }

  static Future<void> clearOpenAIApiKey() async {
    await _storage.delete(key: 'openai_api_key');
    // Clear cache when API key is removed
    _cache.clear();
  }

  static Future<bool> hasOpenAIApiKey() async {
    final key = await _getOpenAIApiKey();
    return key != null && key.isNotEmpty && key.startsWith('sk-');
  }

  // Test API key validity
  static Future<bool> testOpenAIApiKey() async {
    try {
      final insight = await _getOpenAIInsight('salt', 'Test Recipe', null);
      return insight.ingredient.isNotEmpty;
    } catch (e) {
      debugPrint('API key test failed: $e');
      return false;
    }
  }

  // Mock data implementation (fallback)
  static Future<IngredientInsight> _getMockInsight(String ingredient, String recipeTitle) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    final insights = _getIngredientDatabase();
    final key = ingredient.toLowerCase().trim();
    
    // Find the best match
    for (final entry in insights.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    
    return _getDefaultInsight(ingredient);
  }

  static Map<String, IngredientInsight> _getIngredientDatabase() {
    return {
      'cheddar cheese': IngredientInsight(
        ingredient: 'Cheddar Cheese',
        quickInsight: 'This ingredient adds creamy texture and sharp, salty flavor. It also contributes protein and fat, helping with satiety. However, it can be high in saturated fat and sodium.',
        diabetesContext: 'Cheddar is fine in moderation, but full-fat versions may raise cholesterol over time. For people with diabetes, it\'s best used in small amounts as part of a balanced meal.',
        substitutions: [
          IngredientSubstitute(
            name: 'Low-fat cottage cheese',
            icon: '🥣',
            description: 'Similar creaminess, lower fat and sodium',
            benefit: 'Higher protein, fewer calories',
          ),
          IngredientSubstitute(
            name: 'Goat cheese',
            icon: '🧀',
            description: 'Tangy flavor, easier to digest',
            benefit: 'Used in smaller amounts, lower lactose',
          ),
          IngredientSubstitute(
            name: 'Nutritional yeast',
            icon: '🌟',
            description: 'Dairy-free, cheesy flavor',
            benefit: 'Rich in B vitamins, vegan-friendly',
          ),
        ],
      ),
      'bell peppers': IngredientInsight(
        ingredient: 'Bell Peppers',
        quickInsight: 'Bell peppers add sweetness, crunch, and vibrant color. They\'re rich in vitamin C and antioxidants while being naturally low in calories and carbs.',
        diabetesContext: 'Excellent choice for diabetes! Bell peppers are very low in carbs (about 4g per cup) and have minimal impact on blood sugar. The fiber helps slow digestion.',
        substitutions: [
          IngredientSubstitute(
            name: 'Zucchini',
            icon: '🥒',
            description: 'Similar mild flavor and crunch',
            benefit: 'Even lower in carbs, high water content',
          ),
          IngredientSubstitute(
            name: 'Mushrooms',
            icon: '🍄',
            description: 'Earthy flavor, meaty texture',
            benefit: 'Very low carbs, adds umami flavor',
          ),
          IngredientSubstitute(
            name: 'Broccoli florets',
            icon: '🥦',
            description: 'Slightly bitter, great crunch',
            benefit: 'High fiber, packed with nutrients',
          ),
        ],
      ),
      'olive oil': IngredientInsight(
        ingredient: 'Olive Oil',
        quickInsight: 'Olive oil provides healthy monounsaturated fats and helps with cooking and flavor. It\'s calorie-dense but offers heart-healthy benefits when used in moderation.',
        diabetesContext: 'Great choice for diabetes! Olive oil doesn\'t raise blood sugar and may help improve insulin sensitivity. However, it\'s high in calories, so use sparingly.',
        substitutions: [
          IngredientSubstitute(
            name: 'Avocado oil',
            icon: '🥑',
            description: 'Higher smoke point, neutral flavor',
            benefit: 'Great for high-heat cooking',
          ),
          IngredientSubstitute(
            name: 'Coconut oil spray',
            icon: '🥥',
            description: 'Much lower calories per serving',
            benefit: 'Reduces overall calorie content',
          ),
          IngredientSubstitute(
            name: 'Vegetable broth',
            icon: '🍲',
            description: 'Oil-free sautéing option',
            benefit: 'Virtually no calories, adds flavor',
          ),
        ],
      ),
      'greek yogurt': IngredientInsight(
        ingredient: 'Greek Yogurt',
        quickInsight: 'Greek yogurt provides creamy texture, tangy flavor, and high protein content. It\'s thicker than regular yogurt due to the straining process that removes whey.',
        diabetesContext: 'Excellent for diabetes! Greek yogurt is high in protein, which helps stabilize blood sugar. Choose plain, unsweetened varieties to avoid added sugars.',
        substitutions: [
          IngredientSubstitute(
            name: 'Cottage cheese',
            icon: '🥛',
            description: 'Similar protein content, mild flavor',
            benefit: 'Often lower in carbs, budget-friendly',
          ),
          IngredientSubstitute(
            name: 'Silken tofu',
            icon: '🌱',
            description: 'Creamy texture, neutral flavor',
            benefit: 'Dairy-free, lower in saturated fat',
          ),
          IngredientSubstitute(
            name: 'Cashew cream',
            icon: '🥜',
            description: 'Rich, creamy, slightly sweet',
            benefit: 'Dairy-free, healthy fats',
          ),
        ],
      ),
      'honey': IngredientInsight(
        ingredient: 'Honey',
        quickInsight: 'Honey adds natural sweetness and helps bind ingredients. While it\'s a natural sugar, it\'s still high in carbohydrates and affects blood glucose levels.',
        diabetesContext: 'Use sparingly with diabetes. Honey has a lower glycemic index than table sugar, but still raises blood sugar. A little goes a long way for flavor.',
        substitutions: [
          IngredientSubstitute(
            name: 'Stevia',
            icon: '🌿',
            description: 'Natural, zero-calorie sweetener',
            benefit: 'No impact on blood sugar',
          ),
          IngredientSubstitute(
            name: 'Sugar-free maple syrup',
            icon: '🍁',
            description: 'Similar flavor profile',
            benefit: 'Lower carbs, diabetes-friendly',
          ),
          IngredientSubstitute(
            name: 'Cinnamon',
            icon: '🌰',
            description: 'Natural sweetness enhancer',
            benefit: 'May help with insulin sensitivity',
          ),
        ],
      ),
      'chicken breast': IngredientInsight(
        ingredient: 'Chicken Breast',
        quickInsight: 'Chicken breast is a lean protein source that provides structure and satiety to meals. It\'s versatile and takes on flavors well while being naturally low in carbs.',
        diabetesContext: 'Perfect for diabetes! Chicken breast is pure protein with zero carbs, helping to stabilize blood sugar and promote feelings of fullness.',
        substitutions: [
          IngredientSubstitute(
            name: 'Turkey breast',
            icon: '🦃',
            description: 'Similar lean protein profile',
            benefit: 'Slightly lower in calories',
          ),
          IngredientSubstitute(
            name: 'Tofu',
            icon: '🌱',
            description: 'Plant-based protein',
            benefit: 'Lower in saturated fat, vegan-friendly',
          ),
          IngredientSubstitute(
            name: 'White fish fillet',
            icon: '🐟',
            description: 'Mild flavor, flaky texture',
            benefit: 'Rich in omega-3 fatty acids',
          ),
        ],
      ),
      'tomato': IngredientInsight(
        ingredient: 'Tomato',
        quickInsight: 'Tomatoes add acidity, umami flavor, and natural sweetness. They provide lycopene and vitamins while being low in calories and carbs.',
        diabetesContext: 'Great for diabetes! Tomatoes are low in carbs (about 5g per medium tomato) and have a low glycemic index. They add flavor without spiking blood sugar.',
        substitutions: [
          IngredientSubstitute(
            name: 'Red bell pepper',
            icon: '🫑',
            description: 'Sweet flavor, similar color',
            benefit: 'Even lower in carbs, more crunch',
          ),
          IngredientSubstitute(
            name: 'Cucumber',
            icon: '🥒',
            description: 'Fresh, mild flavor',
            benefit: 'Very low carbs, high water content',
          ),
          IngredientSubstitute(
            name: 'Radishes',
            icon: '🔴',
            description: 'Peppery flavor, crisp texture',
            benefit: 'Almost zero carbs, adds spice',
          ),
        ],
      ),
    };
  }

  static IngredientInsight _getDefaultInsight(String ingredient) {
    return IngredientInsight(
      ingredient: ingredient,
      quickInsight: 'This ingredient contributes to the recipe\'s flavor, texture, or nutritional profile. Consider how it fits into your overall meal plan and daily nutrition goals.',
      diabetesContext: 'When managing diabetes, consider the carbohydrate content and glycemic impact of this ingredient. Moderation and balance are key to maintaining stable blood sugar.',
      substitutions: [
        IngredientSubstitute(
          name: 'Similar ingredient',
          icon: '🔄',
          description: 'Look for ingredients with similar properties',
          benefit: 'Maintain recipe integrity while meeting your needs',
        ),
        IngredientSubstitute(
          name: 'Lower-carb alternative',
          icon: '📉',
          description: 'Choose options with fewer carbohydrates',
          benefit: 'Better for blood sugar control',
        ),
        IngredientSubstitute(
          name: 'Whole food option',
          icon: '🌿',
          description: 'Select less processed alternatives',
          benefit: 'More nutrients, better for overall health',
        ),
      ],
    );
  }

  // Utility methods for cache management
  static void clearCache() {
    _cache.clear();
    debugPrint('Ingredient insights cache cleared');
  }

  static int getCacheSize() {
    return _cache.length;
  }

  // Get usage statistics
  static Map<String, dynamic> getUsageStats() {
    return {
      'cached_insights': _cache.length,
      'most_queried': _cache.keys.take(5).toList(),
    };
  }
}