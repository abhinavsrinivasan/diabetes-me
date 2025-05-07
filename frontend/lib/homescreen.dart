import 'package:flutter/material.dart';
import 'features/recipes/models/recipe.dart';
import 'recipedetail.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // Range filters
  RangeValues carbRange = const RangeValues(0, 100);
  RangeValues sugarRange = const RangeValues(0, 50);
  RangeValues giRange = const RangeValues(0, 100);

  @override
  void initState() {
    super.initState();
    fetchRecipesFromBackend();
  }

  Future<void> fetchRecipesFromBackend() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/recipes'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        allRecipes = data.map((json) => Recipe.fromJson(json)).toList();
        filteredRecipes = List.from(allRecipes);
      });
    } else {
      throw Exception('Failed to load recipes');
    }
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Search", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      Text("for recipes", style: TextStyle(fontSize: 20, color: Colors.black87)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.deepPurple),
                    onPressed: openFilterDialog,
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

              // Recipes Grid
              Expanded(
                child: GridView.builder(
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
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: Image.network(
                                recipe.image,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(height: 120, color: Colors.grey[300]),
                              ),
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
                                      style: const TextStyle(fontSize: 11)),
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
