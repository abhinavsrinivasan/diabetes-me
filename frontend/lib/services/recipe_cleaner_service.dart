// lib/services/recipe_cleaner_service.dart

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
    'check my vlog', 'visit my blog', 'see my website', 'follow me on',
    'subscribe to', 'like and share', 'check out my', 'find the recipe on',
    'full recipe at', 'recipe video', 'watch the video', 'recipe link',
  ];

  static final List<String> problematicInstructions = [
    'check my vlog', 'see video', 'watch tutorial', 'visit website',
    'follow link', 'see blog post',
  ];

  static Recipe cleanRecipe(Recipe recipe) {
    if (_hasProblematicContent(recipe)) {
      throw Exception('Recipe contains problematic content');
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
      glycemicIndex: recipe.glycemicIndex,
      ingredients: _cleanIngredients(recipe.ingredients),
      instructions: _cleanInstructions(recipe.instructions),
    );
  }

  static bool _hasProblematicContent(Recipe recipe) {
    final allText = '${recipe.title} ${recipe.instructions.join(' ')}'.toLowerCase();
    return problemmaticPatterns.any((pattern) => allText.contains(pattern));
  }

  static String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s&\-\(\)]'), '')
        .trim();
  }

  static List<String> _cleanIngredients(List<String> ingredients) {
    return ingredients
        .map(_cleanSingleIngredient)
        .where((ingredient) => ingredient.isNotEmpty)
        .toList();
  }

  static String _cleanSingleIngredient(String ingredient) {
    String cleaned = ingredient.toLowerCase().trim();

    for (String key in ingredientStandardization.keys) {
      cleaned = cleaned.replaceAll(key, ingredientStandardization[key]!);
    }

    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^[\d\s/.-]+'), '');

    final units = ['cups?', 'cup', 'tbsp', 'tablespoons?', 'tsp', 'teaspoons?',
                   'oz', 'ounces?', 'lbs?', 'pounds?', 'grams?', 'g', 'kg',
                   'ml', 'l', 'liters?', 'cloves?', 'pieces?', 'slices?'];

    for (String unit in units) {
      cleaned = cleaned.replaceAll(RegExp('\\b$unit\\b'), '');
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[,\-.\s]+'), '');

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
        .where((instruction) => instruction.isNotEmpty && instruction.length > 10)
        .toList();
  }

  static bool _isProblematicInstruction(String instruction) {
    final lowerInstruction = instruction.toLowerCase();
    return problematicInstructions.any((pattern) => lowerInstruction.contains(pattern));
  }

  static String _cleanSingleInstruction(String instruction) {
    String cleaned = instruction.trim();
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    final corrections = {
      'saut ': 'sauté ', 'saute ': 'sauté ', 'sautee ': 'sauté ',
      'untill': 'until', 'reciepe': 'recipe', 'ingrediant': 'ingredient',
      'seperate': 'separate', 'defintely': 'definitely', 'occassionally': 'occasionally',
      'recomend': 'recommend',
    };

    for (String mistake in corrections.keys) {
      cleaned = cleaned.replaceAllMapped(
        RegExp(mistake, caseSensitive: false),
        (match) => corrections[mistake]!,
      );
    }

    if (cleaned.isNotEmpty &&
        !cleaned.endsWith('.') &&
        !cleaned.endsWith('!') &&
        !cleaned.endsWith('?')) {
      cleaned += '.';
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
}
