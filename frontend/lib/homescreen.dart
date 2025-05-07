import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'features/recipes/models/recipe.dart';
import 'services/auth_service.dart';
import 'recipedetail.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';

  List<Recipe> recipes = [];
  String selectedCategory = 'All';
  List<String> categories = ['All', 'Snacks', 'Breakfast', 'Lunch', 'Dinner', 'Dessert'];
  Set<int> confirmed = {}; // For animation
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchRecipes();
  }

  Future<void> fetchRecipes() async {
    final response = await http.get(Uri.parse('$baseUrl/recipes'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        recipes = data.map((json) => Recipe.fromJson(json)).toList();
      });
    }
  }

  void markAsEaten(Recipe recipe) async {
    final token = await AuthService().getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/progress'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: json.encode({
        "carbs": recipe.carbs,
        "sugar": recipe.sugar,
        "exercise": 0,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You ate ${recipe.title}")),
      );
      setState(() => confirmed.add(recipe.id));
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) setState(() => confirmed.remove(recipe.id));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to log progress")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = recipes.where((recipe) {
      final title = recipe.title.toLowerCase();
      final matchesSearch = title.contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' || recipe.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Search", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      Text("for recipes", style: TextStyle(fontSize: 20, color: Colors.black87)),
                    ],
                  ),
                  Icon(Icons.tune, color: Colors.grey.shade600)
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => searchQuery = value),
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
                        onSelected: (_) => setState(() => selectedCategory = cat),
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RecipeDetail(recipe: recipe)),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
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
                                  Text(
                                    recipe.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Carbs: ${recipe.carbs}g\nSugar: ${recipe.sugar}g\nGI: ${recipe.glycemicIndex}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  confirmed.contains(recipe.id)
                                      ? Row(
                                          children: const [
                                            Icon(Icons.check_circle, color: Colors.black),
                                            SizedBox(width: 4),
                                            Text("I Ate This", style: TextStyle(fontWeight: FontWeight.w600))
                                          ],
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => markAsEaten(recipe),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text("I Ate This"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
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
