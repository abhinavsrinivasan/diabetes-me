// lib/homescreen_enhanced.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'recipe_utils.dart';
import 'grocery_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'services/spoonacular_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/auth_service.dart';
import 'dart:io' show Platform;

class EnhancedHomeScreen extends StatefulWidget {
  @override
  _EnhancedHomeScreenState createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen> with TickerProviderStateMixin {
  List<Recipe> allRecipes = [];
  List<Recipe> spoonacularRecipes = [];
  List<Recipe> localRecipes = [];
  List<Recipe> filteredRecipes = [];
  
  String selectedCategory = 'All';
  String selectedCuisine = 'All';
  List<String> categories = ['All', 'Snacks', 'Breakfast', 'Lunch', 'Dinner', 'Dessert'];
  List<String> cuisines = ['All', 'American', 'Italian', 'Mexican', 'Asian', 'Mediterranean', 'Indian', 'French'];
  String searchQuery = '';
  String userName = '';
  String greeting = '';
  
  bool isLoadingSpoonacular = false;
  bool useSpoonacularData = true;
  
  late TabController _tabController;

  // Range filters
  RangeValues carbRange = const RangeValues(0, 100);
  RangeValues sugarRange = const RangeValues(0, 50);
  RangeValues giRange = const RangeValues(0, 100);

  // Backend URL for local recipes
  final String baseUrl = kIsWeb 
    ? 'http://127.0.0.1:5001' 
    : Platform.isIOS
        ? 'http://192.168.1.248:5001'
        : 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchUserProfile();
    updateGreeting();
    loadInitialRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          String fullName = profile['name'] ?? 'User';
          userName = fullName.split(' ').first;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> loadInitialRecipes() async {
    await Future.wait([
      fetchLocalRecipes(),
      loadSpoonacularRecipes(),
    ]);
    combineAndFilterRecipes();
  }

  Future<void> fetchLocalRecipes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/recipes'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          localRecipes = data.map((item) => Recipe.fromJson(item)).toList();
          // Update local recipes with working image URLs
          for (var i = 0; i < localRecipes.length; i++) {
            localRecipes[i] = updateRecipeImage(localRecipes[i]);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching local recipes: $e');
    }
  }

  Future<void> loadSpoonacularRecipes() async {
    if (!useSpoonacularData) return;
    
    setState(() {
      isLoadingSpoonacular = true;
    });

    try {
      // Load different types of diabetes-friendly recipes
      final randomRecipes = await SpoonacularService.getDiabeticFriendlyRecipes(number: 15);
      final lowCarbRecipes = await SpoonacularService.searchRecipes(
        query: 'low carb',
        maxCarbs: 25,
        number: 10,
      );
      final breakfastRecipes = await SpoonacularService.searchRecipes(
        query: 'breakfast',
        maxCarbs: 30,
        maxSugar: 10,
        number: 8,
      );

      setState(() {
        spoonacularRecipes = [
          ...randomRecipes,
          ...lowCarbRecipes,
          ...breakfastRecipes,
        ];
        // Remove duplicates based on title
        final seen = <String>{};
        spoonacularRecipes = spoonacularRecipes.where((recipe) => seen.add(recipe.title)).toList();
      });
    } catch (e) {
      debugPrint('Error loading Spoonacular recipes: $e');
      _showSnackBar('Failed to load online recipes. Showing local recipes only.');
    } finally {
      setState(() {
        isLoadingSpoonacular = false;
      });
    }
  }

  void combineAndFilterRecipes() {
    setState(() {
      allRecipes = [...localRecipes, ...spoonacularRecipes];
      applyFilters();
    });
  }

  Recipe updateRecipeImage(Recipe recipe) {
    // Your existing image update logic
    Map<int, String> imageUrls = {
      1: 'https://images.unsplash.com/photo-1609501676725-7186f017a4b7?w=400&h=400&fit=crop',
      2: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=400&fit=crop',
      3: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=400&fit=crop',
      4: 'https://images.unsplash.com/photo-1582169296194-e4d644f24d1a?w=400&h=400&fit=crop',
      5: 'https://images.unsplash.com/photo-1488900128323-21503983a07e?w=400&h=400&fit=crop',
      6: 'https://images.unsplash.com/photo-1534938665420-4193effeacc4?w=400&h=400&fit=crop',
      7: 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=400&h=400&fit=crop',
      8: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400&h=400&fit=crop',
    };

    return Recipe(
      id: recipe.id,
      title: recipe.title,
      image: imageUrls[recipe.id] ?? recipe.image,
      carbs: recipe.carbs,
      sugar: recipe.sugar,
      calories: recipe.calories,
      category: recipe.category,
      cuisine: recipe.cuisine,
      glycemicIndex: recipe.glycemicIndex,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
    );
  }

  void applyFilters() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        final matchCategory = selectedCategory == 'All' || recipe.category == selectedCategory;
        final matchCuisine = selectedCuisine == 'All' || recipe.cuisine == selectedCuisine;
        final matchCarbs = recipe.carbs >= carbRange.start && recipe.carbs <= carbRange.end;
        final matchSugar = recipe.sugar >= sugarRange.start && recipe.sugar <= sugarRange.end;
        final matchGI = recipe.glycemicIndex >= giRange.start && recipe.glycemicIndex <= giRange.end;
        final matchSearch = searchQuery.isEmpty || 
            recipe.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            recipe.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
            recipe.cuisine.toLowerCase().contains(searchQuery.toLowerCase());
        
        return matchCategory && matchCuisine && matchCarbs && matchSugar && matchGI && matchSearch;
      }).toList();
    });
  }

  Future<void> searchByIngredients(List<String> ingredients) async {
    if (!useSpoonacularData) return;
    
    setState(() {
      isLoadingSpoonacular = true;
    });

    try {
      final results = await SpoonacularService.searchByIngredients(ingredients);
      setState(() {
        spoonacularRecipes.addAll(results);
        combineAndFilterRecipes();
      });
      _showSnackBar('Found ${results.length} recipes using your ingredients!');
    } catch (e) {
      _showSnackBar('Failed to search by ingredients');
    } finally {
      setState(() {
        isLoadingSpoonacular = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final isSpoonacularRecipe = recipe.id > 1000000; // Spoonacular IDs are typically large

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
                
                // Recipe source badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSpoonacularRecipe ? Colors.green.withOpacity(0.9) : Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSpoonacularRecipe ? 'ONLINE' : 'LOCAL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                // Cuisine badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                                _showSnackBar(
                                  newState ? 'Added to favorites!' : 'Removed from favorites',
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_dining, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(recipe.category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const Spacer(),
                        Text(recipe.cuisine, style: const TextStyle(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      "Carbs: ${recipe.carbs}g • Sugar: ${recipe.sugar}g\nGI: ${recipe.glycemicIndex}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          userName.isNotEmpty ? '$userName!' : 'for recipes',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.deepPurple),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                          );
                        },
                        tooltip: 'Scan Barcode',
                      ),
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.deepPurple),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GroceryListScreen()),
                          );
                        },
                        tooltip: 'Grocery List',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                        onPressed: loadInitialRecipes,
                        tooltip: 'Refresh',
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.deepPurple),
                        onSelected: (value) {
                          switch (value) {
                            case 'toggle_source':
                              setState(() {
                                useSpoonacularData = !useSpoonacularData;
                                if (useSpoonacularData) {
                                  loadSpoonacularRecipes();
                                } else {
                                  spoonacularRecipes.clear();
                                }
                                combineAndFilterRecipes();
                              });
                              _showSnackBar(useSpoonacularData 
                                ? 'Online recipes enabled' 
                                : 'Using local recipes only');
                              break;
                            case 'search_ingredients':
                              _showIngredientSearchDialog();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle_source',
                            child: Row(
                              children: [
                                Icon(
                                  useSpoonacularData ? Icons.cloud_off : Icons.cloud,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 8),
                                Text(useSpoonacularData ? 'Local Only' : 'Enable Online'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'search_ingredients',
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.deepPurple),
                                SizedBox(width: 8),
                                Text('Search by Ingredients'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.deepPurple.withOpacity(0.1),
                ),
                tabs: const [
                  Tab(text: 'All Recipes'),
                  Tab(text: 'Diabetic'),
                  Tab(text: 'Low Carb'),
                ],
                onTap: (index) {
                  switch (index) {
                    case 0:
                      setState(() {
                        filteredRecipes = allRecipes;
                        applyFilters();
                      });
                      break;
                    case 1:
                      _filterDiabeticFriendly();
                      break;
                    case 2:
                      _filterLowCarb();
                      break;
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    applyFilters();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for recipes...',
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  suffixIcon: isLoadingSpoonacular 
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.tune, color: Colors.deepPurple),
                        onPressed: _openFilterDialog,
                      ),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Recipe source info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: useSpoonacularData ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: useSpoonacularData ? Colors.green[200]! : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    useSpoonacularData ? Icons.cloud : Icons.storage,
                    color: useSpoonacularData ? Colors.green[700] : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      useSpoonacularData 
                        ? 'Showing ${filteredRecipes.length} recipes (${localRecipes.length} local + ${spoonacularRecipes.length} online)'
                        : 'Showing ${filteredRecipes.length} local recipes',
                      style: TextStyle(
                        fontSize: 12,
                        color: useSpoonacularData ? Colors.green[700] : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Recipes Grid
            Expanded(
              child: allRecipes.isEmpty && !isLoadingSpoonacular
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading recipes...'),
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
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecipes.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          return _buildRecipeCard(filteredRecipes[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _filterDiabeticFriendly() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        return recipe.carbs <= 30 && 
               recipe.sugar <= 15 && 
               recipe.glycemicIndex <= 70;
      }).toList();
    });
  }

  void _filterLowCarb() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        return recipe.carbs <= 20;
      }).toList();
    });
  }

  void _openFilterDialog() {
    // Your existing filter dialog implementation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Recipes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add your existing filter UI here
              const Text('Advanced filters coming soon!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showIngredientSearchDialog() {
    final ingredientController = TextEditingController();
    final ingredients = <String>[];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Search by Ingredients'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ingredientController,
                decoration: const InputDecoration(
                  hintText: 'Enter ingredient (e.g., chicken, broccoli)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty && !ingredients.contains(value.trim())) {
                    setDialogState(() {
                      ingredients.add(value.trim());
                      ingredientController.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (ingredients.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ingredients.map((ingredient) {
                    return Chip(
                      label: Text(ingredient),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setDialogState(() {
                          ingredients.remove(ingredient);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: ingredients.isEmpty ? null : () {
                Navigator.pop(context);
                searchByIngredients(ingredients);
              },
              child: const Text('Search'),
            ),
          ],
        ),
      ),
    );
  }
}