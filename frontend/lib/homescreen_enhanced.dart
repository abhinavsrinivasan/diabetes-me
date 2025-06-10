// lib/homescreen_enhanced.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'recipe_utils.dart';
import 'grocery_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'services/curated_recipes_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/auth_service.dart';
import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  
  bool isLoadingRecipes = false;
  String lastSearchQuery = '';
  
  // Pagination
  int currentPage = 1;
  final int recipesPerPage = 10;
  
  late TabController _tabController;

  // Range filters (removed glycemic index)
  RangeValues carbRange = const RangeValues(0, 50);
  RangeValues sugarRange = const RangeValues(0, 25);

  // Remove NotificationListener and use ScrollController to detect bottom only once
  ScrollController _gridScrollController = ScrollController();

  // Add FocusNode for search bar
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchBarFocused = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchUserProfile();
    updateGreeting();
    loadSupabaseRecipes();
    _searchFocusNode.addListener(() {
      setState(() {
        _searchBarFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gridScrollController.dispose();
    _searchFocusNode.dispose();
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

  Future<void> loadSupabaseRecipes() async {
    setState(() {
      isLoadingRecipes = true;
    });
    try {
      final data = await CuratedRecipesService().fetchAllRecipes();
      final List<Recipe> loadedRecipes = data.map((json) => Recipe.fromJson(json)).toList();
      setState(() {
        allRecipes = loadedRecipes;
        // Remove duplicates based on title
        final seen = <String>{};
        allRecipes = allRecipes.where((recipe) => seen.add(recipe.title)).toList();
        applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading Supabase recipes: $e');
      _showSnackBar('Failed to load recipes from Supabase.');
    } finally {
      setState(() {
        isLoadingRecipes = false;
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
                              max: 50,
                              divisions: 10,
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
                              max: 25,
                              divisions: 5,
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
                                  tempCarbRange = const RangeValues(0, 50);
                                  tempSugarRange = const RangeValues(0, 25);
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
                    // Only show cuisine, not category
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        recipe.cuisine,
                        style: const TextStyle(fontSize: 10, color: Colors.orange),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        'Carbs: ${recipe.carbs} g • Sugar: ${recipe.sugar} g\nCalories: ${recipe.calories}',
                        style: const TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                        onPressed: loadSupabaseRecipes,
                        tooltip: 'Refresh',
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                focusNode: _searchFocusNode,
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
                  suffixIcon: (isLoadingRecipes)
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
                carbRange.start != 0 || carbRange.end != 50 || 
                sugarRange.start != 0 || sugarRange.end != 25)
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
                              carbRange = const RangeValues(0, 50);
                              sugarRange = const RangeValues(0, 25);
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
                        if (carbRange.start != 0 || carbRange.end != 50)
                          _buildFilterChip('Carbs: ${carbRange.start.round()}-${carbRange.end.round()}g', Colors.green),
                        if (sugarRange.start != 0 || sugarRange.end != 25)
                          _buildFilterChip('Sugar: ${sugarRange.start.round()}-${sugarRange.end.round()}g', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),

            if (selectedCategory != 'All' || selectedCuisine != 'All' || 
                carbRange.start != 0 || carbRange.end != 50 || 
                sugarRange.start != 0 || sugarRange.end != 25)
              const SizedBox(height: 16),

            // Recipes Grid
            Expanded(
              child: allRecipes.isEmpty && isLoadingRecipes
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
                                ? 'Try a different search term or adjust your filters'
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
                              controller: _gridScrollController,
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
                          if (totalPages > 1 && !_searchBarFocused)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 16),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 4,
                                children: [
                                  for (int i = 1; i <= totalPages; i++)
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: i == currentPage ? Colors.deepPurple : Colors.white,
                                        foregroundColor: i == currentPage ? Colors.white : Colors.deepPurple,
                                        minimumSize: const Size(36, 36),
                                        padding: EdgeInsets.zero,
                                        side: BorderSide(color: Colors.deepPurple.withOpacity(i == currentPage ? 0.7 : 0.2)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _goToPage(i),
                                      child: Text('$i', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
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
}
