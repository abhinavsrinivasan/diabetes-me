import 'package:uuid/uuid.dart';

class Recipe {
  final int id;
  final String title;
  final String image;
  final int carbs;
  final int sugar;
  final int calories;
  final String category;
  final int glycemicIndex;
  final List<String> ingredients;
  final List<String> instructions;

  Recipe({
    required this.id,
    required this.title,
    required this.image,
    required this.carbs,
    required this.sugar,
    required this.calories,
    required this.category,
    required this.glycemicIndex,
    required this.ingredients,
    required this.instructions,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      image: json['image'],
      carbs: json['carbs'],
      sugar: json['sugar'],
      calories: json['calories'],
      category: json['category'],
      glycemicIndex: json['glycemic_index'],
      ingredients: List<String>.from(json['ingredients'] ?? []),
      instructions: List<String>.from(json['instructions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'carbs': carbs,
      'sugar': sugar,
      'calories': calories,
      'category': category,
      'glycemic_index': glycemicIndex,
      'ingredients': ingredients,
      'instructions': instructions,
    };
  }
}
