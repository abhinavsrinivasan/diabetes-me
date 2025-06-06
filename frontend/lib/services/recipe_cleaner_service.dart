// lib/services/recipe_cleaner_service.dart
import '../features/recipes/models/recipe.dart';

class RecipeCleanerService {
  static final Map<String, String> ingredientStandardization = {
    'saut': 'sauté',
    'saute': 'sauté',
    'sautee': 'sauté',
    'diced': '',
    'chopped': '',
    'minced': '',
    'sliced': '',
    'to taste': '',
    'as needed': '',
    'optional': '',
    'preferably': '',
    'fresh or frozen': '',
    'fresh': '',
    'frozen': '',
    'canned': '',
    'organic': '',
    'for serving': '',
    'for garnish': '',
    'for drizzling': '',
    'about': '',
    'approximately': '',
    'roughly': '',
    '1 cup': '', '2 cups': '', '1 tablespoon': '', '1 tbsp': '',
    '1 teaspoon': '', '1 tsp': '', '1/2 cup': '', '1/4 cup': '',
    '1/3 cup': '', '2/3 cup': '', '3/4 cup': '',
  };

  static final List<String> problemmaticPatterns = [
    // Original patterns
    'check my vlog', 'visit my blog', 'see my website', 'follow me on',
    'subscribe to', 'like and share', 'check out my', 'find the recipe on',
    'full recipe at', 'recipe video', 'watch the video', 'recipe link',
    
    // Spoonacular-specific patterns
    'spoonacular score', 'users who liked', 'brought to you by',
    'blogspot.com', 'wordpress.com', 'amazing score', 'earns an amazing',
    'hit the spot', 'would say it hit', 'recipe also liked',
    'finger foods:', 'power foods', 'skinny kiwifruit', 'skinny broccoli',
    'overall, this recipe', 'plenty of people made', 'people made this recipe',
    'users who liked this', 'also liked', 'frittata muffins',
    'rate this recipe', 'leave a comment', 'nutritional information',
    'original recipe from', 'recipe adapted from', 'find more recipes',
    
    // Website and social media references
    '.com', 'facebook.com', 'instagram.com', 'pinterest.com',
    'youtube.com', 'twitter.com', 'tiktok.com', 'snapchat.com',
    'fullbellysisters', 'food network', 'cooking channel',
    'recipe courtesy', 'adapted from', 'inspired by',
    
    // Marketing and promotional content
    'amazing spoonacular', 'fantastic spoonacular', 'incredible score',
    'recipe earns', 'score of', 'rated this recipe', 'give this recipe',
    'love this recipe', 'try this recipe', 'make this recipe',
    'recipe is perfect', 'recipe is amazing', 'recipe is incredible',
    
    // Blog-style commentary
    'i hope you', 'i think you', 'i know you', 'you will love',
    'let me know', 'tell me', 'comment below', 'share your',
    'what do you think', 'have you tried', 'would you make',
    
    // Recipe sharing platforms
    'allrecipes', 'food.com', 'epicurious', 'bon appetit',
    'serious eats', 'the kitchn', 'taste of home',
  ];

  static final List<String> problematicInstructions = [
    'check my vlog', 'see video', 'watch tutorial', 'visit website',
    'follow link', 'see blog post', 'check out the recipe',
    'find the full recipe', 'get the recipe', 'recipe can be found',
    'visit my blog', 'check my website', 'follow me',
    'subscribe to my', 'like this recipe', 'rate this recipe',
    'leave a comment', 'tell me what you think', 'let me know',
    'share this recipe', 'pin this recipe', 'tweet this',
    'post on facebook', 'instagram this', 'tag me',
  ];

  static Recipe cleanRecipe(Recipe recipe) {
    if (_hasProblematicContent(recipe)) {
      throw Exception('Recipe contains problematic content: ${recipe.title}');
    }

    return Recipe(
      id: recipe.id,
      title: _cleanTitle(recipe.title),
      image: recipe.image,
      carbs: recipe.carbs,
      sugar: recipe.sugar,
      calories: recipe.calories,
      category: recipe.category,
      cuisine: recipe.cuisine,
      ingredients: _cleanIngredients(recipe.ingredients),
      instructions: _cleanInstructions(recipe.instructions),
    );
  }

  static bool _hasProblematicContent(Recipe recipe) {
    final allText = '${recipe.title} ${recipe.instructions.join(' ')}'.toLowerCase();
    
    // Check for problematic patterns
    for (final pattern in problemmaticPatterns) {
      if (allText.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    
    // Check for URLs and domains
    if (RegExp(r'https?://|www\.|\.com|\.org|\.net').hasMatch(allText)) {
      return true;
    }
    
    // Check for social media handles
    if (RegExp(r'@\w+|#\w+').hasMatch(allText)) {
      return true;
    }
    
    return false;
  }

  static String _cleanTitle(String title) {
    String cleaned = title
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s&\-\(\)]'), '')
        .trim();
    
    // Remove common title prefixes/suffixes
    final titleCleaners = [
      'recipe for ', 'how to make ', 'easy ', 'quick ', 'best ',
      'homemade ', 'simple ', 'perfect ', 'amazing ', 'incredible ',
      ' recipe', ' ever', ' you\'ll love', ' - foodnetwork',
      ' | allrecipes', ' - pinterest'
    ];
    
    for (final cleaner in titleCleaners) {
      cleaned = cleaned.replaceAll(RegExp(cleaner, caseSensitive: false), '');
    }
    
    return cleaned.trim();
  }

  static List<String> _cleanIngredients(List<String> ingredients) {
    return ingredients
        .map(_cleanSingleIngredient)
        .where((ingredient) => ingredient.isNotEmpty)
        .where((ingredient) => ingredient.length > 2) // Filter very short ingredients
        .where((ingredient) => !_isProblematicIngredient(ingredient))
        .toList();
  }

  static bool _isProblematicIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();
    
    // Filter ingredients that are actually instructions or comments
    final badIngredients = [
      'see recipe', 'check blog', 'visit site', 'follow recipe',
      'as directed', 'according to', 'refer to', 'see notes',
      'optional:', 'note:', 'tip:', 'chef\'s note',
    ];
    
    for (final bad in badIngredients) {
      if (lower.contains(bad)) {
        return true;
      }
    }
    
    return false;
  }

  static String _cleanSingleIngredient(String ingredient) {
    String cleaned = ingredient.toLowerCase().trim();

    // Apply standardization replacements
    for (String key in ingredientStandardization.keys) {
      cleaned = cleaned.replaceAll(key, ingredientStandardization[key]!);
    }

    // Remove parenthetical notes
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    
    // Remove leading measurements and numbers
    cleaned = cleaned.replaceAll(RegExp(r'^[\d\s/.-]+'), '');

    // Remove common measurement units
    final units = [
      'cups?', 'cup', 'tbsp', 'tablespoons?', 'tsp', 'teaspoons?',
      'oz', 'ounces?', 'lbs?', 'pounds?', 'grams?', 'g', 'kg',
      'ml', 'l', 'liters?', 'cloves?', 'pieces?', 'slices?',
      'pinch', 'dash', 'handful', 'bunch', 'sprig', 'stalk',
      'large', 'medium', 'small', 'extra large', 'jumbo'
    ];

    for (String unit in units) {
      cleaned = cleaned.replaceAll(RegExp('\\b$unit\\b'), '');
    }

    // Clean up whitespace and punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[,\-.\s]+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[,\-.\s]+$'), '');

    // Capitalize properly
    if (cleaned.isNotEmpty) {
      cleaned = cleaned.split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }

    return cleaned;
  }

  static List<String> _cleanInstructions(List<String> instructions) {
    return instructions
        .where((instruction) => !_isProblematicInstruction(instruction))
        .map(_cleanSingleInstruction)
        .where((instruction) => instruction.isNotEmpty && instruction.length > 15)
        .where((instruction) => instruction.length <= 500) // Remove overly long instructions
        .map(_breakDownLongInstruction)
        .expand((instruction) => instruction) // Flatten list of lists
        .toList();
  }

  static bool _isProblematicInstruction(String instruction) {
    final lowerInstruction = instruction.toLowerCase();
    
    // Check against problematic instruction patterns
    for (final pattern in problematicInstructions) {
      if (lowerInstruction.contains(pattern)) {
        return true;
      }
    }
    
    // Filter instructions that are just measurements or ingredients
    if (RegExp(r'^\d+[\s\w/.-]*$').hasMatch(instruction.trim())) {
      return true;
    }
    
    // Filter instructions that are mostly numbers and units
    final wordsCount = instruction.split(' ').length;
    final numbersCount = RegExp(r'\d+').allMatches(instruction).length;
    if (wordsCount > 0 && numbersCount / wordsCount > 0.5) {
      return true;
    }
    
    return false;
  }

  static List<String> _breakDownLongInstruction(String instruction) {
    // If instruction is reasonable length, return as-is
    if (instruction.length <= 200) {
      return [instruction];
    }
    
    // Try to break at natural sentence boundaries
    final sentences = instruction.split(RegExp(r'[.!?]\s+'));
    if (sentences.length > 1) {
      return sentences
          .where((s) => s.trim().length > 10)
          .map((s) => _cleanSingleInstruction(s))
          .toList();
    }
    
    // Try to break at cooking action words
    final actionBreaks = [
      'then,', 'next,', 'after', 'once', 'immediately',
      'continue', 'repeat', 'meanwhile', 'while',
      'in a separate', 'in another', 'at the same time'
    ];
    
    for (final breakWord in actionBreaks) {
      final index = instruction.toLowerCase().indexOf(breakWord);
      if (index > 50 && index < instruction.length - 20) {
        final first = instruction.substring(0, index).trim();
        final second = instruction.substring(index).trim();
        
        if (first.length > 15 && second.length > 15) {
          return [
            _cleanSingleInstruction(first),
            _cleanSingleInstruction(second)
          ].where((s) => s.isNotEmpty).toList();
        }
      }
    }
    
    // Last resort: break at reasonable length
    if (instruction.length > 300) {
      final cutIndex = instruction.lastIndexOf(' ', 200);
      if (cutIndex > 100) {
        final first = instruction.substring(0, cutIndex).trim();
        final second = instruction.substring(cutIndex).trim();
        return [
          _cleanSingleInstruction(first),
          _cleanSingleInstruction(second)
        ].where((s) => s.isNotEmpty).toList();
      }
    }
    
    return [_cleanSingleInstruction(instruction)];
  }

  static String _cleanSingleInstruction(String instruction) {
    String cleaned = instruction.trim();
    
    // Remove HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    // Fix common spelling errors
    final corrections = {
      'saut ': 'sauté ', 'saute ': 'sauté ', 'sautee ': 'sauté ',
      'untill': 'until', 'reciepe': 'recipe', 'ingrediant': 'ingredient',
      'seperate': 'separate', 'defintely': 'definitely', 'occassionally': 'occasionally',
      'recomend': 'recommend', 'temprature': 'temperature', 'refridgerator': 'refrigerator',
      'carfully': 'carefully', 'thoroughy': 'thoroughly', 'completly': 'completely',
    };

    for (String mistake in corrections.keys) {
      cleaned = cleaned.replaceAllMapped(
        RegExp(mistake, caseSensitive: false),
        (match) => corrections[mistake]!,
      );
    }

    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove redundant phrases
    final redundantPhrases = [
      'this is where the technique comes in. ',
      'avoid the temptation to stir. ',
      'simply allow the skillet to sit ',
      'it is important not to over mix this batter. ',
      'makes \\d+ over sized or \\d+ small muffins\\.',
      'muffins freeze well for \\d+ months\\.',
    ];

    for (final phrase in redundantPhrases) {
      cleaned = cleaned.replaceAll(RegExp(phrase, caseSensitive: false), '');
    }

    // Ensure proper sentence ending
    if (cleaned.isNotEmpty &&
        !cleaned.endsWith('.') &&
        !cleaned.endsWith('!') &&
        !cleaned.endsWith('?')) {
      cleaned += '.';
    }

    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  static int getEstimatedCookTime(Map<String, dynamic> spoonacularData) {
    final readyInMinutes = spoonacularData['readyInMinutes'];
    final cookingMinutes = spoonacularData['cookingMinutes'];
    final preparationMinutes = spoonacularData['preparationMinutes'];

    if (cookingMinutes != null && cookingMinutes > 0) return cookingMinutes;
    if (readyInMinutes != null && readyInMinutes > 0) return readyInMinutes;
    if (preparationMinutes != null && preparationMinutes > 0) return preparationMinutes + 15;

    final dishTypes = spoonacularData['dishTypes'] as List<dynamic>? ?? [];
    if (dishTypes.any((type) => type.toString().contains('dessert'))) return 45;
    if (dishTypes.any((type) => type.toString().contains('soup'))) return 30;
    if (dishTypes.any((type) => type.toString().contains('salad'))) return 15;

    return 25;
  }

  // Additional validation method
  static bool isValidRecipe(Recipe recipe) {
    // Check if recipe passed cleaning successfully
    if (recipe.title.isEmpty || recipe.ingredients.isEmpty || recipe.instructions.isEmpty) {
      return false;
    }
    
    // Check for minimum quality standards
    if (recipe.ingredients.length < 2 || recipe.instructions.length < 2) {
      return false;
    }
    
    // Check for reasonable instruction lengths
    final validInstructions = recipe.instructions
        .where((inst) => inst.length >= 15 && inst.length <= 500)
        .length;
    
    if (validInstructions / recipe.instructions.length < 0.7) {
      return false;
    }
    
    return true;
  }
}