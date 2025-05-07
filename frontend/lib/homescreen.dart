import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';

  List<dynamic> recipes = [];
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
      setState(() {
        recipes = json.decode(response.body);
      });
    }
  }

  void markAsEaten(Map recipe) async {
    await http.post(
      Uri.parse('$baseUrl/progress/1'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "carbs": recipe["carbs"],
        "sugar": recipe["sugar"],
        "exercise": 0,
      }),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("You ate ${recipe['title']}")),
    );
    setState(() => confirmed.add(recipe["id"]));
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) setState(() => confirmed.remove(recipe["id"]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = recipes.where((recipe) {
      final title = recipe['title'].toString().toLowerCase();
      final matchesSearch = title.contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' || recipe['category'] == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Color(0xFFFFFAF0),
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
                    children: [
                      Text("Search", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      Text("for recipes", style: TextStyle(fontSize: 20, color: Colors.black87)),
                    ],
                  ),
                  Icon(Icons.tune, color: Colors.grey.shade600)
                ],
              ),
              SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search for recipes...',
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
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
              SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: filteredRecipes.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    return GestureDetector(
                      onTap: () {},
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
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
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              child: Image.network(
                                recipe["image"],
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
                                    recipe["title"],
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  SizedBox(height: 6),
                                  Text("Carbs: ${recipe["carbs"]}g\nSugar: ${recipe["sugar"]}g", style: TextStyle(fontSize: 12)),
                                  SizedBox(height: 10),
                                  confirmed.contains(recipe["id"])
                                      ? Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.black),
                                            SizedBox(width: 4),
                                            Text("I Ate This", style: TextStyle(fontWeight: FontWeight.w600))
                                          ],
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => markAsEaten(recipe),
                                          icon: Icon(Icons.check, size: 16),
                                          label: Text("I Ate This"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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