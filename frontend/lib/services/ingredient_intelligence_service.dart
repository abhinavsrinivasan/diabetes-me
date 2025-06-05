// lib/services/ingredient_intelligence_service.dart
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
  
  // In-memory cache for insights
  static final Map<String, IngredientInsight> _cache = {};
  
  // Get API key from secure storage or environment
  static Future<String?> _getOpenAIApiKey() async {
    // Try secure storage first
    String? apiKey = await _storage.read(key: 'openai_api_key');
    
    // Fallback to environment variable (for development)
    if (apiKey?.isEmpty ?? true) {
      apiKey = const String.fromEnvironment('OPENAI_API_KEY');
    }
    
    return apiKey?.isNotEmpty == true ? apiKey : null;
  }
  
  static Future<bool> hasOpenAIApiKey() async {
    final apiKey = await _getOpenAIApiKey();
    return apiKey != null && apiKey.startsWith('sk-');
  }
  
  static Future<void> setOpenAIApiKey(String apiKey) async {
    await _storage.write(key: 'openai_api_key', value: apiKey.trim());
    _cache.clear(); // Clear cache when API key changes
  }
  
  static Future<void> clearOpenAIApiKey() async {
    await _storage.delete(key: 'openai_api_key');
    _cache.clear();
  }

  static Future<IngredientInsight?> getIngredientInsight({
    required String ingredient,
    required String recipeTitle,
    String? recipeCategory,
  }) async {
    // Check cache first
    final cacheKey = '${ingredient.toLowerCase()}_${recipeTitle.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final insight = await _getOpenAIInsight(ingredient, recipeTitle, recipeCategory);
      
      // Cache the result
      if (insight != null) {
        _cache[cacheKey] = insight;
      }
      
      return insight;
    } catch (e) {
      debugPrint('Error getting ingredient insight: $e');
      
      // Return fallback insight instead of null
      return _getFallbackInsight(ingredient);
    }
  }

  static Future<IngredientInsight?> _getOpenAIInsight(
    String ingredient, 
    String recipeTitle, 
    String? recipeCategory
  ) async {
    final apiKey = await _getOpenAIApiKey();
    if (apiKey == null) {
      throw Exception('No OpenAI API key configured');
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Clean up the response
        final cleanContent = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        
        try {
          final insightData = jsonDecode(cleanContent);
          return IngredientInsight.fromJson(insightData);
        } catch (parseError) {
          debugPrint('Error parsing OpenAI response: $parseError');
          throw Exception('Failed to parse AI response');
        }
      } else {
        _handleApiError(response.statusCode, response.body);
        return null;
      }
    } catch (e) {
      debugPrint('Network error calling OpenAI: $e');
      throw Exception('Failed to connect to OpenAI: $e');
    }
  }

  static void _handleApiError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        throw Exception('Invalid API key. Please check your OpenAI API key.');
      case 429:
        throw Exception('Rate limit exceeded. Please try again later.');
      case 402:
        throw Exception('API quota exceeded. Please check your billing.');
      default:
        throw Exception('API request failed: $statusCode');
    }
  }

  // Fallback insight when AI is unavailable
  static IngredientInsight _getFallbackInsight(String ingredient) {
    final fallbackSubstitutions = _getFallbackSubstitutions(ingredient);
    
    return IngredientInsight(
      ingredient: ingredient,
      quickInsight: 'This ingredient adds flavor and nutrition to your recipe.',
      diabetesContext: 'Consider portion size and pairing with protein or fiber for blood sugar management.',
      substitutions: fallbackSubstitutions,
    );
  }

  static List<IngredientSubstitute> _getFallbackSubstitutions(String ingredient) {
    final lower = ingredient.toLowerCase();
    
    if (lower.contains('sugar') || lower.contains('honey')) {
      return [
        IngredientSubstitute(
          name: 'Stevia',
          icon: '🌿',
          description: 'Natural zero-calorie sweetener',
          benefit: 'No impact on blood sugar',
        ),
        IngredientSubstitute(
          name: 'Monk Fruit Sweetener',
          icon: '🍈',
          description: 'Natural sweetener with no calories',
          benefit: 'Zero glycemic index',
        ),
        IngredientSubstitute(
          name: 'Erythritol',
          icon: '❄️',
          description: 'Sugar alcohol with minimal calories',
          benefit: 'Very low impact on blood glucose',
        ),
      ];
    }
    
    if (lower.contains('white rice') || lower.contains('rice')) {
      return [
        IngredientSubstitute(
          name: 'Cauliflower Rice',
          icon: '🥦',
          description: 'Low-carb vegetable alternative',
          benefit: '90% fewer carbs than regular rice',
        ),
        IngredientSubstitute(
          name: 'Brown Rice',
          icon: '🌾',
          description: 'Whole grain with more fiber',
          benefit: 'Lower glycemic index than white rice',
        ),
        IngredientSubstitute(
          name: 'Quinoa',
          icon: '🌱',
          description: 'Protein-rich whole grain',
          benefit: 'More protein and fiber',
        ),
      ];
    }
    
    // Generic healthy substitutions
    return [
      IngredientSubstitute(
        name: 'Whole Grain Alternative',
        icon: '🌾',
        description: 'Choose whole grain versions when possible',
        benefit: 'Higher fiber content',
      ),
      IngredientSubstitute(
        name: 'Fresh Herbs',
        icon: '🌿',
        description: 'Add flavor without calories',
        benefit: 'Rich in antioxidants',
      ),
      IngredientSubstitute(
        name: 'Lean Protein',
        icon: '🐟',
        description: 'Help stabilize blood sugar',
        benefit: 'Promotes satiety',
      ),
    ];
  }

  // Test API key validity
  static Future<bool> testOpenAIApiKey() async {
    try {
      final insight = await _getOpenAIInsight('salt', 'Test Recipe', null);
      return insight?.ingredient.isNotEmpty ?? false;
    } catch (e) {
      debugPrint('API key test failed: $e');
      return false;
    }
  }

  // Cache management
  static void clearCache() {
    _cache.clear();
    debugPrint('Ingredient insights cache cleared');
  }

  static int getCacheSize() {
    return _cache.length;
  }

  static Map<String, dynamic> getUsageStats() {
    return {
      'cached_insights': _cache.length,
      'most_queried': _cache.keys.take(5).toList(),
    };
  }
}