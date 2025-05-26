import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'recipe_utils.dart';
import 'grocery_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/auth_service.dart';
import 'dart:io' show Platform;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Recipe> allRecipes = []; // full list
  List<Recipe> filteredRecipes = []; // filtered list
  String selectedCategory = 'All';
  String selectedCuisine = 'All';
  List<String> categories = ['All', 'Snacks', 'Breakfast', 'Lunch', 'Dinner', 'Dessert'];
  List<String> cuisines = ['All', 'American', 'Italian', 'Mexican', 'Asian', 'Mediterranean', 'Indian', 'French'];
  String searchQuery = '';
  String userName = '';
  String greeting = '';

  // Range filters
  RangeValues carbRange = const RangeValues(0, 100);
  RangeValues sugarRange = const RangeValues(0, 50);
  RangeValues giRange = const RangeValues(0, 100);

  // Backend URL
  final String baseUrl = kIsWeb 
    ? 'http://127.0.0.1:5001' 
    : Platform.isIOS
        ? 'http://192.168.1.248:5001'
        : 'http://10.0.2.2:5001';

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
          for (var i = 0; i < allRecipes.length; i++) {
            allRecipes[i] = updateRecipeImage(allRecipes[i]);
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
      4: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=400&fit=crop', // Chickpeas (working Unsplash URL)
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
      cuisine: recipe.cuisine,
      glycemicIndex: recipe.glycemicIndex,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
    );
  }

  void applyFilters() {
    setState(() {
      filteredRecipes = allRecipes.where((recipe) {
        // Category filter
        final matchCategory = selectedCategory == 'All' || recipe.category == selectedCategory;
        
        // Cuisine filter
        final matchCuisine = selectedCuisine == 'All' || recipe.cuisine == selectedCuisine;
        
        // Carbs filter
        final matchCarbs = recipe.carbs >= carbRange.start && recipe.carbs <= carbRange.end;
        
        // Sugar filter
        final matchSugar = recipe.sugar >= sugarRange.start && recipe.sugar <= sugarRange.end;
        
        // Glycemic Index filter
        final matchGI = recipe.glycemicIndex >= giRange.start && recipe.glycemicIndex <= giRange.end;
        
        // Search query filter
        final matchSearch = searchQuery.isEmpty || 
            recipe.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            recipe.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
            recipe.cuisine.toLowerCase().contains(searchQuery.toLowerCase());
        
        return matchCategory && matchCuisine && matchCarbs && matchSugar && matchGI && matchSearch;
      }).toList();
    });
  }

  void openFilterDialog() {
    // Create temporary variables to store filter state
    String tempSelectedCategory = selectedCategory;
    String tempSelectedCuisine = selectedCuisine;
    RangeValues tempCarbRange = carbRange;
    RangeValues tempSugarRange = sugarRange;
    RangeValues tempGiRange = giRange;

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
                            
                            const SizedBox(height: 24),
                            
                            // Glycemic Index Slider
                            const Text(
                              "Glycemic Index",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RangeSlider(
                              values: tempGiRange,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              labels: RangeLabels(
                                '${tempGiRange.start.round()}',
                                '${tempGiRange.end.round()}',
                              ),
                              activeColor: Colors.blue,
                              inactiveColor: Colors.blue.withOpacity(0.3),
                              onChanged: (values) {
                                setDialogState(() {
                                  tempGiRange = values;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${tempGiRange.start.round()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${tempGiRange.end.round()}',
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
                                  tempGiRange = const RangeValues(0, 100);
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
                                  giRange = tempGiRange;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      body: SafeArea(
        child: Column(
          children: [
            // Header with personalized greeting
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
            ),

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
                sugarRange.start != 0 || sugarRange.end != 50 ||
                giRange.start != 0 || giRange.end != 100)
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
                              giRange = const RangeValues(0, 100);
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
                        if (giRange.start != 0 || giRange.end != 100)
                          _buildFilterChip('GI: ${giRange.start.round()}-${giRange.end.round()}', Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),

            if (selectedCategory != 'All' || selectedCuisine != 'All' || 
                carbRange.start != 0 || carbRange.end != 100 || 
                sugarRange.start != 0 || sugarRange.end != 50 ||
                giRange.start != 0 || giRange.end != 100)
              const SizedBox(height: 16),

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
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRecipes.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
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
                                        // Cuisine badge
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              recipe.cuisine,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
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
                                            Text(recipe.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.local_dining, size: 12, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(recipe.category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                            const Spacer(),
                                            Text("Carbs: ${recipe.carbs}g • Sugar: ${recipe.sugar}g\nGI: ${recipe.glycemicIndex}",
                                                style: const TextStyle(fontSize: 11)),
                                          ],
                                        ),
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
}