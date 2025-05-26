import 'widgets/ingredient_insight_modal.dart';
import 'services/grocery_list_service.dart';
import 'package:flutter/material.dart';
import 'features/recipes/models/recipe.dart';
import 'services/grocery_list_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool isFavorite = false;
  List<String> modifiedIngredients = [];

  @override
  void initState() {
    super.initState();
    // Initialize with original ingredients
    modifiedIngredients = List.from(widget.recipe.ingredients);
  }

  // Mock ingredient data with icons and amounts
  List<Map<String, dynamic>> get ingredientsList {
    final baseIngredients = [
      {
        'icon': '🥖',
        'name': modifiedIngredients.isNotEmpty ? modifiedIngredients[0] : 'Bread',
        'amount': '2 slices'
      },
      {
        'icon': '🫒',
        'name': modifiedIngredients.length > 1 ? modifiedIngredients[1] : 'Olive oil',
        'amount': '1 tbsp'
      },
      {
        'icon': '🧄',
        'name': modifiedIngredients.length > 2 ? modifiedIngredients[2] : 'Garlic',
        'amount': '1 clove'
      },
      {
        'icon': '🧂',
        'name': 'Salt and pepper',
        'amount': 'To taste'
      },
    ];

    // Add remaining ingredients
    for (int i = 3; i < modifiedIngredients.length; i++) {
      baseIngredients.add({
        'icon': _getIngredientIcon(modifiedIngredients[i]),
        'name': modifiedIngredients[i],
        'amount': _getIngredientAmount(modifiedIngredients[i])
      });
    }
    
    return baseIngredients;
  }

  String _getIngredientIcon(String ingredient) {
    final lower = ingredient.toLowerCase();
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('cheese')) return '🧀';
    if (lower.contains('chicken')) return '🍗';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('avocado')) return '🥑';
    if (lower.contains('lettuce') || lower.contains('salad')) return '🥬';
    if (lower.contains('yogurt')) return '🥛';
    if (lower.contains('berry') || lower.contains('strawberry')) return '🍓';
    if (lower.contains('blueberry')) return '🫐';
    if (lower.contains('nuts') || lower.contains('almond')) return '🥜';
    if (lower.contains('honey')) return '🍯';
    if (lower.contains('bell pepper')) return '🫑';
    if (lower.contains('broccoli')) return '🥦';
    if (lower.contains('zucchini')) return '🥒';
    if (lower.contains('mushroom')) return '🍄';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('onion')) return '🧅';
    return '🥄'; // Default icon
  }

  String _getIngredientAmount(String ingredient) {
    final lower = ingredient.toLowerCase();
    if (lower.contains('oil')) return '1-2 tbsp';
    if (lower.contains('cheese')) return '1/4 cup';
    if (lower.contains('chicken')) return '4 oz';
    if (lower.contains('yogurt')) return '1/2 cup';
    if (lower.contains('nuts')) return '1/4 cup';
    if (lower.contains('berry') || lower.contains('fruit')) return '1/2 cup';
    if (lower.contains('vegetable') || lower.contains('pepper') || lower.contains('broccoli')) return '1 cup';
    return '1 portion';
  }

  void _onIngredientTapped(String ingredient) {
    showIngredientInsight(
      context: context,
      ingredient: ingredient,
      recipeTitle: widget.recipe.title,
      recipeCategory: widget.recipe.category,
      onReplaceIngredient: (newIngredient) {
        setState(() {
          // Find and replace the ingredient
          final index = modifiedIngredients.indexWhere(
            (ing) => ing.toLowerCase().contains(ingredient.toLowerCase()),
          );
          if (index != -1) {
            modifiedIngredients[index] = newIngredient;
          }
        });
      },
    );
  }

  Future<void> _addToGroceryList(String ingredient) async {
    await GroceryListService.addToGroceryList(ingredient);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$ingredient" to grocery list!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      isFavorite = !isFavorite;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isFavorite ? 'Added to favorites!' : 'Removed from favorites'),
                        backgroundColor: isFavorite ? const Color(0xFF4CAF50) : Colors.grey[600],
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      widget.recipe.image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                    // Cuisine badge
                    Positioned(
                      top: 80,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.recipe.cuisine,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipe Title and Rating
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.recipe.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'by Chef Recipe',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Star Rating
                              Row(
                                children: [
                                  ...List.generate(4, (index) => const Icon(
                                    Icons.star,
                                    color: Color(0xFFFFB800),
                                    size: 20,
                                  )),
                                  const Icon(
                                    Icons.star_border,
                                    color: Color(0xFFFFB800),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recipe Stats
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Calories', '${widget.recipe.calories} cal'),
                          Container(width: 1, height: 40, color: Colors.grey[300]),
                          _buildStatItem('Ingredients', '${ingredientsList.length.toString().padLeft(2, '0')}'),
                          Container(width: 1, height: 40, color: Colors.grey[300]),
                          _buildStatItem('Total Time', '25 min'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // About Recipe
                    const Text(
                      'About Recipe',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This delicious ${widget.recipe.title.toLowerCase()} is a perfect choice for those managing diabetes. With ${widget.recipe.carbs}g carbs, ${widget.recipe.sugar}g sugar, and a glycemic index of ${widget.recipe.glycemicIndex}, it\'s designed to help maintain stable blood sugar levels while delivering amazing taste.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Diabetes Info
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diabetes-Friendly Info',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNutritionInfo('Carbs', '${widget.recipe.carbs}g', const Color(0xFFFF6B35)),
                              _buildNutritionInfo('Sugar', '${widget.recipe.sugar}g', const Color(0xFF9C27B0)),
                              _buildNutritionInfo('GI', '${widget.recipe.glycemicIndex}', const Color(0xFF2196F3)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Ingredients Section with Interactive Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Ingredients',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 14,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tap to explore',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '(${ingredientsList.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Interactive Ingredients List
                    ...ingredientsList.map((ingredient) => _buildInteractiveIngredientCard(ingredient)).toList(),

                    const SizedBox(height: 32),

                    // Steps Section
                    const Text(
                      'Steps',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Steps List
                    ...widget.recipe.instructions.asMap().entries.map((entry) {
                      int index = entry.key;
                      String step = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  step,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 40),

                    // Cook Now Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Happy cooking! Timer feature coming soon.'),
                              backgroundColor: Color(0xFF4CAF50),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Cook Now',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveIngredientCard(Map<String, dynamic> ingredient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onIngredientTapped(ingredient['name']),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon container with subtle animation hint
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ingredient['icon'],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ingredient['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            ingredient['amount'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap for insights & substitutes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Grocery list button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.add_shopping_cart,
                      size: 20,
                      color: Colors.green[600],
                    ),
                    onPressed: () => _addToGroceryList(ingredient['name']),
                    tooltip: 'Add to grocery list',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Insight indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionInfo(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}