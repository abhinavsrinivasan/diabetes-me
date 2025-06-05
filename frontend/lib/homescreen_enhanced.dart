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
  List<Recipe> filteredRecipes = [];
  
  String selectedCategory = 'All';
  String selectedCuisine = 'All';
  List<String> categories = ['All', 'Snacks', 'Breakfast', 'Lunch', 'Dinner', 'Dessert'];
  List<String> cuisines = ['All', 'American', 'Italian', 'Mexican', 'Asian', 'Mediterranean', 'Indian', 'French'];
  String searchQuery = '';
  String userName = '';
  String greeting = '';
  
  bool isLoadingSpoonacular = false;
  bool isSearchingNew = false;
  String lastSearchQuery = '';
  
  // Pagination
  int currentPage = 1;
  final int recipesPerPage = 20;
  
  late TabController _tabController;

  // Range filters (removed glycemic index)
  RangeValues carbRange = const RangeValues(0, 100);
  RangeValues sugarRange = const RangeValues(0, 50);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchUserProfile();
    updateGreeting();
    loadSpoonacularRecipes();
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

  Future<void> loadSpoonacularRecipes() async {
    setState(() {
      isLoadingSpoonacular = true;
    });

    try {
      // Load 200 diabetes-friendly recipes from different categories
      final List<Future<List<Recipe>>> recipeFutures = [
        SpoonacularService.getDiabeticFriendlyRecipes(number: 50),
        SpoonacularService.searchRecipes(
          query: 'breakfast',
          maxCarbs: 30,
          maxSugar: 10,
          number: 40,
        ),
        SpoonacularService.searchRecipes(
          query: 'lunch',
          maxCarbs: 35,
          maxSugar: 15,
          number: 40,
        ),
        SpoonacularService.searchRecipes(
          query: 'dinner',
          maxCarbs: 40,
          maxSugar: 15,
          number: 40,
        ),
        SpoonacularService.searchRecipes(
          query: 'snack',
          maxCarbs: 20,
          maxSugar: 8,
          number: 30,
        ),
      ];

      final results = await Future.wait(recipeFutures);
      final List<Recipe> loadedRecipes = [];
      
      for (final recipeList in results) {
        loadedRecipes.addAll(recipeList);
      }

      setState(() {
        allRecipes = loadedRecipes;
        // Remove duplicates based on title
        final seen = <String>{};
        allRecipes = allRecipes.where((recipe) => seen.add(recipe.title)).toList();
        applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading Spoonacular recipes: $e');
      _showSnackBar('Failed to load recipes. Please check your internet connection.');
    } finally {
      setState(() {
        isLoadingSpoonacular = false;
      });
    }
  }

  void applyFilters() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        final matchCategory = selectedCategory == 'All' || recipe.category == selectedCategory;
        final matchCuisine = selectedCuisine == 'All' || recipe.cuisine == selectedCuisine;
        final matchCarbs = recipe.carbs >= carbRange.start && recipe.carbs <= carbRange.end;
        final matchSugar = recipe.sugar >= sugarRange.start && recipe.sugar <= sugarRange.end;
        final matchSearch = searchQuery.isEmpty || 
            recipe.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            recipe.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
            recipe.cuisine.toLowerCase().contains(searchQuery.toLowerCase());
        
        return matchCategory && matchCuisine && matchCarbs && matchSugar && matchSearch;
      }).toList();
      
      // Reset to page 1 when filters change
      currentPage = 1;
    });

    // If no results found and user has searched for something, search Spoonacular
    if (filteredRecipes.isEmpty && 
        searchQuery.isNotEmpty && 
        searchQuery.length >= 3 && 
        searchQuery != lastSearchQuery &&
        !isSearchingNew) {
      _searchSpoonacularForQuery(searchQuery);
    }
  }

  List<Recipe> get paginatedRecipes {
    final startIndex = (currentPage - 1) * recipesPerPage;
    final endIndex = startIndex + recipesPerPage;
    
    if (startIndex >= filteredRecipes.length) return [];
    
    return filteredRecipes.sublist(
      startIndex,
      endIndex > filteredRecipes.length ? filteredRecipes.length : endIndex,
    );
  }

  int get totalPages {
    return (filteredRecipes.length / recipesPerPage).ceil();
  }

  void _goToPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  Future<void> _searchSpoonacularForQuery(String query) async {
    setState(() {
      isSearchingNew = true;
      lastSearchQuery = query;
    });

    try {
      final newRecipes = await SpoonacularService.searchRecipes(
        query: query,
        number: 20,
        maxCarbs: carbRange.end.round(),
        maxSugar: sugarRange.end.round(),
      );

      if (newRecipes.isNotEmpty) {
        setState(() {
          // Add new recipes to the main list, avoiding duplicates
          final existingTitles = allRecipes.map((r) => r.title.toLowerCase()).toSet();
          final uniqueNewRecipes = newRecipes.where(
            (recipe) => !existingTitles.contains(recipe.title.toLowerCase())
          ).toList();
          
          allRecipes.addAll(uniqueNewRecipes);
          applyFilters(); // Reapply filters to show new results
        });

        _showSnackBar('Found ${newRecipes.length} additional recipes for "$query"!');
      } else {
        _showSnackBar('No additional recipes found for "$query"');
      }
    } catch (e) {
      debugPrint('Error searching Spoonacular for query: $e');
      _showSnackBar('Failed to search for additional recipes');
    } finally {
      setState(() {
        isSearchingNew = false;
      });
    }
  }

  Future<void> searchByIngredients(List<String> ingredients) async {
    setState(() {
      isLoadingSpoonacular = true;
    });

    try {
      final results = await SpoonacularService.searchByIngredients(ingredients);
      setState(() {
        // Replace current recipes with ingredient-based results
        allRecipes = results;
        filteredRecipes = results;
        searchQuery = ''; // Clear search query
        selectedCategory = 'All'; // Reset filters
        selectedCuisine = 'All';
        carbRange = const RangeValues(0, 100);
        sugarRange = const RangeValues(0, 50);
      });
      _showSnackBar('Found ${results.length} recipes with your ingredients!');
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

  void openFilterDialog() {
    // Create temporary variables to store filter state
    String tempSelectedCategory = selectedCategory;
    String tempSelectedCuisine = selectedCuisine;
    RangeValues tempCarbRange = carbRange;
    RangeValues tempSugarRange = sugarRange;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  maxWidth: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune, color: Colors.deepPurple[600], size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            "Filter Recipes",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    
                    // Scrollable Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Filter
                            const Text(
                              "Category",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categories.map((category) {
                                final isSelected = tempSelectedCategory == category;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      tempSelectedCategory = category;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? Colors.deepPurple 
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected 
                                            ? Colors.deepPurple 
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected 
                                            ? FontWeight.w600 
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Cuisine Filter
                            const Text(
                              "Cuisine",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: cuisines.map((cuisine) {
                                final isSelected = tempSelectedCuisine == cuisine;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      tempSelectedCuisine = cuisine;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? Colors.orange 
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected 
                                            ? Colors.orange 
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      cuisine,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected 
                                            ? FontWeight.w600 
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Carbs Slider
                            const Text(
                              "Carbs (g)",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RangeSlider(
                              values: tempCarbRange,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              labels: RangeLabels(
                                '${tempCarbRange.start.round()}g',
                                '${tempCarbRange.end.round()}g',
                              ),
                              activeColor: Colors.green,
                              inactiveColor: Colors.green.withOpacity(0.3),
                              onChanged: (values) {
                                setDialogState(() {
                                  tempCarbRange = values;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${tempCarbRange.start.round()}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${tempCarbRange.end.round()}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Sugar Slider
                            const Text(
                              "Sugar (g)",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RangeSlider(
                              values: tempSugarRange,
                              min: 0,
                              max: 50,
                              divisions: 25,
                              labels: RangeLabels(
                                '${tempSugarRange.start.round()}g',
                                '${tempSugarRange.end.round()}g',
                              ),
                              activeColor: Colors.purple,
                              inactiveColor: Colors.purple.withOpacity(0.3),
                              onChanged: (values) {
                                setDialogState(() {
                                  tempSugarRange = values;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${tempSugarRange.start.round()}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${tempSugarRange.end.round()}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Clear All Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempSelectedCategory = 'All';
                                  tempSelectedCuisine = 'All';
                                  tempCarbRange = const RangeValues(0, 100);
                                  tempSugarRange = const RangeValues(0, 50);
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Clear All",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Apply Filters Button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                // Apply the temporary filters to the main state
                                setState(() {
                                  selectedCategory = tempSelectedCategory;
                                  selectedCuisine = tempSelectedCuisine;
                                  carbRange = tempCarbRange;
                                  sugarRange = tempSugarRange;
                                });
                                
                                // Apply filters and close dialog
                                applyFilters();
                                Navigator.pop(context);
                                
                                // Show confirmation
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Filters applied! Found ${filteredRecipes.length} recipes.'),
                                    backgroundColor: Colors.green[600],
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                "Apply Filters",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
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
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SPOONACULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                // Action buttons
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
                      "Carbs: ${recipe.carbs}g • Sugar: ${recipe.sugar}g\nCalories: ${recipe.calories}",
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
                        onPressed: loadSpoonacularRecipes,
                        tooltip: 'Refresh',
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.deepPurple),
                        onSelected: (value) {
                          if (value == 'search_ingredients') {
                            _showIngredientSearchDialog();
                          }
                        },
                        itemBuilder: (context) => [
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

            // Tab Bar for categories
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
                        selectedCategory = 'All';
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
                    // Reset last search query if user is typing something new
                    if (value.length < 3) {
                      lastSearchQuery = '';
                    }
                  });
                  // Add debouncing to avoid too many API calls
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (searchQuery == value) {
                      applyFilters();
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for recipes...',
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  suffixIcon: (isLoadingSpoonacular || isSearchingNew)
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
                        onPressed: openFilterDialog,
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

            // Active Filters Display (if any filters are applied)
            if (selectedCategory != 'All' || selectedCuisine != 'All' || 
                carbRange.start != 0 || carbRange.end != 100 || 
                sugarRange.start != 0 || sugarRange.end != 50)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Active Filters:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategory = 'All';
                              selectedCuisine = 'All';
                              carbRange = const RangeValues(0, 100);
                              sugarRange = const RangeValues(0, 50);
                              applyFilters();
                            });
                          },
                          child: Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (selectedCategory != 'All')
                          _buildFilterChip('Category: $selectedCategory', Colors.deepPurple),
                        if (selectedCuisine != 'All')
                          _buildFilterChip('Cuisine: $selectedCuisine', Colors.orange),
                        if (carbRange.start != 0 || carbRange.end != 100)
                          _buildFilterChip('Carbs: ${carbRange.start.round()}-${carbRange.end.round()}g', Colors.green),
                        if (sugarRange.start != 0 || sugarRange.end != 50)
                          _buildFilterChip('Sugar: ${sugarRange.start.round()}-${sugarRange.end.round()}g', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),

            if (selectedCategory != 'All' || selectedCuisine != 'All' || 
                carbRange.start != 0 || carbRange.end != 100 || 
                sugarRange.start != 0 || sugarRange.end != 50)
              const SizedBox(height: 16),

            // Recipes Grid
            Expanded(
              child: allRecipes.isEmpty && isLoadingSpoonacular
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading diabetes-friendly recipes...'),
                        SizedBox(height: 8),
                        Text(
                          'Fetching ~200 recipes from Spoonacular',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : filteredRecipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isNotEmpty 
                                ? 'No recipes found for "$searchQuery"'
                                : 'No recipes match your filters',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              searchQuery.isNotEmpty && searchQuery.length >= 3
                                ? isSearchingNew 
                                    ? 'Searching Spoonacular for more recipes...'
                                    : 'Try a different search term or adjust your filters'
                                : 'Try adjusting your search criteria or filters',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (searchQuery.isNotEmpty && searchQuery.length < 3) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Type at least 3 characters to search online',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Recipes Grid
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: paginatedRecipes.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemBuilder: (context, index) {
                                return _buildRecipeCard(paginatedRecipes[index]);
                              },
                            ),
                          ),
                          
                          // Pagination
                          if (totalPages > 1) _buildPagination(),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _filterDiabeticFriendly() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        return recipe.carbs <= 30 && 
               recipe.sugar <= 15;
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

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          if (currentPage > 1)
            IconButton(
              onPressed: () => _goToPage(currentPage - 1),
              icon: const Icon(Icons.chevron_left),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          
          const SizedBox(width: 8),
          
          // Page numbers
          ...List.generate(totalPages, (index) {
            final pageNumber = index + 1;
            final isCurrentPage = pageNumber == currentPage;
            
            // Show max 5 pages centered around current page
            if (totalPages <= 5 || 
                (pageNumber >= currentPage - 2 && pageNumber <= currentPage + 2) ||
                pageNumber == 1 || pageNumber == totalPages) {
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => _goToPage(pageNumber),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentPage ? Colors.deepPurple : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentPage ? Colors.deepPurple : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        pageNumber.toString(),
                        style: TextStyle(
                          color: isCurrentPage ? Colors.white : Colors.black87,
                          fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            } else if ((pageNumber == currentPage - 3 && currentPage > 4) ||
                       (pageNumber == currentPage + 3 && currentPage < totalPages - 3)) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Colors.grey)),
              );
            }
            return const SizedBox.shrink();
          }),
          
          const SizedBox(width: 8),
          
          // Next button
          if (currentPage < totalPages)
            IconButton(
              onPressed: () => _goToPage(currentPage + 1),
              icon: const Icon(Icons.chevron_right),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
        ],
      ),
    );
  }
}