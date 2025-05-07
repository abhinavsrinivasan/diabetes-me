import 'package:flutter/material.dart';
import 'features/recipes/models/recipe.dart';

class RecipeDetail extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetail({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF0),
      appBar: AppBar(
        title: Text(recipe.title),
        backgroundColor: const Color(0xFFF1EFFF),
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Image.network(
                recipe.image,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(height: 220, color: Colors.grey[300]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Category: ${recipe.category}"),
                  const SizedBox(height: 4),
                  Text("Calories: ${recipe.calories}"),
                  const SizedBox(height: 4),
                  Text("Carbs: ${recipe.carbs}g | Sugar: ${recipe.sugar}g | GI: ${recipe.glycemicIndex}"),
                  const SizedBox(height: 16),
                  const Text("Instructions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...recipe.instructions.map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text("• $step", style: const TextStyle(fontSize: 14)),
                      )),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
