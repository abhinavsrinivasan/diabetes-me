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
  
  // HARDCODED API KEY FOR DEVELOPMENT - REMOVE IN PRODUCTION!
  static const String _hardcodedApiKey = "OPENAI_API_KEY"; // Replace with your actual key
  OPENAI_API_KEY
  // Cache for API responses to save costs and improve performance
  static final Map<String, IngredientInsight> _cache = {};
  
  static Future<IngredientInsight?> getIngredientInsight({
    required String ingredient,
    required String recipeTitle,
    String? recipeCategory,
  }) async {
    try {
      // Always use hardcoded key for now
      if (_hardcodedApiKey.isEmpty || !_hardcodedApiKey.startsWith('sk-')) {
        debugPrint('No valid hardcoded API key found');
        return null;
      }

      // Check cache first
      final cacheKey = '${ingredient.toLowerCase()}_${recipeTitle.toLowerCase()}';
      if (_cache.containsKey(cacheKey)) {
        debugPrint('Using cached insight for $ingredient');
        return _cache[cacheKey]!;
      }

      debugPrint('Using OpenAI API for $ingredient');
      final insight = await _getOpenAIInsight(ingredient, recipeTitle, recipeCategory);
      
      // Cache the result
      _cache[cacheKey] = insight;
      return insight;
      
    } catch (e) {
      debugPrint('Error getting ingredient insight: $e');
      return null;
    }
  }

  static Future<IngredientInsight> _getOpenAIInsight(
    String ingredient, 
    String recipeTitle, 
    String? recipeCategory
  ) async {
    // Use hardcoded API key
    final apiKey = _hardcodedApiKey;

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

  // Modified API Key Management methods to always return true for hardcoded key
  static Future<String?> _getOpenAIApiKey() async {
    return _hardcodedApiKey;
  }

  static Future<void> setOpenAIApiKey(String apiKey) async {
    // For now, just store in secure storage but use hardcoded key
    await _storage.write(key: 'openai_api_key', value: apiKey.trim());
    _cache.clear();
  }

  static Future<void> clearOpenAIApiKey() async {
    await _storage.delete(key: 'openai_api_key');
    _cache.clear();
  }

  static Future<bool> hasOpenAIApiKey() async {
    // Always return true since we have hardcoded key
    return _hardcodedApiKey.isNotEmpty && _hardcodedApiKey.startsWith('sk-');
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