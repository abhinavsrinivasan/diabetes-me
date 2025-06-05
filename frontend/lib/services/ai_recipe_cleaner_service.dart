// lib/services/ai_recipe_cleaner_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIRecipeCleanerService {
  static const String _openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _apiKey = "YOUR_OPENAI_API_KEY"; // Replace with actual key

  /// Clean recipe using AI
  static Future<Recipe> cleanRecipeWithAI(Recipe recipe) async {
    try {
      final cleanedData = await _callOpenAI(recipe);
      
      return Recipe(
        id: recipe.id,
        title: cleanedData['title'] ?? recipe.title,
        image: recipe.image,
        carbs: recipe.carbs,
        sugar: recipe.sugar,
        calories: recipe.calories,
        category: recipe.category,
        cuisine: recipe.cuisine,
        glycemicIndex: recipe.glycemicIndex,
        ingredients: List<String>.from(cleanedData['ingredients'] ?? recipe.ingredients),
        instructions: List<String>.from(cleanedData['instructions'] ?? recipe.instructions),
      );
    } catch (e) {
      // Fallback to manual cleaning if AI fails
      return RecipeCleanerService.cleanRecipe(recipe);
    }
  }

  static Future<Map<String, dynamic>> _callOpenAI(Recipe recipe) async {
    final systemPrompt = '''You are a professional recipe editor specializing in standardizing recipes for a diabetes-friendly cooking app. 

Your tasks:
1. Clean and standardize ingredient names (remove measurements, "to taste", "optional", etc.)
2. Fix spelling and grammar errors
3. Rewrite unclear or problematic instructions
4. Remove any promotional content, blog references, or social media mentions
5. Ensure instructions are clear, concise, and actionable

Return ONLY valid JSON in this exact format:
{
  "title": "cleaned recipe title",
  "ingredients": ["ingredient1", "ingredient2", ...],
  "instructions": ["step1", "step2", ...]
}

Rules for ingredients:
- Remove all measurements and quantities
- Remove phrases like "to taste", "optional", "as needed"
- Use simple, standard names (e.g., "Salt" not "Sea salt, to taste")
- Fix spelling errors
- Remove cooking methods from ingredient names

Rules for instructions:
- Each step should be clear and actionable
- Fix spelling and grammar
- Remove any references to blogs, vlogs, websites, or social media
- Replace vague instructions with specific ones
- Ensure proper cooking terminology''';

    final userPrompt = '''Clean this recipe:

Title: ${recipe.title}

Ingredients:
${recipe.ingredients.map((i) => '- $i').join('\n')}

Instructions:
${recipe.instructions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}''';

    final response = await http.post(
      Uri.parse(_openAIUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'max_tokens': 1500,
        'temperature': 0.3, // Lower temperature for more consistent cleaning
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      
      // Clean up the response and parse JSON
      final cleanContent = content.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanContent);
    } else {
      throw Exception('AI cleaning failed: ${response.statusCode}');
    }
  }

  /// Validate recipe quality using AI
  static Future<bool> isRecipeHighQuality(Recipe recipe) async {
    try {
      final result = await _validateQualityWithAI(recipe);
      return result['isHighQuality'] == true;
    } catch (e) {
      // Fallback to manual validation
      return EnhancedSpoonacularService._isHighQualityRecipe(recipe);
    }
  }

  static Future<Map<String, dynamic>> _validateQualityWithAI(Recipe recipe) async {
    final systemPrompt = '''You are a recipe quality assessor for a diabetes-friendly cooking app.

Evaluate if this recipe is high quality and suitable for publication. A high-quality recipe should:
- Have clear, actionable instructions
- Use standard ingredient names
- Be free of promotional content
- Have logical cooking steps
- Be appropriate for home cooking
- Have no spelling/grammar errors

Return ONLY valid JSON:
{
  "isHighQuality": true/false,
  "issues": ["list of specific issues if any"],
  "score": 1-10
}''';

    final userPrompt = '''Evaluate this recipe:

Title: ${recipe.title}
Ingredients: ${recipe.ingredients.join(', ')}
Instructions: ${recipe.instructions.join(' ')}''';

    final response = await http.post(
      Uri.parse(_openAIUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'max_tokens': 500,
        'temperature': 0.2,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return jsonDecode(content);
    } else {
      throw Exception('AI validation failed');
    }
  }
}

// Enhanced service that combines AI with manual cleaning
class SmartRecipeCleanerService {
  static bool _useAI = true; // Toggle for AI usage
  
  /// Clean recipe with AI when possible, fallback to manual
  static Future<Recipe> smartCleanRecipe(Recipe recipe) async {
    if (_useAI) {
      try {
        return await AIRecipeCleanerService.cleanRecipeWithAI(recipe);
      } catch (e) {
        print('AI cleaning failed, using manual cleaning: $e');
        _useAI = false; // Disable AI for this session if it fails
      }
    }
    
    // Manual cleaning fallback
    return RecipeCleanerService.cleanRecipe(recipe);
  }

  /// Batch clean multiple recipes with rate limiting
  static Future<List<Recipe>> batchCleanRecipes(List<Recipe> recipes) async {
    final cleanedRecipes = <Recipe>[];
    
    for (int i = 0; i < recipes.length; i++) {
      try {
        final cleaned = await smartCleanRecipe(recipes[i]);
        
        // Validate quality
        bool isQuality = true;
        if (_useAI) {
          isQuality = await AIRecipeCleanerService.isRecipeHighQuality(cleaned);
        } else {
          isQuality = EnhancedSpoonacularService._isHighQualityRecipe(cleaned);
        }
        
        if (isQuality) {
          cleanedRecipes.add(cleaned);
        }
        
        // Rate limiting for AI calls
        if (_useAI && i < recipes.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        print('Failed to clean recipe: ${recipes[i].title}');
        continue;
      }
    }
    
    return cleanedRecipes;
  }
}   