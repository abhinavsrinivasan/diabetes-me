import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'recipe_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Recipe> allRecipes = []; // full list
  List<Recipe> filteredRecipes = []; // filtered list
  String selectedCategory = 'All';
  List<String> categories = ['All', 'Snacks', 'Breakfast', 'Lunch', 'Dinner', 'Dessert'];
  String searchQuery = '';
  String userName = '';
  String greeting = '';

  // Range filters
  RangeValues carbRange = const RangeValues(0, 100);
  RangeValues sugarRange = const RangeValues(0, 50);
  RangeValues giRange = const RangeValues(0, 100);

  // Backend URL
  final String baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    fetchRecipesFromBackend();
    fetchUserProfile();
    updateGreeting();
  }

  String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  void updateGreeting() {
    setState(() {
      greeting = getTimeBasedGreeting();
    });
  }

  Future<void> fetchUserProfile() async {
    try {
      final profile = await AuthService().getProfile();
      if (profile != null) {
        setState(() {
          // Extract first name from full name
          String fullName = profile['name'] ?? 'User';
          userName = fullName.split(' ').first;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> fetchRecipesFromBackend() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/recipes'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          allRecipes = data.map((item) => Recipe.fromJson(item)).toList();
          // Update recipes with working image URLs
          for (var recipe in allRecipes) {
            recipe = updateRecipeImage(recipe);
          }
          filteredRecipes = List.from(allRecipes);
        });
      } else {
        debugPrint('Backend error: ${response.statusCode}');
        throw Exception('Failed to load recipes');
      }
    } catch (e) {
      debugPrint('Error fetching recipes: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load recipes. Make sure your Flask server is running.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Recipe updateRecipeImage(Recipe recipe) {
    // Map recipe IDs to working Unsplash images
    Map<int, String> imageUrls = {
      1: 'https://images.unsplash.com/photo-1609501676725-7186f017a4b7?w=400&h=400&fit=crop', // Zucchini noodles
      2: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=400&fit=crop', // Salad
      3: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=400&fit=crop', // Yogurt parfait
      4: 'https://images.unsplash.com/photo-1638475938022-5ad2df6a5d89?w=400&h=400&fit=crop', // Chickpeas
      5: 'https://images.unsplash.com/photo-1488900128323-21503983a07e?w=400&h=400&fit=crop', // Greek yogurt
      6: 'https://images.unsplash.com/photo-1534938665420-4193effeacc4?w=400&h=400&fit=crop', // Cauliflower
      7: 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=400&h=400&fit=crop', // Avocado toast
      8: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400&h=400&fit=crop', // Salmon
    };

    // Create a new Recipe with updated image URL
    return Recipe(
      id: recipe.id,
      title: recipe.title,
      image: imageUrls[recipe.id] ?? recipe.image,
      carbs: recipe.carbs,
      sugar: recipe.sugar,
      calories: recipe.calories,
      category: recipe.category,
      glycemicIndex: recipe.glycemicIndex,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
    );
  }

  void applyFilters() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        final matchCarbs = recipe.carbs >= carbRange.start && recipe.carbs <= carbRange.end;
        final matchSugar = recipe.sugar >= sugarRange.start && recipe.sugar <= sugarRange.end;
        final matchGI = recipe.glycemicIndex >= giRange.start && recipe.glycemicIndex <= giRange.end;
        final matchCategory = selectedCategory == 'All' || recipe.category == selectedCategory;
        final matchSearch = recipe.title.toLowerCase().contains(searchQuery.toLowerCase());
        return matchCarbs && matchSugar && matchGI && matchCategory && matchSearch;
      }).toList();
    });
  }

  void openFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Filter Recipes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildSlider("Carbs (g)", carbRange, (val) => setState(() => carbRange = val)),
                    _buildSlider("Sugar (g)", sugarRange, (val) => setState(() => sugarRange = val)),
                    _buildSlider("Glycemic Index", giRange, (val) => setState(() => giRange = val)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel", style: TextStyle(color: Colors.deepPurple)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            applyFilters();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          child: const Text("Apply"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSlider(String label, RangeValues range, Function(RangeValues) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        RangeSlider(
          values: range,
          min: 0,
          max: 100,
          divisions: 20,
          labels: RangeLabels('${range.start.round()}', '${range.end.round()}'),
          activeColor: Colors.deepPurple,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with personalized greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        userName.isNotEmpty ? '$userName!' : 'for recipes',
                        style: const TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                        onPressed: () {
                          fetchRecipesFromBackend();
                          fetchUserProfile();
                          updateGreeting();
                        },
                        tooltip: 'Refresh',
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.deepPurple),
                        onPressed: openFilterDialog,
                        tooltip: 'Filter Recipes',
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    applyFilters();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for recipes...',
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = cat == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = cat;
                            applyFilters();
                          });
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Recipes Grid or Loading/Error State
              Expanded(
                child: allRecipes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading recipes...'),
                            SizedBox(height: 8),
                            Text(
                              'Make sure your Flask server is running on localhost:5000',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : filteredRecipes.isEmpty
                        ? const Center(
                            child: Text(
                              'No recipes match your filters.\nTry adjusting your search criteria.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : GridView.builder(
                            itemCount: filteredRecipes.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemBuilder: (context, index) {
                              final recipe = filteredRecipes[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                            child: Image.network(
                                              recipe.image,
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  height: 120,
                                                  color: Colors.grey[200],
                                                  child: const Center(child: CircularProgressIndicator()),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                debugPrint('Image load error for ${recipe.title}: $error');
                                                return Container(
                                                  height: 120,
                                                  color: Colors.grey[300],
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[600]),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        recipe.category,
                                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Row(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: FutureBuilder<bool>(
                                                    future: RecipeUtils.isFavorite(recipe),
                                                    builder: (context, snapshot) {
                                                      final isFavorite = snapshot.data ?? false;
                                                      return IconButton(
                                                        icon: Icon(
                                                          isFavorite ? Icons.favorite : Icons.favorite_border,
                                                          color: isFavorite ? Colors.red : Colors.black54,
                                                          size: 20,
                                                        ),
                                                        padding: const EdgeInsets.all(8),
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () async {
                                                          final newState = await RecipeUtils.toggleFavorite(recipe);
                                                          setState(() {});
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                newState ? 'Added to favorites!' : 'Removed from favorites',
                                                              ),
                                                              backgroundColor: newState ? Colors.green[600] : Colors.grey[600],
                                                              behavior: SnackBarBehavior.floating,
                                                              duration: const Duration(seconds: 1),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.add_circle,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                    padding: const EdgeInsets.all(8),
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () async {
                                                      await RecipeUtils.addRecipeNutrition(recipe, context);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(recipe.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 6),
                                            Text("Carbs: ${recipe.carbs}g\nSugar: ${recipe.sugar}g\nGI: ${recipe.glycemicIndex}",
                                                style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}